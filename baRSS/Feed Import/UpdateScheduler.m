@import SystemConfiguration;
#import "UpdateScheduler.h"
#import "Constants.h"
#import "StoreCoordinator.h"
#import "NotifyEndpoint.h"
#import "NSDate+Ext.h"

#import "FeedDownload.h"
#import "FaviconDownload.h"
#import "Feed+Ext.h"
#import "FeedArticle+Ext.h"
#import "FeedMeta+Ext.h"
#import "FeedGroup+Ext.h"

#include <stdatomic.h>

static NSTimer *_timer;
static SCNetworkReachabilityRef _reachability = NULL;
static BOOL _isReachable = YES;
static BOOL _updatePaused = NO;
static _Atomic(NSUInteger) _queueSize = 0;

@implementation UpdateScheduler

// ################################################################
// #  MARK: - Getter & Setter -
// ################################################################

/// @return Number of feeds being currently downloaded.
+ (NSUInteger)feedsInQueue { return _queueSize; }

/// @return Date when background update will fire. If updates are paused, date is @c distantFuture.
+ (NSDate *)dateScheduled { return _timer.fireDate; }

/// @return @c YES if current network state is reachable and updates are not paused by user.
+ (BOOL)allowNetworkConnection { return (_isReachable && !_updatePaused); }

/// @return @c YES if batch update is running
+ (BOOL)isUpdating { return _queueSize > 0; }

/// @return @c YES if update is paused by user.
+ (BOOL)isPaused { return _updatePaused; }

/// Set paused flag and cancel timer regardless of network connectivity.
+ (void)setPaused:(BOOL)flag {
	// TODO: should pause persist between app launches?
	_updatePaused = flag;
	if (flag) [self scheduleTimer:nil];
	else      [self scheduleNextFeed];
}

/// Update status. 'Paused', 'No conection', or 'Next update in ...'
+ (NSString*)remainingTimeTillNextUpdate:(nullable double*)remaining {
	double time = fabs(_timer.fireDate.timeIntervalSinceNow);
	if (remaining)
		*remaining = time;
	if (!_isReachable)
		return NSLocalizedString(@"No network connection", nil);
	if (_updatePaused)
		return NSLocalizedString(@"Updates paused", nil);
	if (time > 1e9) // distance future, over 31 years
		return @""; // aka. no feeds in list
	return [NSString stringWithFormat:NSLocalizedString(@"Next update in %@", nil),
			[NSDate stringForRemainingTime:_timer.fireDate]];
}

/// Update status. 'Updating X feeds …' or empty string if not updating.
+ (NSString*)updatingXFeeds {
	NSUInteger c = _queueSize;
	switch (c) {
		case 0:  return @"";
		case 1:  return NSLocalizedString(@"Updating 1 feed …", nil);
		default: return [NSString stringWithFormat:NSLocalizedString(@"Updating %lu feeds …", nil), c];
	}
}

// ################################################################
// #  MARK: - Schedule Timer Actions -
// ################################################################

/// Get date of next up feed and start the timer.
+ (void)scheduleNextFeed {
	if (![self allowNetworkConnection]) // timer will restart once connection exists
		return;
	if (_queueSize > 0) // assume every update ends with scheduleNextFeed
		return; // skip until called again
	NSDate *nextTime = [StoreCoordinator nextScheduledUpdate]; // if nextTime = nil, then no feeds to update
	if (nextTime && [nextTime timeIntervalSinceNow] < 1) { // mostly, if app was closed for a long time
		nextTime = [NSDate dateWithTimeIntervalSinceNow:1];
	}
	[self scheduleTimer:nextTime];
#ifdef DEBUG
	NSLog(@"schedule next update: %@", nextTime);
#endif
}

/**
 Set new @c .fireDate and @c .tolerance for update timer.

 @param nextTime If @c nil disable timer and set @c .fireDate to distant future.
 */
+ (void)scheduleTimer:(NSDate*)nextTime {
	static dispatch_once_t onceToken;
	dispatch_once(&onceToken, ^{
		_timer = [NSTimer timerWithTimeInterval:NSTimeIntervalSince1970 target:[self class] selector:@selector(updateTimerCallback) userInfo:nil repeats:YES];
		[[NSRunLoop mainRunLoop] addTimer:_timer forMode:NSRunLoopCommonModes];
		// technically not the right place to register. But since it is run once, its easier than somewhere else.
		[NSWorkspace.sharedWorkspace.notificationCenter addObserver:[self class] selector:@selector(didWakeAfterSleep) name:NSWorkspaceDidWakeNotification object:nil];
	});
	if (!nextTime)
		nextTime = [NSDate distantFuture];
	int tolerance = (int)([nextTime timeIntervalSinceNow] * 0.15);
	_timer.tolerance = (tolerance < 1 ? 1 : tolerance > 600 ? 600 : tolerance); // at least 1 sec, upto 10 min
	_timer.fireDate = nextTime;
	PostNotification(kNotificationScheduleTimerChanged, nil);
}

+ (void)didWakeAfterSleep {
#ifdef DEBUG
	NSLog(@"did wake from sleep");
#endif
	[UpdateScheduler scheduleNextFeed];
}

/// Called when schedule timer runs out (earliest @c .schedule date). Or if forced by user.
+ (void)updateTimerCallback {
	NSManagedObjectContext *moc = [StoreCoordinator createChildContext];
	NSArray<Feed*> *list = [StoreCoordinator feedsThatNeedUpdate:moc];
	[self update:list userInitiated:NO context:moc];
}

/// Start download of feeds immediatelly, regardless of @c .scheduled property.
+ (void)forceUpdate:(NSString*)indexPath {
	if (![self allowNetworkConnection]) // menu item should be disabled anyway
		return;
	NSManagedObjectContext *moc = [StoreCoordinator createChildContext];
	NSArray<Feed*> *list = [StoreCoordinator feedsWithIndexPath:indexPath inContext:moc];
	[self update:list userInitiated:YES context:moc];
}

/// Helper method for actual download
+ (void)update:(NSArray<Feed*>*)list userInitiated:(BOOL)flag context:(NSManagedObjectContext*)moc {
#ifdef DEBUG
	NSLog(@"updating feeds: %ld (%@)", list.count, flag ? @"forced" : @"scheduled");
#endif
	[self downloadList:list userInitiated:flag notifications:YES finally:^{
		[StoreCoordinator saveContext:moc andParent:YES]; // save parents too ...
		[moc reset];
		[self scheduleNextFeed]; // always reset the timer
	}];
}

// ################################################################
// #  MARK: - Download Actions -
// ################################################################

/// Perform @c FaviconDownload on all core data @c Feed entries.
+ (void)updateAllFavicons {
	for (Feed *f in [StoreCoordinator feedsWithIndexPath:nil inContext:nil])
		[FaviconDownload updateFeed:f finally:nil];
}

/// Download list of feeds. Either silently in background or with alerts in foreground.
+ (void)downloadList:(NSArray<Feed*>*)list userInitiated:(BOOL)flag notifications:(BOOL)notify finally:(nullable os_block_t)block {
	if (![self allowNetworkConnection]) {
		if (block) block();
		return;
	}
	// Else: batch download
	atomic_fetch_add_explicit(&_queueSize, list.count, memory_order_relaxed);
	PostNotification(kNotificationBackgroundUpdateInProgress, @(_queueSize));
	dispatch_group_t group = dispatch_group_create();
	for (Feed *f in list) {
		dispatch_group_enter(group);
		[self updateFeed:f alert:flag isForced:flag notifications:notify finally:^{
			atomic_fetch_sub_explicit(&_queueSize, 1, memory_order_relaxed);
			PostNotification(kNotificationBackgroundUpdateInProgress, @(_queueSize));
			dispatch_group_leave(group);
		}];
	}
	if (block) dispatch_group_notify(group, dispatch_get_main_queue(), block);
}

/// Helper method to show modal error alert
static inline void AlertDownloadError(NSError *err, NSString *url) {
	NSAlert *alertPopup = [NSAlert alertWithError:err];
	alertPopup.informativeText = [NSString stringWithFormat:NSLocalizedString(@"Error loading source: %@", nil), url];
	[alertPopup runModal];
}

/**
 Start download request with existing @c Feed object. Reuses etag and modified headers (unless articles count is 0).
 @note Will post a @c kNotificationArticlesUpdated notification if download was successful and status code is @b not 304.
 */
+ (void)updateFeed:(Feed*)feed alert:(BOOL)alert isForced:(BOOL)forced notifications:(BOOL)notify finally:(nullable os_block_t)block {
	NSManagedObjectContext *moc = feed.managedObjectContext;
	NSManagedObjectID *oid = feed.objectID;
	[[FeedDownload withFeed:feed forced:forced] startWithBlock:^(FeedDownload *mem) {
		if (alert && mem.error) // but still copy values for error count increment
			AlertDownloadError(mem.error, mem.request.URL.absoluteString);
		Feed *f = [moc objectWithID:oid];
		BOOL recentlyAdded = (f.articles.count == 0); // before copy values
		BOOL downloadIcon = (!f.hasIcon && (recentlyAdded || forced));
		BOOL needsNotification = [mem copyValuesTo:f ignoreError:NO];
		
		// need to gather object before save, because afterwards list will be empty
		NSArray *inserted = notify ? moc.insertedObjects.allObjects : nil;
		NSArray *deleted = moc.deletedObjects.allObjects;
		
		[StoreCoordinator saveContext:moc andParent:YES];
		
		// after save, update notifications
		// dismiss previously delivered notifications
		if (deleted) {
			NSMutableArray *ids = [NSMutableArray array];
			for (FeedArticle *article in deleted) { // will contain non-articles too
				if ([article isKindOfClass:[FeedArticle class]] || [article isKindOfClass:[Feed class]]) {
					[ids addObject:article.notificationID];
				}
			}
			[NotifyEndpoint dismiss:ids]; // no-op if empty
		}
		// post new notification (if needed)
		if (notify && inserted) {
			BOOL didAddAny = NO;
			for (FeedArticle *article in inserted) { // will contain non-articles too
				if ([article isKindOfClass:[FeedArticle class]]) {
					[NotifyEndpoint postArticle:article];
					didAddAny = YES;
				}
			}
			if (didAddAny)
				[NotifyEndpoint postFeed:f];
		}
		
		if (needsNotification)
			PostNotification(kNotificationArticlesUpdated, oid);
		if (downloadIcon && !mem.error) {
			[FaviconDownload updateFeed:f finally:block];
		} else if (block) block(); // always call block(); with or without favicon download
	}];
}

/**
 Download feed at url and append to persistent store in root folder. On error present user modal alert.
 Creates new @c FeedGroup, @c Feed, @c FeedMeta and @c FeedArticle instances and saves them to the persistent store.
 */
+ (void)autoDownloadAndParseURL:(NSString*)url addAnyway:(BOOL)flag name:(nullable NSString*)title refresh:(int32_t)interval {
	[[FeedDownload withURL:url] startWithBlock:^(FeedDownload *mem) {
		if (!flag && mem.error) {
			AlertDownloadError(mem.error, url);
			return;
		}
		NSManagedObjectContext *moc = [StoreCoordinator createChildContext];
		FeedGroup *fg = [FeedGroup appendToRoot:FEED inContext:moc];
		[fg setNameIfChanged:title];
		[fg.feed.meta setRefreshIfChanged:interval];
		[mem copyValuesTo:fg.feed ignoreError:YES];
		[StoreCoordinator saveContext:moc andParent:YES];
		PostNotification(kNotificationFeedGroupInserted, fg.objectID);
		if (!mem.error) [FaviconDownload updateFeed:fg.feed finally:nil];
		[moc reset];
		[UpdateScheduler scheduleNextFeed];
	}];
}

/// Download and process feed url. Auto update feed title with an update interval of 30 min.
+ (void)autoDownloadAndParseURL:(NSString*)url {
	[self autoDownloadAndParseURL:url addAnyway:NO name:nil refresh:kDefaultFeedRefreshInterval];
}

/// Insert Github URL for version releases with update interval 2 days and rename @c FeedGroup item.
+ (void)autoDownloadAndParseUpdateURL {
	[self autoDownloadAndParseURL:versionUpdateURL addAnyway:YES name:NSLocalizedString(@"baRSS releases", nil) refresh:2 * TimeUnitDays];
}

// ################################################################
// #  MARK: - Network Connection & Reachability -
// ################################################################

/// Set callback on @c self to listen for network reachability changes.
+ (void)registerNetworkChangeNotification {
	// https://stackoverflow.com/questions/11240196/notification-when-wifi-connected-os-x
	if (_reachability != NULL) return;
	_reachability = SCNetworkReachabilityCreateWithName(NULL, "1.1.1.1");
	if (_reachability == NULL) return;
	// If reachability information is available now, we don't get a callback later
	SCNetworkConnectionFlags flags;
	if (SCNetworkReachabilityGetFlags(_reachability, &flags))
		networkReachabilityCallback(_reachability, flags, NULL);
	if (!SCNetworkReachabilitySetCallback(_reachability, networkReachabilityCallback, NULL) ||
		!SCNetworkReachabilityScheduleWithRunLoop(_reachability, [[NSRunLoop currentRunLoop] getCFRunLoop], kCFRunLoopCommonModes))
	{
		CFRelease(_reachability);
		_reachability = NULL;
	}
}

/// Remove @c self callback (network reachability changes).
+ (void)unregisterNetworkChangeNotification {
	if (_reachability != NULL) {
		SCNetworkReachabilitySetCallback(_reachability, nil, nil);
		SCNetworkReachabilitySetDispatchQueue(_reachability, nil);
		CFRelease(_reachability);
		_reachability = NULL;
	}
}

/// Called when network interface or reachability changes.
static void networkReachabilityCallback(SCNetworkReachabilityRef target, SCNetworkConnectionFlags flags, void *object) {
	if (_reachability == NULL) return;
	_isReachable = [UpdateScheduler hasConnectivity:flags];
	PostNotification(kNotificationNetworkStatusChanged, @(_isReachable));
	if (_isReachable) {
		[UpdateScheduler scheduleNextFeed];
	} else {
		[UpdateScheduler scheduleTimer:nil];
	}
}

/// @return @c YES if network connection established.
+ (BOOL)hasConnectivity:(SCNetworkReachabilityFlags)flags {
	if ((flags & kSCNetworkReachabilityFlagsReachable) == 0)
		return NO;
	if ((flags & kSCNetworkReachabilityFlagsConnectionRequired) == 0)
		return YES;
	if ((flags & kSCNetworkReachabilityFlagsInterventionRequired) == 0 &&
		((flags & kSCNetworkReachabilityFlagsConnectionOnDemand) != 0 ||
		 (flags & kSCNetworkReachabilityFlagsConnectionOnTraffic) != 0))
		return YES; // no-intervention AND ( on-demand OR on-traffic )
	return NO;
}

@end
