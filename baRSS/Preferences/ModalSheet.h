@import Cocoa;

NS_ASSUME_NONNULL_BEGIN

@interface ModalSheet : NSPanel
@property (readonly) BOOL didTapCancel;

- (instancetype)initWithContentRect:(NSRect)contentRect styleMask:(NSWindowStyleMask)style backing:(NSBackingStoreType)backingStoreType defer:(BOOL)flag NS_UNAVAILABLE;
- (instancetype)initWithView:(NSView*)content NS_DESIGNATED_INITIALIZER;

- (void)setDoneEnabled:(BOOL)accept;
- (void)extendContentViewBy:(CGFloat)dy;
@end

NS_ASSUME_NONNULL_END
