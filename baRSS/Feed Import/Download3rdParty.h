@import Cocoa;

#define ENV_LOG_YOUTUBE 1

NS_ASSUME_NONNULL_BEGIN

// TODO: Make plugins extensible? community extensions.
@interface YouTubePlugin : NSObject
+ (nullable NSString*)feedURL:(NSURL*)url data:(NSData*)html;
+ (NSString*)videoImage:(NSString*)videoid;
+ (NSString*)videoImageHQ:(NSString*)videoid;
@end

NS_ASSUME_NONNULL_END
