@import Cocoa;

@class Feed;

NS_ASSUME_NONNULL_BEGIN

@interface UpdateScheduler : NSObject
@property (class, readonly) NSUInteger feedsInQueue;
@property (class, readonly) NSDate *dateScheduled;
@property (class, readonly) BOOL allowNetworkConnection;
@property (class, readonly) BOOL isUpdating;
@property (class, setter=setPaused:) BOOL isPaused;

// Getter
+ (NSString*)remainingTimeTillNextUpdate:(nullable double*)remaining;
+ (NSString*)updatingXFeeds;
// Scheduling
+ (void)scheduleNextFeed;
+ (void)forceUpdate:(NSString*)indexPath;
+ (void)downloadList:(NSArray<Feed*>*)list userInitiated:(BOOL)flag notifications:(BOOL)notify finally:(nullable os_block_t)block;
+ (void)updateAllFavicons;
// Auto Download & Parse Feed URL
+ (void)autoDownloadAndParseURL:(NSString*)url;
+ (void)autoDownloadAndParseUpdateURL;
// Register for network change notifications
+ (void)registerNetworkChangeNotification;
+ (void)unregisterNetworkChangeNotification;
@end

NS_ASSUME_NONNULL_END
