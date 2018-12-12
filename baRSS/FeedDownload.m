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
 Perform feed download request from URL alone. Not updating any @c Feed item.
 */
+ (void)newFeed:(NSString *)urlStr block:(void(^)(RSParsedFeed *feed, NSError *error, NSHTTPURLResponse *response))block {
	[[[NSURLSession sharedSession] dataTaskWithRequest:[self newRequestURL:urlStr] completionHandler:^(NSData * _Nullable data, NSURLResponse * _Nullable response, NSError * _Nullable error) {
		NSHTTPURLResponse* httpResponse = (NSHTTPURLResponse*)response;
		if (error || [httpResponse statusCode] == 304) {
			block(nil, error, httpResponse);
			return;
		}
		RSXMLData *xml = [[RSXMLData alloc] initWithData:data urlString:urlStr];
		RSParseFeed(xml, ^(RSParsedFeed * _Nullable parsedFeed, NSError * _Nullable err) {
			NSAssert(err || parsedFeed, @"Only parse error XOR parsed result can be set. Not both. Neither none.");
			// TODO: Need for error?: "URL does not contain a RSS feed. Can't parse feed items."
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
		NSHTTPURLResponse *header = (NSHTTPURLResponse*)response;
		RSParsedFeed *parsed = nil; // can stay nil if !error and statusCode = 304
		BOOL hasError = (error != nil);
		if (!error && [header statusCode] != 304) { // only parse if modified
			RSXMLData *xml = [[RSXMLData alloc] initWithData:data urlString:header.URL.absoluteString];
			// should be fine to call synchronous since dataTask is already in the background (always? proof?)
			parsed = RSParseFeedSync(xml, &error); // reuse error
			if (error || !parsed || parsed.articles.count == 0) {
				hasError = YES;
			}
		}
		[feed.managedObjectContext performBlock:^{ // otherwise access on feed will EXC_BAD_INSTRUCTION
			if (hasError) {
				[feed.meta setErrorAndPostponeSchedule];
			} else {
				feed.meta.errorCount = 0; // reset counter
				[feed.meta setEtagAndModified:header];
				[feed.meta calculateAndSetScheduled];
				if (parsed) [feed updateWithRSS:parsed postUnreadCountChange:YES];
				// TODO: save changes for this feed only? / Partial Update
				//[[NSNotificationCenter defaultCenter] postNotificationName:kNotificationFeedUpdated object:feed.objectID];
			}
			dispatch_group_leave(group);
		}];
	}] resume];
}

/**
 Download feed at url and append to persistent store in root folder.
 On error present user modal alert.
 */
+ (void)autoDownloadAndParseURL:(NSString*)url {
	[FeedDownload newFeed:url block:^(RSParsedFeed *feed, NSError *error, NSHTTPURLResponse *response) {
		if (error) {
			dispatch_async(dispatch_get_main_queue(), ^{
				[NSApp presentError:error];
			});
		} else {
			[FeedDownload autoParseFeedAndAppendToRoot:feed response:response];
		}
	}];
}

/**
 Create new @c FeedGroup, @c Feed, @c FeedMeta and @c FeedArticle instances and save them to the persistent store.
 Appends feed to the end of the root folder, so that the user will immediatelly see it.
 Update duration is set to the default of 30 minutes.

 @param rss Parsed RSS feed. If @c @c nil no feed object will be added.
 @param response May be @c nil but then feed download URL will not be set.
 */
+ (void)autoParseFeedAndAppendToRoot:(nonnull RSParsedFeed*)rss response:(NSHTTPURLResponse*)response {
	if (!rss || rss.articles.count == 0) return;
	NSManagedObjectContext *moc = [StoreCoordinator createChildContext];
	NSUInteger idx = [StoreCoordinator sortedObjectIDsForParent:nil isFeed:NO inContext:moc].count;
	FeedGroup *newFeed = [FeedGroup newGroup:FEED inContext:moc];
	FeedMeta *meta = newFeed.feed.meta;
	[meta setURL:response.URL.absoluteString refresh:30 unit:RefreshUnitMinutes];
	[meta calculateAndSetScheduled];
	[newFeed setName:rss.title andRefreshString:[meta readableRefreshString]];
	[meta setEtagAndModified:response];
	[newFeed.feed updateWithRSS:rss postUnreadCountChange:YES];
	newFeed.sortIndex = (int32_t)idx;
	[newFeed.feed calculateAndSetIndexPathString];
	[StoreCoordinator saveContext:moc andParent:YES];
	NSString *faviconURL = newFeed.feed.link;
	if (faviconURL.length == 0)
		faviconURL = meta.url;
	[FeedDownload backgroundDownloadFavicon:faviconURL forFeed:newFeed.feed];
	[moc reset];
}

/**
 Try to download @c favicon.ico and save downscaled image to persistent store.
 */
+ (void)backgroundDownloadFavicon:(NSString*)urlStr forFeed:(Feed*)feed {
	NSManagedObjectID *oid = feed.objectID;
	dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
		NSImage *img = [self downloadFavicon:urlStr];
		if (img) {
			NSManagedObjectContext *moc = [StoreCoordinator createChildContext];
			[moc performBlock:^{
				Feed *f = [moc objectWithID:oid];
				if (!f.icon)
					f.icon = [[FeedIcon alloc] initWithEntity:FeedIcon.entity insertIntoManagedObjectContext:moc];
				f.icon.icon = [img TIFFRepresentation];
				[StoreCoordinator saveContext:moc andParent:YES];
				[[NSNotificationCenter defaultCenter] postNotificationName:kNotificationFaviconDownloadFinished object:f.objectID];
				[moc reset];
			}];
		}
	});
}

/// Download favicon located at http://.../ @c favicon.ico and rescale image to @c 16x16.
+ (NSImage*)downloadFavicon:(NSString*)urlStr {
	NSURL *favURL = [[self hostURL:urlStr] URLByAppendingPathComponent:@"favicon.ico"];
	NSImage *img = [[NSImage alloc] initWithContentsOfURL:favURL];
	if (!img) return nil;
	return [NSImage imageWithSize:NSMakeSize(16, 16) flipped:NO drawingHandler:^BOOL(NSRect dstRect) {
		[img drawInRect:dstRect];
		return YES;
	}];
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
