#ifndef Constants_h
#define Constants_h

@import Cocoa;

// TODO: Add support for media player? image feed?
// <enclosure url="https://url.mp3" length="63274022" type="audio/mpeg" />
// TODO: Disable 'update all' menu item during update?
// TODO: SQlite instead of CoreData?  https://www.objc.io/issues/4-core-data/SQLite-instead-of-core-data/


/// UTI type used for opml files
static NSPasteboardType const UTI_OPML = @"org.opml.opml";
/// URL with newest baRSS releases. Automatically added when user starts baRSS for the first time.
static NSString* const versionUpdateURL = @"https://github.com/relikd/baRSS/releases.atom";
/// URL to help page of auxiliary application "URL Scheme Defaults"
static NSString* const auxiliaryAppURL = @"https://github.com/relikd/URL-Scheme-Defaults#url-scheme-defaults";


#pragma mark - NSImageName constants


/// Default RSS icon (with border, with gradient, orange)
static NSImageName const RSSImageDefaultRSSIcon        = @"RSSImageDefaultRSSIcon";
/// Settings, global statusbar icon (rss icon with neighbor icons)
static NSImageName const RSSImageSettingsGlobalIcon    = @"RSSImageSettingsGlobalIcon";
/// Settings, global menu icon (menu bar, black)
static NSImageName const RSSImageSettingsGlobalMenu    = @"RSSImageSettingsGlobalMenu";
/// Settings, group icon (folder, black)
static NSImageName const RSSImageSettingsGroup         = @"RSSImageSettingsGroup";
/// Settings, feed icon (RSS, no border, no gradient, black)
static NSImageName const RSSImageSettingsFeed          = @"RSSImageSettingsFeed";
/// Settings, article icon (RSS surrounded by text lines)
static NSImageName const RSSImageSettingsArticle       = @"RSSImageSettingsArticle";
/// Menu bar, bar icon (RSS, with border, no gradient, orange)
static NSImageName const RSSImageMenuBarIconActive     = @"RSSImageMenuBarIconActive";
/// Menu bar, bar icon (RSS, with border, no gradient, paused, orange)
static NSImageName const RSSImageMenuBarIconPaused     = @"RSSImageMenuBarIconPaused";
/// Menu item, unread state icon (blue dot)
static NSImageName const RSSImageMenuItemUnread        = @"RSSImageMenuItemUnread";
/// Feed edit, regex editor icon @c "(.*)"
static NSImageName const RSSImageRegexIcon             = @"RSSImageRegexIcon";


#pragma mark - NSNotificationName constants


/// Helper method calls @c (defaultCenter)postNotification:
static inline void PostNotification(NSNotificationName name, id obj) { [[NSNotificationCenter defaultCenter] postNotificationName:name object:obj]; }
/// Helper method calls @c (defaultCenter)addObserver:
static inline void RegisterNotification(NSNotificationName name, SEL action, id observer) { [[NSNotificationCenter defaultCenter] addObserver:observer selector:action name:name object:nil]; }
/**
 @c notification.object is @c NSNumber of type @c NSUInteger.
 Represents number of feeds that are proccessed in background update. Sends @c 0 when all downloads are finished.
 */
static NSNotificationName const kNotificationBackgroundUpdateInProgress = @"baRSS-notification-background-update-in-progress";
/**
 @c notification.object is @c nil.
 Called whenever the update schedule timer is modified.
 */
static NSNotificationName const kNotificationScheduleTimerChanged = @"baRSS-notification-schedule-timer-changed";
/**
 @c notification.object is @c NSManagedObjectID of type @c FeedGroup.
 Called whenever a new feed group was created in @c autoDownloadAndParseURL:
 */
static NSNotificationName const kNotificationFeedGroupInserted = @"baRSS-notification-feed-inserted";
/**
 @c notification.object is @c NSManagedObjectID of type @c Feed.
 Called whenever download of a feed finished and articles were modified (not if statusCode 304).
 */
static NSNotificationName const kNotificationArticlesUpdated = @"baRSS-notification-articles-updated";
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
