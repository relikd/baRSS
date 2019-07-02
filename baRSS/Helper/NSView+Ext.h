//
//  The MIT License (MIT)
//  Copyright (c) 2019 Oleg Geier
//
//  Permission is hereby granted, free of charge, to any person obtaining a copy of
//  this software and associated documentation files (the "Software"), to deal in
//  the Software without restriction, including without limitation the rights to
//  use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies
//  of the Software, and to permit persons to whom the Software is furnished to do
//  so, subject to the following conditions:
//
//  The above copyright notice and this permission notice shall be included in all
//  copies or substantial portions of the Software.
//
//  THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
//  IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
//  FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
//  AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
//  LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
//  OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
//  SOFTWARE.

#import <Cocoa/Cocoa.h>

/***/ static const CGFloat PAD_WIN = 20; // window padding
/***/ static const CGFloat PAD_L = 16;
/***/ static const CGFloat PAD_M = 8;
/***/ static const CGFloat PAD_S = 4;
/***/ static const CGFloat PAD_XS = 2;

/***/ static const CGFloat HEIGHT_LABEL = 17;
/***/ static const CGFloat HEIGHT_LABEL_SMALL = 14;
/***/ static const CGFloat HEIGHT_INPUTFIELD = 21;
/***/ static const CGFloat HEIGHT_BUTTON = 21;
/***/ static const CGFloat HEIGHT_INLINEBUTTON = 16;
/***/ static const CGFloat HEIGHT_POPUP = 21;
/***/ static const CGFloat HEIGHT_SPINNER = 16;
/***/ static const CGFloat HEIGHT_CHECKBOX = 14;

/// Static variable to calculate origin center coordinate in its @c superview. The value of this var isn't used.
static const CGFloat CENTER = -0.015625;

/// Calculate @c origin.y going down from the top border of its @c superview
NS_INLINE CGFloat YFromTop(NSView *view) { return NSHeight(view.superview.frame) - NSMinY(view.frame) - view.alignmentRectInsets.bottom; }


/*
 Allmost all methods return @c self to allow method chaining
 */

@interface NSView (Ext)
// UI: TextFields
+ (NSTextField*)label:(NSString*)text;
+ (NSTextField*)inputField:(NSString*)placeholder width:(CGFloat)w;
+ (NSView*)labelColumn:(NSArray<NSString*>*)labels rowHeight:(CGFloat)h padding:(CGFloat)pad;
// UI: Buttons
+ (NSButton*)button:(NSString*)text;
+ (NSButton*)buttonImageSquare:(nonnull NSImageName)name;
+ (NSButton*)buttonIcon:(NSImage*)img size:(CGFloat)size;
+ (NSButton*)inlineButton:(NSString*)text;
+ (NSPopUpButton*)popupButton:(CGFloat)w;
// UI: Others
+ (NSImageView*)imageView:(NSImageName)name size:(CGFloat)size;
+ (NSButton*)checkbox:(BOOL)flag;
+ (NSProgressIndicator*)activitySpinner;
+ (NSView*)radioGroup:(NSArray<NSString*>*)entries target:(id)target action:(nonnull SEL)action;
+ (NSView*)radioGroup:(NSArray<NSString*>*)entries;
// UI: Enclosing Container
- (NSScrollView*)wrapContent:(NSView*)content inScrollView:(NSRect)rect;
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
- (instancetype)action:(SEL)selector target:(id)target;
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
@end
