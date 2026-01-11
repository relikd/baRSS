@import Cocoa;
@import UserNotifications;

@class Feed, FeedArticle;

NS_ASSUME_NONNULL_BEGIN

API_AVAILABLE(macos(10.14))
@interface NotifyEndpoint : NSObject <UNUserNotificationCenterDelegate>
+ (void)activate;

+ (void)setGlobalCount:(NSInteger)count previousCount:(NSInteger)count;
+ (void)postFeed:(Feed*)feed;
+ (void)postArticle:(FeedArticle*)article;

+ (void)dismiss:(nullable NSArray<NSString*>*)list;
@end

NS_ASSUME_NONNULL_END
