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

@import Cocoa;

// TODO: Add support for media player? image feed?
// <enclosure url="https://url.mp3" length="63274022" type="audio/mpeg" />
// TODO: Disable 'update all' menu item during update?


/// UTI type used for opml files
static NSPasteboardType const UTI_OPML = @"org.opml";
/// URL with newest baRSS releases. Automatically added when user starts baRSS for the first time.
static NSString* const versionUpdateURL = @"https://github.com/relikd/baRSS/releases.atom";


#pragma mark - NSImageName constants


/// Default RSS icon (with border, with gradient, orange)
static NSImageName const RSSImageDefaultRSSIcon    = @"RSSImageDefaultRSSIcon";
/// Settings, global icon (menu bar, black)
static NSImageName const RSSImageSettingsGlobal    = @"RSSImageSettingsGlobal";
/// Settings, group icon (folder, black)
static NSImageName const RSSImageSettingsGroup     = @"RSSImageSettingsGroup";
/// Settings, feed icon (RSS, no border, no gradient, black)
static NSImageName const RSSImageSettingsFeed      = @"RSSImageSettingsFeed";
/// Menu bar, bar icon (RSS, with border, no gradient, orange)
static NSImageName const RSSImageMenuBarIconActive = @"RSSImageMenuBarIconActive";
/// Menu bar, bar icon (RSS, with border, no gradient, paused, orange)
static NSImageName const RSSImageMenuBarIconPaused = @"RSSImageMenuBarIconPaused";
/// Menu item, unread state icon (blue dot)
static NSImageName const RSSImageMenuItemUnread    = @"RSSImageMenuItemUnread";


#pragma mark - NSNotificationName constants


/// Helper method calls @c (defaultCenter)postNotification:
NS_INLINE void PostNotification(NSNotificationName name, id obj) { [[NSNotificationCenter defaultCenter] postNotificationName:name object:obj]; }
NS_INLINE void RegisterNotification(NSNotificationName name, SEL action, id observer) { [[NSNotificationCenter defaultCenter] addObserver:observer selector:action name:name object:nil]; }
/**
 @c notification.object is @c NSNumber of type @c NSUInteger.
 Represents number of feeds that are proccessed in background update. Sends @c 0 when all downloads are finished.
 */
static NSNotificationName const kNotificationBackgroundUpdateInProgress = @"baRSS-notification-background-update-in-progress";
/**
 @c notification.object is @c NSManagedObjectID of type @c FeedGroup.
 Called whenever a new feed group was created in @c autoDownloadAndParseURL:
 */
static NSNotificationName const kNotificationGroupInserted = @"baRSS-notification-group-inserted";
/**
 @c notification.object is @c NSManagedObjectID of type @c Feed.
 Called whenever download of a feed finished and object was modified (not if statusCode 304).
 */
static NSNotificationName const kNotificationFeedUpdated = @"baRSS-notification-feed-updated";
/**
 @c notification.object is @c NSManagedObjectID of type @c Feed.
 Called whenever the icon attribute of an item was updated.
 */
static NSNotificationName const kNotificationFeedIconUpdated = @"baRSS-notification-feed-icon-updated";
/**
 @c notification.object is @c NSNumber of type @c BOOL.
 @c YES if network became reachable. @c NO on connection lost.
 */
static NSNotificationName const kNotificationNetworkStatusChanged = @"baRSS-notification-network-status-changed";
/**
 @c notification.object is @c NSNumber of type @c NSInteger.
 Represents a relative change (e.g., negative if items were marked read)
 */
static NSNotificationName const kNotificationTotalUnreadCountChanged = @"baRSS-notification-total-unread-count-changed";
/**
 @c notification.object is either @c nil or @c NSNumber of type @c NSInteger.
 If new count is known an absoulte number is passed.
 Else @c nil if count has to be fetched from core data.
 */
static NSNotificationName const kNotificationTotalUnreadCountReset = @"baRSS-notification-total-unread-count-reset";


#pragma mark - Internal


/**
 Internal developer method for benchmarking purposes.
 */
extern uint64_t dispatch_benchmark(size_t count, void (^block)(void));
//void benchmark(char *desc, dispatch_block_t b){printf("%s: %llu ns\n", desc, dispatch_benchmark(1, b));}
#define benchmark(desc,block) printf(desc": %llu ns\n", dispatch_benchmark(1, block));

#endif /* Constants_h */
