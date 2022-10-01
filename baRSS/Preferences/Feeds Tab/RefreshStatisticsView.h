@import Cocoa;

NS_ASSUME_NONNULL_BEGIN

@protocol RefreshIntervalButtonDelegate <NSObject>
@required
/// @c sender.tag is refresh interval in seconds
- (void)refreshIntervalButtonClicked:(NSButton*)sender;
@end


@interface RefreshStatisticsView : NSView
- (instancetype)initWithRefreshInterval:(NSDictionary*)info articleCount:(NSUInteger)count callback:(nullable id<RefreshIntervalButtonDelegate>)callback NS_DESIGNATED_INITIALIZER;
- (instancetype)initWithFrame:(NSRect)frameRect NS_UNAVAILABLE;
- (nullable instancetype)initWithCoder:(NSCoder *)decoder NS_UNAVAILABLE;
@end

NS_ASSUME_NONNULL_END
