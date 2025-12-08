#import "DrawImage.h"
#import "Constants.h"
#import "NSColor+Ext.h"
#import "TinySVG.h"


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
static inline const CGFloat ShorterSide(NSSize s) {
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
static inline void PathAddCircle(CGMutablePathRef path, CGFloat radius) {
	CGPathAddArc(path, NULL, radius, radius, radius, 0, M_PI * 2, YES);
}

/// Add ring with @c radius and @c innerRadius
static inline void PathAddRing(CGMutablePathRef path, CGFloat radius, CGFloat innerRadius) {
	CGPathAddArc(path, NULL, radius, radius, radius, 0, M_PI * 2, YES);
	CGPathAddArc(path, NULL, radius, radius, innerRadius, 0, M_PI * -2, YES);
}

/// Add a single RSS icon radio wave
static inline void PathAddRSSArc(CGMutablePathRef path, CGFloat radius, CGFloat thickness) {
	CGPathMoveToPoint(path, NULL, 0, radius + thickness);
	CGPathAddArc(path, NULL, 0, 0, radius + thickness, M_PI_2, 0, YES);
	CGPathAddLineToPoint(path, NULL, radius, 0);
	CGPathAddArc(path, NULL, 0, 0, radius, 0, M_PI_2, NO);
	CGPathCloseSubpath(path);
}

/// Add two vertical bars representing a pause icon
static inline void PathAddPauseIcon(CGMutablePathRef path, CGAffineTransform at, CGFloat size, CGFloat thickness) {
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
static inline void AddGlobalIconPath(CGContextRef c, CGFloat size) {
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

/**
 Create @c CGPath for RSS icon; a circle in the lower left bottom and two radio waves going outwards.
 @param connection If @c NO, draw only one radio wave and a pause icon in the upper right
 */
static inline void AddRSSIconPath(CGContextRef c, CGFloat size, BOOL connection) {
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


#pragma mark - Icon Background


/// Insert and draw linear gradient with @c color saturation @c ±0.3
static void DrawGradient(CGContextRef c, CGFloat size, NSColor *color) {
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


/// Flip coordinate system
static void FlipCoordinateSystem(CGContextRef c, CGFloat height) {
	CGContextTranslateCTM(c, 0, height);
	CGContextScaleCTM(c, 1, -1);
}

/// Scale and translate context to the center with respect to the new scale. If @c width @c != @c length align top left.
static void SetContentScale(CGContextRef c, CGSize size, CGFloat scale) {
	const CGFloat s = ShorterSide(size);
	CGFloat offset = s * (1 - scale) / 2;
	CGContextTranslateCTM(c, offset, size.height - s + offset); // top left alignment
	CGContextScaleCTM(c, scale, scale);
}

/// Helper method; set drawing color, add rounded background and prepare content scale
static void DrawRoundedFrame(CGContextRef c, CGRect r, CGColorRef color, BOOL background, CGFloat corner, CGFloat defaultScale, CGFloat scaling) {
	CGContextSetFillColorWithColor(c, color);
	CGContextSetStrokeColorWithColor(c, color);
	CGFloat contentScale = defaultScale;
	if (background) {
		svgAddRect(c, 1, r, ShorterSide(r.size) * corner/2);
		if (scaling != 0.0)
			contentScale *= scaling;
	}
	SetContentScale(c, r.size, contentScale);
}


#pragma mark - Easy Icon Drawing Methods


/// Draw RSS icon in menu bar with neighbors
static void DrawMenubarIcon(CGRect r) {
	const CGFloat size = ShorterSide(r.size);
	CGContextRef c = NSGraphicsContext.currentContext.CGContext;
	CGContextSetFillColorWithColor(c, [NSColor controlTextColor].CGColor);
	
	// menu bar
	CGContextSetAlpha(c, .23);
	const CGFloat barHeightInset = round(size*.06);
	svgAddRect(c, 1, CGRectInset(r, 0, barHeightInset), 0);
	CGContextFillPath(c);
	
	const CGFloat offset = round(size*.75);
	const CGFloat iconInset = round(size*.2);
	const CGFloat iconCorner = size*.12;
	CGContextSetAlpha(c, .66);
	
	// left neighbor
	CGContextTranslateCTM(c, -offset, 0);
	svgAddRect(c, 1, CGRectInset(r, iconInset, iconInset), iconCorner);
	CGContextFillPath(c);
	
	// right neighbor
	CGContextTranslateCTM(c, +2*offset, 0);
	svgAddRect(c, 1, CGRectInset(r, iconInset, iconInset), iconCorner);
	CGContextFillPath(c);
	
	// main icon
	CGContextSetAlpha(c, 1);
	CGContextTranslateCTM(c, -offset, 0);
	svgAddRect(c, 1, CGRectInset(r, iconInset, iconInset), iconCorner);
	SetContentScale(c, r.size, .47);
	AddRSSIconPath(c, size, YES);
	CGContextEOFillPath(c);
}

/// Draw global icon (menu bar)
static void DrawGlobalIcon(CGRect r, CGColorRef color, BOOL background) {
	CGContextRef c = NSGraphicsContext.currentContext.CGContext;
	DrawRoundedFrame(c, r, color, background, 0.4, 1.0, 0.7);
	AddGlobalIconPath(c, ShorterSide(r.size));
	CGContextEOFillPath(c);
}

/// Draw group icon (folder)
static void DrawGroupIcon(CGRect r) {
	const CGFloat size = ShorterSide(r.size);
	CGContextRef c = NSGraphicsContext.currentContext.CGContext;
	FlipCoordinateSystem(c, r.size.height);
	SetContentScale(c, r.size, 0.92);
	// folder path
	svgAddPath(c, size/100, "M15,87c-12,0-15-3-15-15V21c0-10,3-13,13-13h11c10,0,8,8,18,8h43c12,0,15,3,15,15v41c0,12-3,15-15,15H15Z");
	// line
	svgAddPath(c, size/100, "M7,32h86Z");
	CGContextSetLineWidth(c, size * 0.08);
	CGContextSetStrokeColorWithColor(c, [NSColor controlTextColor].CGColor);
	CGContextStrokePath(c);
}

/// Draw RSS icon (flat without gradient)
static void DrawRSSIcon(CGRect r, CGColorRef color, BOOL background, BOOL connection) {
	CGContextRef c = NSGraphicsContext.currentContext.CGContext;
	DrawRoundedFrame(c, r, color, background, 0.4, 1.0, 0.7);
	AddRSSIconPath(c, ShorterSide(r.size), connection);
	CGContextEOFillPath(c);
}

/// Draw RSS icon (with orange gradient, corner @c 0.4, white radio waves)
static void DrawRSSGradientIcon(CGRect r, NSColor *color) {
	const CGFloat size = ShorterSide(r.size);
	CGContextRef c = NSGraphicsContext.currentContext.CGContext;
	DrawRoundedFrame(c, r, NSColor.whiteColor.CGColor, YES, 0.4, 1.0, 0.7);
	// Gradient
	CGContextSaveGState(c);
	CGContextClip(c);
	DrawGradient(c, size, color);
	CGContextRestoreGState(c);
	// Bars
	AddRSSIconPath(c, size, YES);
	CGContextEOFillPath(c);
}

/// Draw unread icon (blue dot for unread menu item)
static void DrawUnreadIcon(CGRect r, NSColor *color) {
	CGFloat size = ShorterSide(r.size) / 2.0;
	CGContextRef c = NSGraphicsContext.currentContext.CGContext;
	CGMutablePathRef path = CGPathCreateMutable();
	SetContentScale(c, r.size, 0.7);
	CGContextTranslateCTM(c, 0, size * -0.15); // align with baseline of menu item text
	
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

/// Draw "(.*)" as vector path
static void DrawRegexIcon(CGRect r) {
	const CGFloat size = ShorterSide(r.size);
	CGContextRef c = NSGraphicsContext.currentContext.CGContext;
	
	svgAddRect(c, 1, r, .2 * size);
	CGContextSetFillColorWithColor(c, NSColor.redColor.CGColor);
	CGContextFillPath(c);
	
	// SVG files use bottom-left corner coordinate system. Quartz uses top-left.
	FlipCoordinateSystem(c, r.size.height);
	SetContentScale(c, r.size, 0.8);
	// "("
	svgAddPath(c, size/1000, "m184 187c-140 205-134 432-1 622l-66 44c-159-221-151-499 0-708z");
	// "."
	svgAddCircle(c, size/1000, 315, 675, 70, NO);
	// "*"
	svgAddPath(c, size/1000, "m652 277 107-35 21 63-109 36 68 92-54 39-68-93-66 91-52-41 67-88-109-37 21-63 108 37v-113h66v112z");
	// ")"
	svgAddPath(c, size/1000, "m816 813c140-205 134-430 1-621l66-45c159 221 151 499 0 708z");
	
	CGContextSetFillColorWithColor(c, NSColor.whiteColor.CGColor);
	CGContextFillPath(c);
}


#pragma mark - NSImage Name Registration


/// Add single image to @c ImageNamed cache and set accessibility description
static void Register(CGFloat size, NSImageName name, NSString *description, BOOL (^draw)(NSRect r)) {
	NSImage *img = [NSImage imageWithSize: NSMakeSize(size, size) flipped:NO drawingHandler:draw];
	img.accessibilityDescription = description;
	img.name = name;
}

/// Register all icons that require custom drawing in @c ImageNamed cache
void RegisterImageViewNames(void) {
	Register(16, RSSImageDefaultRSSIcon, NSLocalizedString(@"RSS icon", nil), ^(NSRect r) { DrawRSSGradientIcon(r, [NSColor rssOrange]); return YES; });
	Register(16, RSSImageSettingsGlobalIcon, NSLocalizedString(@"Global menu icon settings", nil), ^(NSRect r) { DrawMenubarIcon(r); return YES; });
	Register(16, RSSImageSettingsGlobalMenu, NSLocalizedString(@"Global settings", nil), ^(NSRect r) { DrawGlobalIcon(r, [NSColor controlTextColor].CGColor, NO); return YES; });
	Register(16, RSSImageSettingsGroup, NSLocalizedString(@"Group settings", nil), ^(NSRect r) { DrawGroupIcon(r); return YES; });
	Register(16, RSSImageSettingsFeed, NSLocalizedString(@"Feed settings", nil), ^(NSRect r) { DrawRSSIcon(r, [NSColor controlTextColor].CGColor, NO, YES); return YES; });
	Register(16, RSSImageMenuBarIconActive, NSLocalizedString(@"RSS menu bar icon", nil), ^(NSRect r) { DrawRSSIcon(r, [NSColor menuBarIconColor].CGColor, YES, YES); return YES; });
	Register(16, RSSImageMenuBarIconPaused, NSLocalizedString(@"RSS menu bar icon, paused", nil), ^(NSRect r) { DrawRSSIcon(r, [NSColor menuBarIconColor].CGColor, YES, NO); return YES; });
	Register(14, RSSImageMenuItemUnread, NSLocalizedString(@"Unread icon", nil), ^(NSRect r) { DrawUnreadIcon(r, [NSColor unreadIndicatorColor]); return YES; });
	Register(32, RSSImageRegexIcon, NSLocalizedString(@"Regex icon", nil), ^(NSRect r) { DrawRegexIcon(r); return YES; });
}
