@import Cocoa;

NS_ASSUME_NONNULL_BEGIN

@interface BarStatusItem : NSObject
@property (weak, readonly) NSMenu *mainMenu;

- (void)setUnreadCountAbsolute:(NSUInteger)count;
- (void)setUnreadCountRelative:(NSInteger)count;
- (void)asyncReloadUnreadCount;
- (void)updateBarIcon;
- (void)showWelcomeMessage;
@end

NS_ASSUME_NONNULL_END
