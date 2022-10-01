@import Cocoa;
@class BarStatusItem;

NS_ASSUME_NONNULL_BEGIN

@interface BarMenu : NSObject <NSMenuDelegate>
- (instancetype)init NS_UNAVAILABLE;
- (instancetype)initWithStatusItem:(BarStatusItem*)statusItem NS_DESIGNATED_INITIALIZER;
@end

NS_ASSUME_NONNULL_END
