@import Cocoa;
@class BarStatusItem;

NS_ASSUME_NONNULL_BEGIN

@interface BarMenu : NSObject <NSMenuDelegate>
@property (assign) BOOL showHidden;
- (instancetype)init NS_UNAVAILABLE;
- (instancetype)initWithStatusItem:(BarStatusItem*)statusItem NS_DESIGNATED_INITIALIZER;
@end

NS_ASSUME_NONNULL_END
