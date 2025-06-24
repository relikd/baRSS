@import Cocoa;

NS_ASSUME_NONNULL_BEGIN

@interface RegexConverterModal : NSPanel
@property (readonly) BOOL didTapCancel;

- (instancetype)initWithContentRect:(NSRect)contentRect styleMask:(NSWindowStyleMask)style backing:(NSBackingStoreType)backingStoreType defer:(BOOL)flag NS_UNAVAILABLE;
- (instancetype)initWithView:(NSView*)content NS_DESIGNATED_INITIALIZER;
@end

NS_ASSUME_NONNULL_END
