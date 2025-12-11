@import Cocoa;

/***/ static CGFloat const PAD_WIN = 20; // window padding
/***/ static CGFloat const PAD_L = 16;
/***/ static CGFloat const PAD_M = 8;
/***/ static CGFloat const PAD_S = 4;
/***/ static CGFloat const PAD_XS = 2;

/***/ static CGFloat const HEIGHT_LABEL = 17;
/***/ static CGFloat const HEIGHT_LABEL_SMALL = 14;
/***/ static CGFloat const HEIGHT_INPUTFIELD = 21;
/***/ static CGFloat const HEIGHT_BUTTON = 21;
/***/ static CGFloat const HEIGHT_INLINEBUTTON = 16;
/***/ static CGFloat const HEIGHT_POPUP = 21;
/***/ static CGFloat const HEIGHT_SPINNER = 16;
/***/ static CGFloat const HEIGHT_CHECKBOX = 14;

/// Static variable to calculate origin center coordinate in its @c superview. The value of this var isn't used.
static CGFloat const CENTER = -0.015625;

NS_ASSUME_NONNULL_BEGIN

/// Calculate @c origin.y going down from the top border of its @c superview
static inline CGFloat YFromTop(NSView *view) { return NSHeight(view.superview.frame) - NSMinY(view.frame) - view.alignmentRectInsets.bottom; }
/// @c MAX()
static inline CGFloat Max(CGFloat a, CGFloat b) { return a < b ? b : a; }
/// @c Max(NSWidth(a.frame),NSWidth(b.frame))
static inline CGFloat NSMaxWidth(NSView *a, NSView *b) { return Max(NSWidth(a.frame), NSWidth(b.frame)); }


/*
 Allmost all methods return @c self to allow method chaining
 */

@interface NSView (Ext)
// UI: TextFields
+ (NSTextField*)label:(NSString*)text;
+ (NSTextField*)inputField:(NSString*)placeholder width:(CGFloat)w;
+ (NSTextField*)integerField:(NSString*)placeholder unit:(nullable NSString*)unit width:(CGFloat)w;
+ (NSView*)labelColumn:(NSArray<NSString*>*)labels rowHeight:(CGFloat)h padding:(CGFloat)pad;
// UI: Buttons
+ (NSButton*)button:(NSString*)text;
+ (NSButton*)buttonImageSquare:(nonnull NSImageName)name;
+ (NSButton*)buttonIcon:(nonnull NSImageName)name size:(CGFloat)size;
+ (NSButton*)helpButton;
+ (NSButton*)inlineButton:(NSString*)text;
+ (NSPopUpButton*)popupButton:(CGFloat)w;
// UI: Others
+ (NSImageView*)imageView:(nullable NSImageName)name size:(CGFloat)size;
+ (NSButton*)checkbox:(BOOL)flag;
+ (NSProgressIndicator*)activitySpinner;
+ (nullable NSView*)radioGroup:(NSArray<NSString*>*)entries target:(id)target action:(nonnull SEL)action;
+ (nullable NSView*)radioGroup:(NSArray<NSString*>*)entries;
// UI: Enclosing Container
+ (NSPopover*)popover:(NSSize)size;
- (NSScrollView*)wrapInScrollView:(NSSize)size;
+ (NSView*)wrapView:(NSView*)other withLabel:(NSString*)str padding:(CGFloat)pad;
// Insert UI elements in parent view
- (instancetype)placeIn:(NSView*)parent x:(CGFloat)x y:(CGFloat)y;
- (instancetype)placeIn:(NSView*)parent x:(CGFloat)x yTop:(CGFloat)y;
- (instancetype)placeIn:(NSView*)parent xRight:(CGFloat)x y:(CGFloat)y;
- (instancetype)placeIn:(NSView*)parent xRight:(CGFloat)x yTop:(CGFloat)y;
// Modify existing UI elements
- (instancetype)sizableWidthAndHeight;
- (instancetype)sizeToRight:(CGFloat)rightPadding;
- (instancetype)sizeWidthToFit;
- (instancetype)tooltip:(NSString*)tt;
// Debugging
- (instancetype)colorLayer:(NSColor*)color;
+ (NSView*)redCube:(CGFloat)size;
@end


@interface NSControl (Ext)
- (instancetype)action:(SEL)selector target:(nullable id)target;
- (instancetype)large;
- (instancetype)small;
- (instancetype)tiny;
- (instancetype)bold;
- (instancetype)textRight;
- (instancetype)textCenter;
@end


@interface NSTextField (Ext)
- (instancetype)gray;
- (instancetype)selectable;
- (instancetype)multiline:(NSSize)size;
@end

NS_ASSUME_NONNULL_END
