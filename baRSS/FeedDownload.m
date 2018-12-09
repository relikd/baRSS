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
	
	__block NSManagedObjectContext *childContext = [StoreCoordinator createChildContext];
	NSArray<Feed*> *list = [StoreCoordinator getListOfFeedsThatNeedUpdate:_nextUpdateIsForced inContext:childContext];
	_nextUpdateIsForced = NO;
	if (list.count == 0) {
		NSLog(@"ERROR: Something went wrong, timer fired too early.");
		[childContext reset];
		childContext = nil;
		// thechnically should never happen, anyway we need to reset the timer
		[self resumeUpdates];
		return; // nothing to do here
	}
	dispatch_group_t group = dispatch_group_create();
	for (Feed *feed in list) {
		[self downloadFeed:feed group:group];
	}
	dispatch_group_notify(group, dispatch_get_main_queue(), ^{
		[StoreCoordinator saveContext:childContext andParent:YES];
		[[NSNotificationCenter defaultCenter] postNotificationName:kNotificationFeedUpdated object:[list valueForKeyPath:@"objectID"]];
		[childContext reset];
		childContext = nil;
		[self resumeUpdates];
	});
}


#pragma mark - Download RSS Feed -


/// @return New request with no caching policy and timeout interval of 30 seconds.
+ (NSMutableURLRequest*)newRequestURL:(NSString*)url {
	NSMutableURLRequest *req = [NSMutableURLRequest requestWithURL:[NSURL URLWithString:url]];
	req.timeoutInterval = 30;
	req.cachePolicy = NSURLRequestReloadIgnoringCacheData;
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
	return req;
}

/**
 Perform feed download request from URL alone. Not updating any @c Feed item.
 */
+ (void)newFeed:(NSString *)url block:(void(^)(RSParsedFeed *feed, NSError* error, NSHTTPURLResponse* response))block {
	[[[NSURLSession sharedSession] dataTaskWithRequest:[self newRequestURL:url] completionHandler:^(NSData * _Nullable data, NSURLResponse * _Nullable response, NSError * _Nullable error) {
		NSHTTPURLResponse* httpResponse = (NSHTTPURLResponse*)response;
		if (error || [httpResponse statusCode] == 304) {
			block(nil, error, httpResponse);
			return;
		}
		RSXMLData *xml = [[RSXMLData alloc] initWithData:data urlString:url];
		RSParseFeed(xml, ^(RSParsedFeed * _Nullable parsedFeed, NSError * _Nullable err) {
			if (!err && (!parsedFeed || parsedFeed.articles.count == 0)) { // TODO: this should be fixed in RSXMLParser
				NSString *errDesc = NSLocalizedString(@"URL does not contain a RSS feed. Can't parse feed items.", nil);
				err = [NSError errorWithDomain:NSURLErrorDomain code:NSURLErrorUnsupportedURL userInfo:@{NSLocalizedDescriptionKey: errDesc}];
			}
			block(parsedFeed, err, httpResponse);
		});
	}] resume];
}

/**
 Start download request with existing @c Feed object. Reuses etag and modified headers.

 @param feed @c Feed on which the update is executed.
 @param group Mutex to count completion of all downloads.
 */
+ (void)downloadFeed:(Feed*)feed group:(dispatch_group_t)group {
	if (![self allowNetworkConnection])
		return;
	dispatch_group_enter(group);
	[[[NSURLSession sharedSession] dataTaskWithRequest:[self newRequest:feed.meta] completionHandler:^(NSData * _Nullable data, NSURLResponse * _Nullable response, NSError * _Nullable error) {
		[feed.managedObjectContext performBlock:^{
			// core data block inside of url session block; otherwise access will EXC_BAD_INSTRUCTION
			if (error) {
				[feed.meta setErrorAndPostponeSchedule];
			} else {
				[feed.meta setEtagAndModified:(NSHTTPURLResponse*)response];
				[feed.meta calculateAndSetScheduled];
				
				if ([(NSHTTPURLResponse*)response statusCode] != 304) { // only parse if modified
					// should be fine to call synchronous since dataTask is already in the background (always? proof?)
					RSXMLData *xml = [[RSXMLData alloc] initWithData:data urlString:feed.meta.url];
					RSParsedFeed *parsed = RSParseFeedSync(xml, NULL);
					if (parsed && parsed.articles.count > 0) {
						[feed updateWithRSS:parsed postUnreadCountChange:YES];
						feed.meta.errorCount = 0; // reset counter
					} else {
						[feed.meta setErrorAndPostponeSchedule]; // replaces date of 'calculateAndSetScheduled'
					}
				}
				// TODO: save changes for this feed only?
				//[[NSNotificationCenter defaultCenter] postNotificationName:kNotificationFeedUpdated object:feed.objectID];
			}
			dispatch_group_leave(group);
		}];
	}] resume];
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
