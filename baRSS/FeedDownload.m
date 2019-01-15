//
//  The MIT License (MIT)
//  Copyright (c) 2018 Oleg Geier
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

#import "FeedDownload.h"
#import "Constants.h"
#import "StoreCoordinator.h"
#import "Feed+Ext.h"
#import "FeedMeta+Ext.h"
#import "FeedGroup+Ext.h"

#import <SystemConfiguration/SystemConfiguration.h>

static SCNetworkReachabilityRef _reachability = NULL;
static BOOL _isReachable = NO;
static BOOL _updatePaused = NO;
static BOOL _nextUpdateIsForced = NO;


@implementation FeedDownload

#pragma mark - User Interaction -

/// @return @c YES if current network state is reachable and updates are not paused by user.
+ (BOOL)allowNetworkConnection {
	return (_isReachable && !_updatePaused);
}

/// @return @c YES if update is paused by user.
+ (BOOL)isPaused {
	return _updatePaused;
}

/// Set paused flag and cancel timer regardless of network connectivity.
+ (void)setPaused:(BOOL)flag {
	_updatePaused = flag;
	if (_updatePaused)
		[self pauseUpdates];
	else
		[self resumeUpdates];
}

/// Cancel current timer and stop any updates until enabled again.
+ (void)pauseUpdates {
	[self scheduleTimer:nil];
}

/// Start normal (non forced) schedule if network is reachable.
+ (void)resumeUpdates {
	if (_isReachable)
		[self scheduleUpdateForUpcomingFeeds];
}


#pragma mark - Update Feed Timer -


/**
 Get date of next up feed and start the timer.
 */
+ (void)scheduleUpdateForUpcomingFeeds {
	if (![self allowNetworkConnection]) // timer will restart once connection exists
		return;
	NSDate *nextTime = [StoreCoordinator nextScheduledUpdate];
	if (!nextTime) return; // no timer means no feeds to update
	if ([nextTime timeIntervalSinceNow] < 1) { // mostly, if app was closed for a long time
		nextTime = [NSDate dateWithTimeIntervalSinceNow:1];
	}
	[self scheduleTimer:nextTime];
}

/**
 Start download of all feeds (immediatelly) regardless of @c .scheduled property.
 */
+ (void)forceUpdateAllFeeds {
	if (![self allowNetworkConnection]) // timer will restart once connection exists
		return;
	_nextUpdateIsForced = YES;
	[self scheduleTimer:[NSDate dateWithTimeIntervalSinceNow:0.2]];
}

/**
 Set new @c .fireDate and @c .tolerance for update timer.

 @param nextTime If @c nil timer will be disabled with a @c .fireDate very far in the future.
 */
+ (void)scheduleTimer:(NSDate*)nextTime {
	static NSTimer *timer;
	if (!timer) {
		timer = [NSTimer timerWithTimeInterval:NSTimeIntervalSince1970 target:[self class] selector:@selector(updateTimerCallback) userInfo:nil repeats:YES];
		[[NSRunLoop mainRunLoop] addTimer:timer forMode:NSRunLoopCommonModes];
	}
	if (!nextTime)
		nextTime = [NSDate dateWithTimeIntervalSinceNow:NSTimeIntervalSince1970];
	NSTimeInterval tolerance = [nextTime timeIntervalSinceNow] * 0.15;
	timer.tolerance = (tolerance < 1 ? 1 : tolerance); // at least 1 sec
	timer.fireDate = nextTime;
}

/**
 Called when schedule timer runs out (earliest @c .schedule date). Or if forced by user request.
 */
+ (void)updateTimerCallback {
	if (![self allowNetworkConnection])
		return;
	NSLog(@"fired");
	
	BOOL updateAll = _nextUpdateIsForced;
	_nextUpdateIsForced = NO;
	
	NSManagedObjectContext *moc = [StoreCoordinator createChildContext];
	NSArray<Feed*> *list = [StoreCoordinator getListOfFeedsThatNeedUpdate:updateAll inContext:moc];
	//NSAssert(list.count > 0, @"ERROR: Something went wrong, timer fired too early.");
	
	[FeedDownload batchUpdateFeeds:list showErrorAlert:NO finally:^(NSArray<Feed*> *successful, NSArray<Feed*> *failed) {
		[self saveContext:moc andPostChanges:successful];
		[moc reset];
		[self resumeUpdates]; // always reset the timer
	}];
}

/**
 Perform save on context and all parents. Then post @c FeedUpdated notification.
 */
+ (void)saveContext:(NSManagedObjectContext*)moc andPostChanges:(NSArray<Feed*>*)changedFeeds {
	[StoreCoordinator saveContext:moc andParent:YES];
	if (changedFeeds && changedFeeds.count > 0) {
		NSArray<NSManagedObjectID*> *list = [changedFeeds valueForKeyPath:@"objectID"];
		[[NSNotificationCenter defaultCenter] postNotificationName:kNotificationFeedUpdated object:list];
	}
}


#pragma mark - Request Generator -


/// @return Base URL part. E.g., https://stackoverflow.com/a/15897956/10616114 ==> https://stackoverflow.com/
+ (NSURL*)hostURL:(NSString*)urlStr {
	return [[NSURL URLWithString:@"/" relativeToURL:[self fixURL:urlStr]] absoluteURL];
}

/// Check if any scheme is set. If not, prepend 'http://'.
+ (NSURL*)fixURL:(NSString*)urlStr {
	NSURL *url = [NSURL URLWithString:urlStr];
	if (!url.scheme) {
		url = [NSURL URLWithString:[NSString stringWithFormat:@"http://%@", urlStr]]; // usually will redirect to https if necessary
	}
	return url;
}

/// @return New request with no caching policy and timeout interval of 30 seconds.
+ (NSMutableURLRequest*)newRequestURL:(NSString*)urlStr {
	NSMutableURLRequest *req = [NSMutableURLRequest requestWithURL:[self fixURL:urlStr]];
	req.cachePolicy = NSURLRequestReloadIgnoringLocalCacheData;
	req.HTTPShouldHandleCookies = NO;
//	req.timeoutInterval = 30;
//	[req setValue:@"Mon, 10 Sep 2018 10:32:19 GMT" forHTTPHeaderField:@"If-Modified-Since"];
//	[req setValue:@"wII2pETT9EGmlqyCHBFJpm25/7w" forHTTPHeaderField:@"If-None-Match"]; // ETag
	return req;
}

/// @return New request with etag and modified headers set.
+ (NSURLRequest*)newRequest:(FeedMeta*)meta {
	NSMutableURLRequest *req = [self newRequestURL:meta.url];
	NSString* etag = [meta.etag stringByReplacingOccurrencesOfString:@"-gzip" withString:@""];
	if (meta.modified.length > 0)
		[req setValue:meta.modified forHTTPHeaderField:@"If-Modified-Since"];
	if (etag.length > 0)
		[req setValue:etag forHTTPHeaderField:@"If-None-Match"]; // ETag
	if (!_nextUpdateIsForced) // any FeedMeta-request that is not forced, is a background update
		req.networkServiceType = NSURLNetworkServiceTypeBackground;
	return req;
}

/**
 Start download session of RSS or Atom feed, parse feed and return result on the main thread.
 
 @param block Called when parsing finished or an @c NSURL error occured.
              If content did not change (status code 304) both, error and result will be @c nil.
              Will be called on main thread.
 */
+ (void)parseFeedRequest:(NSURLRequest*)request block:(nonnull void(^)(RSParsedFeed *rss, NSError *error, NSHTTPURLResponse *response))block {
	[[[NSURLSession sharedSession] dataTaskWithRequest:request completionHandler:^(NSData * _Nullable data, NSURLResponse * _Nullable response, NSError * _Nullable error) {
		NSHTTPURLResponse* httpResponse = (NSHTTPURLResponse*)response;
		if (error || [httpResponse statusCode] == 304) {
			dispatch_async(dispatch_get_main_queue(), ^{
				block(nil, error, httpResponse); // error = nil if status == 304
			});
		} else {
			RSXMLData *xml = [[RSXMLData alloc] initWithData:data urlString:httpResponse.URL.absoluteString];
			RSFeedParser *parser = [RSFeedParser parserWithXMLData:xml];
			[parser parseAsync:^(RSParsedFeed * _Nullable parsedFeed, NSError * _Nullable err) {
				dispatch_async(dispatch_get_main_queue(), ^{
					block(parsedFeed, err, httpResponse);
				});
			}];
		}
	}] resume];
}


#pragma mark - Download RSS Feed -


/**
 Perform feed download request from URL alone. Not updating any @c Feed item.
 */
+ (void)newFeed:(NSString *)urlStr block:(void(^)(RSParsedFeed *parsed, NSError *error, NSHTTPURLResponse *response))block {
	[self parseFeedRequest:[self newRequestURL:urlStr] block:block];
}

/**
 Start download request with existing @c Feed object. Reuses etag and modified headers.

 @param feed @c Feed on which the update is executed.
 @param group Mutex to count completion of all downloads.
 @param alert If @c YES display Error Popup to user.
 @param successful Empty, mutable list that will be returned in @c batchUpdateFeeds:finally:showErrorAlert: finally block
 @param failed Empty, mutable list that will be returned in @c batchUpdateFeeds:finally:showErrorAlert: finally block
 */
+ (void)downloadFeed:(Feed*)feed group:(dispatch_group_t)group
		  errorAlert:(BOOL)alert
		  successful:(nonnull NSMutableArray<Feed*>*)successful
			  failed:(nonnull NSMutableArray<Feed*>*)failed
{
	if (![self allowNetworkConnection]) {
		[failed addObject:feed];
		return;
	}
	dispatch_group_enter(group);
	[self parseFeedRequest:[self newRequest:feed.meta] block:^(RSParsedFeed *rss, NSError *error, NSHTTPURLResponse *response) {
		if (error) {
			if (alert) [NSApp presentError:error];
			[feed.meta setErrorAndPostponeSchedule];
			[failed addObject:feed];
		} else {
			[feed.meta setSucessfulWithResponse:response];
			if (rss) [feed updateWithRSS:rss postUnreadCountChange:YES];
			[successful addObject:feed]; // will be added even if statusCode == 304 (rss == nil)
		}
		dispatch_group_leave(group);
	}];
}

/**
 Download feed at url and append to persistent store in root folder.
 On error present user modal alert.
 
 Creates new @c FeedGroup, @c Feed, @c FeedMeta and @c FeedArticle instances and saves them to the persistent store.
 Update duration is set to the default of 30 minutes.
 */
+ (void)autoDownloadAndParseURL:(NSString*)url {
	NSManagedObjectContext *moc = [StoreCoordinator createChildContext];
	Feed *f = [Feed appendToRootWithDefaultIntervalInContext:moc];
	f.meta.url = url;
	[self batchDownloadRSSAndFavicons:@[f] showErrorAlert:YES rssFinished:^(NSArray<Feed *> *successful, BOOL *cancelFavicons) {
		if (successful.count == 0) {
			*cancelFavicons = YES;
		} else {
			[self saveContext:moc andPostChanges:successful];
		}
	} finally:^(BOOL successful) {
		if (successful) {
			[StoreCoordinator saveContext:moc andParent:YES];
		} else {
			[moc rollback];
		}
		[moc reset];
	}];
}

/**
 Perform a download /update request for the feed data and download missing favicons.
 If neither block is set, favicons will be downloaded and stored automatically.
 However, you should handle the case

 @param list List of feeds that need update. Its sufficient if @c feed.meta.url is set.
 @param flag If @c YES display Error Popup to user.
 @param blockXml Called after XML is downloaded and parsed.
                 Parameter @c successful is list of feeds that were downloaded.
                 Set @c cancelFavicons to @c YES to call @c finally block without downloading favicons. Default: @c NO.
 @param blockFavicon Called after all downloads are finished.
                     @c successful is set to @c NO if favicon download was prohibited in @c blockXml or list is empty.
 */
+ (void)batchDownloadRSSAndFavicons:(NSArray<Feed*> *)list
					 showErrorAlert:(BOOL)flag
						rssFinished:(void(^)(NSArray<Feed*> *successful, BOOL * cancelFavicons))blockXml
							finally:(void(^)(BOOL successful))blockFavicon
{
	[self batchUpdateFeeds:list showErrorAlert:flag finally:^(NSArray<Feed*> *successful, NSArray<Feed*> *failed) {
		BOOL cancelFaviconsDownload = NO;
		if (blockXml) {
			blockXml(successful, &cancelFaviconsDownload);
		}
		if (cancelFaviconsDownload || successful.count == 0) {
			if (blockFavicon) blockFavicon(NO);
		} else {
			[self batchDownloadFavicons:successful replaceExisting:NO finally:^{
				if (blockFavicon) blockFavicon(YES);
			}];
		}
	}];
}

/**
 Create download list of feed URLs and download them all at once. Finally, notify when all finished.
 
 @param list Download list using @c feed.meta.url as download url. (while reusing etag and modified headers)
 @param flag If @c YES display Error Popup to user.
 @param block Called after all downloads finished @b OR if list is empty (in that case both parameters are @c nil ).
 */
+ (void)batchUpdateFeeds:(NSArray<Feed*> *)list showErrorAlert:(BOOL)flag finally:(void(^)(NSArray<Feed*> *successful, NSArray<Feed*> *failed))block {
	if (!list || list.count == 0) {
		if (block) block(nil, nil);
		return;
	}
	// else, process all feed items in a batch
	NSMutableArray<Feed*> *successful = [NSMutableArray arrayWithCapacity:list.count];
	NSMutableArray<Feed*> *failed = [NSMutableArray arrayWithCapacity:list.count];
	
	dispatch_group_t group = dispatch_group_create();
	for (Feed *feed in list) {
		[self downloadFeed:feed group:group errorAlert:flag successful:successful failed:failed];
	}
	dispatch_group_notify(group, dispatch_get_main_queue(), ^{
		if (block) block(successful, failed);
	});
}


#pragma mark - Favicon -


/**
 Create download list of @c favicon.ico URLs and save downloaded images to persistent store.
 
 @param list Download list using @c feed.link as download url. If empty fall back to @c feed.meta.url
 @param flag If @c YES display Error Popup to user.
 @param block Called after all downloads finished.
 */
+ (void)batchDownloadFavicons:(NSArray<Feed*> *)list replaceExisting:(BOOL)flag finally:(os_block_t)block {
	dispatch_group_t group = dispatch_group_create();
	for (Feed *f in list) {
		if (!flag && f.icon != nil) {
			continue; // skip existing icons if replace == NO
		}
		NSManagedObjectID *oid = f.objectID;
		NSManagedObjectContext *moc = f.managedObjectContext;
		NSString *faviconURL = (f.link.length > 0 ? f.link : f.meta.url);
		
		dispatch_group_enter(group);
		[self downloadFavicon:faviconURL finished:^(NSImage *img) {
			Feed *feed = [moc objectWithID:oid]; // should also work if context was reset
			[feed setIcon:img replaceExisting:flag];
			dispatch_group_leave(group);
		}];
	}
	dispatch_group_notify(group, dispatch_get_main_queue(), ^{
		if (block) block();
	});
}

/// Download favicon located at http://.../ @c favicon.ico. Callback @c block will be called on main thread.
+ (void)downloadFavicon:(NSString*)urlStr finished:(void(^)(NSImage * _Nullable img))block {
	dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
		NSURL *favURL = [[self hostURL:urlStr] URLByAppendingPathComponent:@"favicon.ico"];
		NSImage *img = [[NSImage alloc] initWithContentsOfURL:favURL];
		if (!img || ![img isValid])
			img = nil;
//		if (img.size.width > 16 || img.size.height > 16) {
//			NSImage *smallImage = [NSImage imageWithSize:NSMakeSize(16, 16) flipped:NO drawingHandler:^BOOL(NSRect dstRect) {
//				[img drawInRect:dstRect];
//				return YES;
//			}];
//			if (img.TIFFRepresentation.length > smallImage.TIFFRepresentation.length)
//				img = smallImage;
//		}
		dispatch_async(dispatch_get_main_queue(), ^{
			block(img);
		});
	});
}


#pragma mark - Network Connection & Reachability -


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
	_isReachable = [FeedDownload hasConnectivity:flags];
	[[NSNotificationCenter defaultCenter] postNotificationName:kNotificationNetworkStatusChanged object:@(_isReachable)];
	if (_isReachable) {
		NSLog(@"reachable");
		[FeedDownload resumeUpdates];
	} else {
		NSLog(@"not reachable");
		[FeedDownload pauseUpdates];
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
