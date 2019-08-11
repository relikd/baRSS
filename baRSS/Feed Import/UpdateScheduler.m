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
#import "WebFeed.h"
#import "Constants.h"
#import "StoreCoordinator.h"

static NSTimer *_timer;
static SCNetworkReachabilityRef _reachability = NULL;
static BOOL _isReachable = NO;
static BOOL _isUpdating = NO;
static BOOL _updatePaused = NO;
static BOOL _nextUpdateIsForced = NO;


@implementation UpdateScheduler

#pragma mark - User Interaction

/// @return Number of feeds being currently downloaded.
+ (NSUInteger)feedsInQueue { return [WebFeed feedsInQueue]; }

/// @return Date when background update will fire. If updates are paused, date is @c distantFuture.
+ (NSDate *)dateScheduled { return _timer.fireDate; }

/// @return @c YES if current network state is reachable and updates are not paused by user.
+ (BOOL)allowNetworkConnection { return (_isReachable && !_updatePaused); }

/// @return @c YES if batch update is running
+ (BOOL)isUpdating { return _isUpdating; }

/// @return @c YES if update is paused by user.
+ (BOOL)isPaused { return _updatePaused; }

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
		[self scheduleNextFeed];
}

/// Set @c isUpdating @c = @c YES
+ (void)beginUpdate { _isUpdating = YES; }

/// Set @c isUpdating @c = @c NO
+ (void)endUpdate { _isUpdating = NO; }


#pragma mark - Update Feed Timer


/**
 Get date of next up feed and start the timer.
 */
+ (void)scheduleNextFeed {
	if (![self allowNetworkConnection]) // timer will restart once connection exists
		return;
	NSDate *nextTime = [StoreCoordinator nextScheduledUpdate]; // if nextTime = nil, then no feeds to update
	if (nextTime && [nextTime timeIntervalSinceNow] < 1) { // mostly, if app was closed for a long time
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
	[self scheduleTimer:[NSDate dateWithTimeIntervalSinceNow:0.05]];
}

/**
 Set new @c .fireDate and @c .tolerance for update timer.

 @param nextTime If @c nil timer will be disabled with a @c .fireDate very far in the future.
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
}

/**
 Called when schedule timer runs out (earliest @c .schedule date). Or if forced by user request.
 */
+ (void)updateTimerCallback {
#ifdef DEBUG
	NSLog(@"fired");
#endif
	BOOL updateAll = _nextUpdateIsForced;
	_nextUpdateIsForced = NO;
	if (updateAll)
		[WebFeed setRequestsAreUrgent:YES];
	
	NSManagedObjectContext *moc = [StoreCoordinator createChildContext];
	NSArray<Feed*> *list = [StoreCoordinator getListOfFeedsThatNeedUpdate:updateAll inContext:moc];
	//NSAssert(list.count > 0, @"ERROR: Something went wrong, timer fired too early.");
	if (![self allowNetworkConnection]) {
		[WebFeed setRequestsAreUrgent:NO];
		[moc reset];
		return;
	}
	[WebFeed batchDownloadFeeds:list favicons:updateAll showErrorAlert:NO finally:^{
		[WebFeed setRequestsAreUrgent:NO];
		[StoreCoordinator saveContext:moc andParent:YES]; // save parents too ...
		[moc reset];
		[self resumeUpdates]; // always reset the timer
	}];
}


#pragma mark - Network Connection & Reachability


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
		[UpdateScheduler resumeUpdates];
	} else {
		[UpdateScheduler pauseUpdates];
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
