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

#ifndef Constants_h
#define Constants_h

// TODO: Add support for media player? image feed?
// <enclosure url="https://url.mp3" length="63274022" type="audio/mpeg" />
// TODO: Disable 'update all' menu item during update?
// TODO: List of hidden preferences for readme
// TODO: Do we need to search for favicon in places other than '../favicon.ico'?

/**
 @c notification.object is @c NSNumber of type @c NSUInteger.
 Represents number of feeds that are proccessed in background update. Sends @c 0 when all downloads are finished.
 */
static NSString *kNotificationBackgroundUpdateInProgress = @"baRSS-notification-background-update-in-progress";
/**
 @c notification.object is @c NSManagedObjectID of type @c Feed.
 Called whenever download of a feed finished and object was modified (not if statusCode 304).
 */
static NSString *kNotificationFeedUpdated = @"baRSS-notification-feed-updated";
/**
 @c notification.object is @c NSManagedObjectID of type @c Feed.
 Called whenever the icon attribute of an item was updated.
 */
static NSString *kNotificationFeedIconUpdated = @"baRSS-notification-feed-icon-updated";
/**
 @c notification.object is @c NSNumber of type @c BOOL.
 @c YES if network became reachable. @c NO on connection lost.
 */
static NSString *kNotificationNetworkStatusChanged = @"baRSS-notification-network-status-changed";
/**
 @c notification.object is @c NSNumber of type @c NSInteger.
 Represents a relative change (e.g., negative if items were marked read)
 */
static NSString *kNotificationTotalUnreadCountChanged = @"baRSS-notification-total-unread-count-changed";
/**
 @c notification.object is either @c nil or @c NSNumber of type @c NSInteger.
 If new count is known an absoulte number is passed.
 Else @c nil if count has to be fetched from core data.
 */
static NSString *kNotificationTotalUnreadCountReset = @"baRSS-notification-total-unread-count-reset";


/**
 Internal developer method for benchmarking purposes.
 */
extern uint64_t dispatch_benchmark(size_t count, void (^block)(void));
//void benchmark(char *desc, dispatch_block_t b){printf("%s: %llu ns\n", desc, dispatch_benchmark(1, b));}
#define benchmark(desc,block) printf(desc": %llu ns\n", dispatch_benchmark(1, block));

#endif /* Constants_h */
