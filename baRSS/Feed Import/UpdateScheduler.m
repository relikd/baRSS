//
//  The MIT License (MIT)
//  Copyright (c) 2019 Oleg Geier
//
//  Permission is hereby granted, free of charge, to any person obtaining a copy of
//  this software and associated documentation files (the "Software"), to deal in
//  the Software without restriction, including without limitation the rights to
//  use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies
//  of the Software, and to permit persons to whom the Software is furnished to do
//  so, subject to the following conditions:
//
//  The above copyright notice and this permission notice shall be included in all
//  copies or substantial portions of the Software.
//
//  THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
//  IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
//  FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
//  AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
//  LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
//  OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
//  SOFTWARE.

@import SystemConfiguration;
#import "UpdateScheduler.h"
#import "Constants.h"
#import "StoreCoordinator.h"
#import "NSDate+Ext.h"

#import "FeedDownload.h"
#import "FaviconDownload.h"
#import "Feed+Ext.h"
#import "FeedMeta+Ext.h"
#import "FeedGroup+Ext.h"

#include <stdatomic.h>

static NSTimer *_timer;
static SCNetworkReachabilityRef _reachability = NULL;
static BOOL _isReachable = YES;
static BOOL _updatePaused = NO;
static BOOL _nextUpdateIsForced = NO;
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
}

/// Start download of all feeds (immediatelly) regardless of @c .scheduled property.
+ (void)forceUpdateAllFeeds {
	if (![self allowNetworkConnection]) // timer will restart once connection exists
		return;
	_nextUpdateIsForced = YES;
	[self scheduleTimer:[NSDate dateWithTimeIntervalSinceNow:0.05]];
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
	});
	if (!nextTime)
		nextTime = [NSDate distantFuture];
	NSTimeInterval tolerance = [nextTime timeIntervalSinceNow] * 0.15;
	_timer.tolerance = (tolerance < 1 ? 1 : tolerance); // at least 1 sec
	_timer.fireDate = nextTime;
	PostNotification(kNotificationScheduleTimerChanged, nil);
}

/// Called when schedule timer runs out (earliest @c .schedule date). Or if forced by user.
+ (void)updateTimerCallback {
#ifdef DEBUG
	NSLog(@"fired");
#endif
	BOOL updateAll = _nextUpdateIsForced;
	_nextUpdateIsForced = NO;
	
	NSManagedObjectContext *moc = [StoreCoordinator createChildContext];
	NSArray<Feed*> *list = [StoreCoordinator listOfFeedsThatNeedUpdate:updateAll inContext:moc];
	//NSAssert(list.count > 0, @"ERROR: Something went wrong, timer fired too early.");
	
	[self downloadList:list userInitiated:updateAll finally:^{
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
	for (Feed *f in [StoreCoordinator listOfFeedsThatNeedUpdate:YES inContext:nil])
		[FaviconDownload updateFeed:f finally:nil];
}

/// Download list of feeds. Either silently in background or with alerts in foreground.
+ (void)downloadList:(NSArray<Feed*>*)list userInitiated:(BOOL)flag finally:(nullable os_block_t)block {
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
		[self updateFeed:f alert:flag isForced:flag finally:^{
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
	alertPopup.informativeText = [NSString stringWithFormat:@"Error loading source: %@", url];
	[alertPopup runModal];
}

/**
 Start download request with existing @c Feed object. Reuses etag and modified headers (unless articles count is 0).
 @note Will post a @c kNotificationArticlesUpdated notification if download was successful and status code is @b not 304.
 */
+ (void)updateFeed:(Feed*)feed alert:(BOOL)alert isForced:(BOOL)forced finally:(nullable os_block_t)block {
	NSManagedObjectContext *moc = feed.managedObjectContext;
	NSManagedObjectID *oid = feed.objectID;
	[[FeedDownload withFeed:feed forced:forced] startWithBlock:^(FeedDownload *mem) {
		if (alert && mem.error) // but still copy values for error count increment
			AlertDownloadError(mem.error, mem.request.URL.absoluteString);
		Feed *f = [moc objectWithID:oid];
		BOOL recentlyAdded = (f.articles.count == 0); // before copy values
		BOOL downloadIcon = (!f.hasIcon && (recentlyAdded || forced));
		BOOL needsNotification = [mem copyValuesTo:f ignoreError:NO];
		[StoreCoordinator saveContext:moc andParent:YES];
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
