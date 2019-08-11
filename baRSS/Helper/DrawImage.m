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

#import "DrawImage.h"
#import "Constants.h"

@implementation NSColor (RandomColor)
/// @return Color with random R, G, B values for testing purposes
+ (NSColor*)randomColor {
	return [NSColor colorWithRed:(arc4random()%50+20)/100.0
						   green:(arc4random()%50+20)/100.0
							blue:(arc4random()%50+20)/100.0
						   alpha:1];
}
/// @return Orange color that is typically used for RSS
+ (NSColor*)rssOrange {
	return [NSColor colorWithCalibratedRed:251/255.0 green:163/255.0 blue:58/255.0 alpha:1.0];
}
@end


@implementation DrawSeparator
- (void)drawRect:(NSRect)r {
	NSColor *color = [NSColor darkGrayColor];
	NSGradient *grdnt = [[NSGradient alloc] initWithStartingColor:color endingColor:[color colorWithAlphaComponent:0.0]];
	NSRect separatorRect = NSMakeRect(1, NSMidY(self.frame) - 1, NSWidth(self.frame) - 2, 2);
	NSBezierPath *rounded = [NSBezierPath bezierPathWithRoundedRect:separatorRect xRadius:1 yRadius:1];
	[grdnt drawInBezierPath:rounded angle:0];
}
@end


#pragma mark - Helper Methods


/// @return @c MIN(s.width,s.height)
NS_INLINE const CGFloat ShorterSide(NSSize s) {
	return (s.width < s.height ? s.width : s.height);
}

/// Perform @c CGAffineTransform with custom rotation point
// CGAffineTransform RotateAroundPoint(CGAffineTransform at, CGFloat angle, CGFloat x, CGFloat y) {
//	at = CGAffineTransformTranslate(at, x, y);
//	at = CGAffineTransformRotate(at, angle);
//	return CGAffineTransformTranslate(at, -x, -y);
//}


#pragma mark - CGPath Component Generators


/// Add circle with @c radius
NS_INLINE void PathAddCircle(CGMutablePathRef path, CGFloat radius) {
	CGPathAddArc(path, NULL, radius, radius, radius, 0, M_PI * 2, YES);
}

/// Add ring with @c radius and @c innerRadius
NS_INLINE void PathAddRing(CGMutablePathRef path, CGFloat radius, CGFloat innerRadius) {
	CGPathAddArc(path, NULL, radius, radius, radius, 0, M_PI * 2, YES);
	CGPathAddArc(path, NULL, radius, radius, innerRadius, 0, M_PI * -2, YES);
}

/// Add a single RSS icon radio wave
NS_INLINE void PathAddRSSArc(CGMutablePathRef path, CGFloat radius, CGFloat thickness) {
	CGPathMoveToPoint(path, NULL, 0, radius + thickness);
	CGPathAddArc(path, NULL, 0, 0, radius + thickness, M_PI_2, 0, YES);
	CGPathAddLineToPoint(path, NULL, radius, 0);
	CGPathAddArc(path, NULL, 0, 0, radius, 0, M_PI_2, NO);
	CGPathCloseSubpath(path);
}

/// Add two vertical bars representing a pause icon
NS_INLINE void PathAddPauseIcon(CGMutablePathRef path, CGAffineTransform at, CGFloat size, CGFloat thickness) {
	const CGFloat off = (size - 2 * thickness) / 4;
	CGPathAddRect(path, &at, CGRectMake(off, 0, thickness, size));
	CGPathAddRect(path, &at, CGRectMake(size/2 + off, 0, thickness, size));
}

/// Add X icon by applying a rotational affine transform and drawing a plus sign
// void PathAddXIcon(CGMutablePathRef path, CGAffineTransform at, CGFloat size, CGFloat thickness) {
//	at = RotateAroundPoint(at, M_PI_4, size/2, size/2);
//	const CGFloat p = size * 0.5 - thickness / 2;
//	CGPathAddRect(path, &at, CGRectMake(0, p, size, thickness));
//	CGPathAddRect(path, &at, CGRectMake(p, 0, thickness, p));
//	CGPathAddRect(path, &at, CGRectMake(p, p + thickness, thickness, p));
//}


#pragma mark - Full Icon Path Generators


/// Create @c CGPath for global icon; a menu bar and an open menu below
NS_INLINE void AddGlobalIconPath(CGContextRef c, CGFloat size) {
	CGMutablePathRef menu = CGPathCreateMutable();
	CGPathAddRect(menu, NULL, CGRectMake(0, 0.8 * size, size, 0.2 * size));
	CGPathAddRect(menu, NULL, CGRectMake(0.3 * size, 0, 0.55 * size, 0.75 * size));
	CGPathAddRect(menu, NULL, CGRectMake(0.35 * size, 0.05 * size, 0.45 * size, 0.75 * size));
	
	CGFloat entryHeight = 0.1 * size; // 0.075
	for (int i = 0; i < 3; i++) { // 4
		//CGPathAddRect(menu, NULL, CGRectMake(0.37 * size, (2 * i + 1) * entryHeight, 0.42 * size, entryHeight)); // uncomment path above
		CGPathAddRect(menu, NULL, CGRectMake(0.35 * size, (2 * i + 1.5) * entryHeight, 0.4 * size, entryHeight * 0.8));
	}
	CGContextAddPath(c, menu);
	CGPathRelease(menu);
}

/// Create @c CGPath for group icon; a folder symbol
NS_INLINE void AddGroupIconPath(CGContextRef c, CGFloat size, BOOL showBackground) {
	const CGFloat r1 = size * 0.05; // corners
	const CGFloat r2 = size * 0.08; // upper part, name tag
	const CGFloat r3 = size * 0.15; // lower part, corners inside
	const CGFloat posTop = 0.85 * size;
	const CGFloat posMiddle = 0.6 * size - r3;
	const CGFloat posBottom = 0.15 * size + r1;
	const CGFloat posNameTag = 0.3 * size;
	
	CGMutablePathRef upper = CGPathCreateMutable();
	CGPathMoveToPoint(upper, NULL, 0, 0.5 * size);
	CGPathAddLineToPoint(upper, NULL, 0, posTop - r1);
	CGPathAddArc(upper, NULL, r1, posTop - r1, r1, M_PI, M_PI_2, YES);
	CGPathAddArc(upper, NULL, posNameTag, posTop - r2, r2, M_PI_2, M_PI_4, YES);
	CGPathAddArc(upper, NULL, posNameTag + 1.85 * r2, posTop, r2, M_PI + M_PI_4, -M_PI_2, NO);
	CGPathAddArc(upper, NULL, size - r1, posTop - r1 - r2, r1, M_PI_2, 0, YES);
	CGPathAddArc(upper, NULL, size - r1, posBottom, r1, 0, -M_PI_2, YES);
	CGPathAddArc(upper, NULL, r1, posBottom, r1, -M_PI_2, M_PI, YES);
	CGPathCloseSubpath(upper);
	
	CGMutablePathRef lower = CGPathCreateMutable();
	CGPathAddArc(lower, NULL, r3, posMiddle, r3, M_PI, M_PI_2, YES);
	CGPathAddArc(lower, NULL, size - r3, posMiddle, r3, M_PI_2, 0, YES);
	CGPathAddArc(lower, NULL, size - r1, posBottom, r1, 0, -M_PI_2, YES);
	CGPathAddArc(lower, NULL, r1, posBottom, r1, -M_PI_2, M_PI, YES);
	CGPathCloseSubpath(lower);
	
	CGContextAddPath(c, upper);
	if (showBackground)
		CGContextEOFillPath(c);
	CGContextAddPath(c, lower);
	CGPathRelease(upper);
	CGPathRelease(lower);
}


/**
NS_INLINE Create @c CGPath for RSS icon; a circle in the lower left bottom and two radio waves going outwards.
NS_INLINE @param connection If @c NO, draw only one radio wave and a pause icon in the upper right
NS_INLINE */
NS_INLINE void AddRSSIconPath(CGContextRef c, CGFloat size, BOOL connection) {
	CGMutablePathRef bars = CGPathCreateMutable(); // the rss bars
	PathAddCircle(bars, size * 0.125);
	PathAddRSSArc(bars, size * 0.45, size * 0.2);
	if (connection) {
		PathAddRSSArc(bars, size * 0.8, size * 0.2);
	} else {
		CGAffineTransform at = CGAffineTransformMake(0.5, 0, 0, 0.5, size/2, size/2);
		PathAddPauseIcon(bars, at, size, size * 0.3);
		//PathAddXIcon(bars, at, size, size * 0.3);
	}
	CGContextAddPath(c, bars);
	CGPathRelease(bars);
}


#pragma mark - Icon Background Generators


/// Create @c CGPath with rounded corners (optional). @param roundness Value between @c 0.0 and @c 1.0
NS_INLINE void AddRoundedBackgroundPath(CGContextRef c, CGRect r, CGFloat roundness) {
	const CGFloat corner = ShorterSide(r.size) * (roundness / 2.0);
	if (corner > 0) {
		CGMutablePathRef pth = CGPathCreateMutable();
		CGPathAddRoundedRect(pth, NULL, r, corner, corner);
		CGContextAddPath(c, pth);
		CGPathRelease(pth);
	} else {
		CGContextAddRect(c, r);
	}
}

/// Insert and draw linear gradient with @c color saturation @c ±0.3
NS_INLINE void DrawGradient(CGContextRef c, CGFloat size, NSColor *color) {
	CGFloat h = 0, s = 1, b = 1, a = 1;
	@try {
		NSColor *rgbColor = [color colorUsingColorSpace:[NSColorSpace deviceRGBColorSpace]];
		[rgbColor getHue:&h saturation:&s brightness:&b alpha:&a];
	} @catch (NSException *e) {}
	
	static CGFloat const impact = 0.3;
	NSColor *darker = [NSColor colorWithHue:h saturation:(s + impact > 1 ? 1 : s + impact) brightness:b alpha:a];
	NSColor *lighter = [NSColor colorWithHue:h saturation:(s - impact < 0 ? 0 : s - impact) brightness:b alpha:a];
	const void* cgColors[] = {
		[darker CGColor],
		[lighter CGColor],
		[darker CGColor]
	};
	CFArrayRef colors = CFArrayCreate(NULL, cgColors, 3, NULL);
	CGGradientRef gradient = CGGradientCreateWithColors(NULL, colors, NULL);
	
	CGContextDrawLinearGradient(c, gradient, CGPointMake(0, size), CGPointMake(size, 0), kCGGradientDrawsBeforeStartLocation | kCGGradientDrawsAfterEndLocation);
	CGGradientRelease(gradient);
	CFRelease(colors);
}


#pragma mark - CGContext Drawing & Manipulation


/// Scale and translate context to the center with respect to the new scale. If @c width @c != @c length align top left.
NS_INLINE void SetContentScale(CGContextRef c, CGSize size, CGFloat scale) {
	const CGFloat s = ShorterSide(size);
	CGFloat offset = s * (1 - scale) / 2;
	CGContextTranslateCTM(c, offset, size.height - s + offset); // top left alignment
	CGContextScaleCTM(c, scale, scale);
}

/// Helper method; set drawing color, add rounded background and prepare content scale
NS_INLINE void DrawRoundedFrame(CGContextRef c, CGRect r, CGColorRef color, BOOL background, CGFloat corner, CGFloat defaultScale, CGFloat scaling) {
	CGContextSetFillColorWithColor(c, color);
	CGContextSetStrokeColorWithColor(c, color);
	CGFloat contentScale = defaultScale;
	if (background) {
		AddRoundedBackgroundPath(c, r, corner);
		if (scaling != 0.0)
			contentScale *= scaling;
	}
	SetContentScale(c, r.size, contentScale);
}


#pragma mark - Easy Icon Drawing Methods


/// Draw global icon (menu bar)
NS_INLINE void DrawGlobalIcon(CGRect r, CGColorRef color, BOOL background) {
	CGContextRef c = NSGraphicsContext.currentContext.CGContext;
	DrawRoundedFrame(c, r, color, background, 0.4, 1.0, 0.7);
	AddGlobalIconPath(c, ShorterSide(r.size));
	CGContextEOFillPath(c);
}

/// Draw group icon (folder)
NS_INLINE void DrawGroupIcon(CGRect r, CGColorRef color, BOOL background) {
	CGContextRef c = NSGraphicsContext.currentContext.CGContext;
	const CGFloat s = ShorterSide(r.size);
	const CGFloat l = s * 0.08; // line width
	DrawRoundedFrame(c, r, color, background, 0.4, 1.0 - (l / s), 0.85);
	CGContextSetLineWidth(c, l * (background ? 0.5 : 1.0));
	AddGroupIconPath(c, s, background);
	CGContextStrokePath(c);
}

/// Draw RSS icon (flat without gradient)
NS_INLINE void DrawRSSIcon(CGRect r, CGColorRef color, BOOL background, BOOL connection) {
	CGContextRef c = NSGraphicsContext.currentContext.CGContext;
	DrawRoundedFrame(c, r, color, background, 0.4, 1.0, 0.7);
	AddRSSIconPath(c, ShorterSide(r.size), connection);
	CGContextEOFillPath(c);
}

/// Draw RSS icon (with orange gradient, corner @c 0.4, white radio waves)
NS_INLINE void DrawRSSGradientIcon(CGRect r) {
	const CGFloat size = ShorterSide(r.size);
	CGContextRef c = NSGraphicsContext.currentContext.CGContext;
	DrawRoundedFrame(c, r, NSColor.whiteColor.CGColor, YES, 0.4, 1.0, 0.7);
	// Gradient
	CGContextSaveGState(c);
	CGContextClip(c);
	DrawGradient(c, size, [NSColor rssOrange]);
	CGContextRestoreGState(c);
	// Bars
	AddRSSIconPath(c, size, YES);
	CGContextEOFillPath(c);
}

/// Draw unread icon (blue dot for unread menu item)
NS_INLINE void DrawUnreadIcon(CGRect r, NSColor *color) {
	CGFloat size = ShorterSide(r.size) / 2.0;
	CGContextRef c = NSGraphicsContext.currentContext.CGContext;
	CGMutablePathRef path = CGPathCreateMutable();
	SetContentScale(c, r.size, 0.8);
	
	CGContextSetFillColorWithColor(c, color.CGColor);
	PathAddRing(path, size, size * 0.7);
	CGContextAddPath(c, path);
	CGContextEOFillPath(c);
	
	CGContextSetFillColorWithColor(c, [color colorWithAlphaComponent:0.5].CGColor);
	PathAddCircle(path, size);
	CGContextAddPath(c, path);
	CGContextFillPath(c);
	CGPathRelease(path);
}


#pragma mark - NSImage Name Registration


/// Add single image to @c ImageNamed cache and set accessibility description
NS_INLINE void Register(CGFloat size, NSImageName name, NSString *description, BOOL (^draw)(NSRect r)) {
	NSImage *img = [NSImage imageWithSize: NSMakeSize(size, size) flipped:NO drawingHandler:draw];
	img.accessibilityDescription = description;
	img.name = name;
}

/// Register all icons that require custom drawing in @c ImageNamed cache
void RegisterImageViewNames(void) {
	const CGColorRef black = [NSColor controlTextColor].CGColor;
	Register(16, RSSImageDefaultRSSIcon, NSLocalizedString(@"RSS icon", nil), ^(NSRect r) { DrawRSSGradientIcon(r); return YES; });
	Register(16, RSSImageSettingsGlobal, NSLocalizedString(@"Global settings", nil), ^(NSRect r) { DrawGlobalIcon(r, black, NO); return YES; });
	Register(16, RSSImageSettingsGroup, NSLocalizedString(@"Group settings", nil), ^(NSRect r) { DrawGroupIcon(r, black, NO); return YES; });
	Register(16, RSSImageSettingsFeed, NSLocalizedString(@"Feed settings", nil), ^(NSRect r) { DrawRSSIcon(r, black, NO, YES); return YES; });
	Register(16, RSSImageMenuBarIconActive, NSLocalizedString(@"RSS menu bar icon", nil), ^(NSRect r) { DrawRSSIcon(r, [NSColor rssOrange].CGColor, YES, YES); return YES; });
	Register(16, RSSImageMenuBarIconPaused, NSLocalizedString(@"RSS menu bar icon, paused", nil), ^(NSRect r) { DrawRSSIcon(r, [NSColor rssOrange].CGColor, YES, NO); return YES; });
	Register(12, RSSImageMenuItemUnread, NSLocalizedString(@"Unread icon", nil), ^(NSRect r) { DrawUnreadIcon(r, [NSColor systemBlueColor]); return YES; });
}
