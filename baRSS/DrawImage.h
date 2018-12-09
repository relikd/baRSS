//
//  The MIT License (MIT)
//  Copyright (c) 2018 Oleg Geier
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

@interface NSColor (RandomColor)
/// just for testing purposes
+ (NSColor*)randomColor;
/// RGB color with (251, 163, 58)
+ (NSColor*)rssOrange;
@end

//  ---------------------------------------------------------------
// |
// |  DrawImage
// |
//  ---------------------------------------------------------------

IB_DESIGNABLE
@interface DrawImage : NSView
@property (strong) IBInspectable NSColor *color;
@property (assign) IBInspectable BOOL showBackground;
/** percentage value between 0 - 100 */
@property (assign, nonatomic) IBInspectable CGFloat roundness;
@property (assign, nonatomic) IBInspectable CGFloat contentScale;
@property (strong, readonly) NSImageView *imageView;

- (NSImage*)drawnImage;
@end

//  ---------------------------------------------------------------
// |
// |  RSSIcon
// |
//  ---------------------------------------------------------------

IB_DESIGNABLE
@interface RSSIcon : DrawImage
@property (strong) IBInspectable NSColor *barsColor;
@property (strong) IBInspectable NSColor *gradientColor;
@property (assign) IBInspectable BOOL noConnection;

+ (NSImage*)iconWithSize:(CGFloat)size;
+ (NSImage*)systemBarIcon:(CGFloat)size tint:(NSColor*)color noConnection:(BOOL)conn;
@end

//  ---------------------------------------------------------------
// |
// |  SettingsIconGlobal
// |
//  ---------------------------------------------------------------

IB_DESIGNABLE
@interface SettingsIconGlobal : DrawImage
@end

//  ---------------------------------------------------------------
// |
// |  SettingsIconGroup
// |
//  ---------------------------------------------------------------

IB_DESIGNABLE
@interface SettingsIconGroup : DrawImage
@end

//  ---------------------------------------------------------------
// |
// |  DrawSeparator
// |
//  ---------------------------------------------------------------

IB_DESIGNABLE
@interface DrawSeparator : NSView
@end

