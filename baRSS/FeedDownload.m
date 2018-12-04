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
#import <SystemConfiguration/SystemConfiguration.h>

static SCNetworkReachabilityRef _reachability = NULL;
static BOOL _isReachable = NO;


@implementation FeedDownload

+ (NSMutableURLRequest*)newRequestURL:(NSString*)url {
	NSMutableURLRequest *req = [NSMutableURLRequest requestWithURL:[NSURL URLWithString:url]];
	req.timeoutInterval = 30;
	req.cachePolicy = NSURLRequestReloadIgnoringCacheData;
//	[req setValue:@"Mon, 10 Sep 2018 10:32:19 GMT" forHTTPHeaderField:@"If-Modified-Since"];
//	[req setValue:@"wII2pETT9EGmlqyCHBFJpm25/7w" forHTTPHeaderField:@"If-None-Match"]; // ETag
	return req;
}

+ (NSURLRequest*)newRequest:(FeedConfig*)config {
	NSMutableURLRequest *req = [self newRequestURL:config.url];
	NSString* etag = [config.meta.httpEtag stringByReplacingOccurrencesOfString:@"-gzip" withString:@""];
	if (config.meta.httpModified.length > 0)
		[req setValue:config.meta.httpModified forHTTPHeaderField:@"If-Modified-Since"];
	if (etag.length > 0)
		[req setValue:etag forHTTPHeaderField:@"If-None-Match"]; // ETag
	return req;
}

+ (void)newFeed:(NSString *)url block:(void(^)(RSParsedFeed *feed, NSError* error, NSHTTPURLResponse* response))block {
	[[[NSURLSession sharedSession] dataTaskWithRequest:[self newRequestURL:url] completionHandler:^(NSData * _Nullable data, NSURLResponse * _Nullable response, NSError * _Nullable error) {
		NSHTTPURLResponse* httpResponse = (NSHTTPURLResponse*)response;
		if (error || [httpResponse statusCode] == 304) {
			block(nil, error, httpResponse);
			return;
		}
		RSXMLData *xml = [[RSXMLData alloc] initWithData:data urlString:url];
		RSParseFeed(xml, ^(RSParsedFeed * _Nullable parsedFeed, NSError * _Nullable err) {
			block(parsedFeed, err, httpResponse);
		});
	}] resume];
}


#pragma mark - Update existing feeds -


+ (void)scheduleNextUpdate:(BOOL)forceUpdate {
	static NSTimer *_updateTimer;
	@synchronized (_updateTimer) { // TODO: dig into analyzer warning
		if (_updateTimer) {
			[_updateTimer invalidate];
			_updateTimer = nil;
		}
	}
	if (!_isReachable) return; // cancel timer entirely (will be restarted once connection exists)
	NSDate *nextTime = [NSDate dateWithTimeIntervalSinceNow:0.2];
	if (!forceUpdate) {
		nextTime = [StoreCoordinator nextScheduledUpdate];
		if (!nextTime || [nextTime timeIntervalSinceNow] < 0) { // mostly, if app was closed for a long time
			nextTime = [NSDate dateWithTimeIntervalSinceNow:2]; // TODO: retry in 2 sec?
		}
	}
	NSTimeInterval tolerance = [nextTime timeIntervalSinceNow] * 0.15;
	_updateTimer = [NSTimer timerWithTimeInterval:0 target:[self class] selector:@selector(scheduledUpdateTimer:) userInfo:@(forceUpdate) repeats:NO];
	_updateTimer.fireDate = nextTime;
	_updateTimer.tolerance = (tolerance < 1 ? 1 : tolerance); // at least 1 sec
	[[NSRunLoop mainRunLoop] addTimer:_updateTimer forMode:NSRunLoopCommonModes];
}

+ (void)scheduledUpdateTimer:(NSTimer*)timer {
	NSLog(@"fired");
	BOOL forceAll = [timer.userInfo boolValue];
	// TODO: check internet connection
	// TODO: disable menu item 'update all' during update
	__block NSManagedObjectContext *childContext = [StoreCoordinator createChildContext];
	NSArray<FeedConfig*> *list = [StoreCoordinator getListOfFeedsThatNeedUpdate:forceAll inContext:childContext];
	if (list.count == 0) {
		NSLog(@"ERROR: Something went wrong, timer fired too early.");
		[childContext reset];
		childContext = nil;
		// thechnically should never happen, anyway we need to reset the timer
		[self scheduleNextUpdate:NO]; // NO, since forceAll will get ALL items and shouldn't be 0
		return; // nothing to do here
	}
	dispatch_group_t group = dispatch_group_create();
	for (FeedConfig *c in list) {
		[self downloadFeedForConfig:c group:group];
	}
	dispatch_group_notify(group, dispatch_get_main_queue(), ^{
		[StoreCoordinator saveContext:childContext andParent:YES];
		[[NSNotificationCenter defaultCenter] postNotificationName:kNotificationFeedUpdated object:[list valueForKeyPath:@"objectID"]];
		[childContext reset];
		childContext = nil;
		[self scheduleNextUpdate:NO]; // after forced update, continue regular cycle
	});
}

+ (void)downloadFeedForConfig:(FeedConfig*)config group:(dispatch_group_t)group {
	if (!_isReachable) return;
	dispatch_group_enter(group);
	[[[NSURLSession sharedSession] dataTaskWithRequest:[self newRequest:config] completionHandler:^(NSData * _Nullable data, NSURLResponse * _Nullable response, NSError * _Nullable error) {
		[config.managedObjectContext performBlock:^{
			// core data block inside of url session block; otherwise config access will EXC_BAD_INSTRUCTION
			if (error) {
				int16_t n = config.errorCount + 1;
				config.errorCount = (n < 1 ? 1 : (n > 19 ? 19 : n)); // between: 2 sec and 6 days
				NSTimeInterval retryWaitTime = pow(2, config.errorCount); // 2^n seconds
				config.scheduled = [NSDate dateWithTimeIntervalSinceNow:retryWaitTime];
				// TODO: remove logging
				NSLog(@"Error loading: %@ (%d)", response.URL, config.errorCount);
			} else {
				config.errorCount = 0; // reset counter
				[self downloadSuccessful:data forFeed:config response:(NSHTTPURLResponse*)response];
			}
			dispatch_group_leave(group);
		}];
	}] resume];
}

+ (void)downloadSuccessful:(NSData*)data forFeed:(FeedConfig*)config response:(NSHTTPURLResponse*)http {
	if ([http statusCode] != 304) {
		// should be fine to call synchronous since dataTask is already in the background (always? proof?)
		RSXMLData *xml = [[RSXMLData alloc] initWithData:data urlString:config.url];
		RSParsedFeed *parsed = RSParseFeedSync(xml, NULL);
		if (parsed) {
			// TODO: add support for media player?
			// <enclosure url="https://url.mp3" length="63274022" type="audio/mpeg" />
			[config updateRSSFeed:parsed];
		}
	}
	[config setEtag:[http allHeaderFields][@"Etag"] modified:[http allHeaderFields][@"Date"]]; // @"Expires", @"Last-Modified"
	// Don't update redirected url since it happened in the background; User may not recognize url
	[config calculateAndSetScheduled];
//	[config mergeChangesAndSave];
//	[config.managedObjectContext performBlock:^{
//		[[NSNotificationCenter defaultCenter] postNotificationName:kNotificationFeedUpdated object:config.objectID];
//	}];
}


#pragma mark - Network Connection -


+ (BOOL)isNetworkReachable { return _isReachable; }

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

+ (void)unregisterNetworkChangeNotification {
	if (_reachability != NULL) {
		SCNetworkReachabilitySetCallback(_reachability, nil, nil);
		SCNetworkReachabilitySetDispatchQueue(_reachability, nil);
		CFRelease(_reachability);
		_reachability = NULL;
	}
}

static void networkReachabilityCallback(SCNetworkReachabilityRef target, SCNetworkConnectionFlags flags, void *object) {
	if (_reachability == NULL)
		return;
	_isReachable = [FeedDownload hasConnectivity:flags];
	[[NSNotificationCenter defaultCenter] postNotificationName:kNotificationNetworkStatusChanged
														object:[NSNumber numberWithBool:_isReachable]];
	if (_isReachable)    {
		NSLog(@"reachable");
	} else {
		NSLog(@"not reachable");
	}
	// schedule regardless of state (if not reachable timer will be canceled)
	[FeedDownload scheduleNextUpdate:NO];
}

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
