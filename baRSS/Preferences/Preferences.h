@import Cocoa;
@class SettingsFeeds;

NS_ASSUME_NONNULL_BEGIN

@interface Preferences : NSWindow <NSWindowDelegate>
+ (instancetype)window;
- (__kindof NSViewController*)selectTab:(NSUInteger)index;
@end

NS_ASSUME_NONNULL_END
