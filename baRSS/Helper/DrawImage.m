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


#pragma mark - RSS Icon (rounded corners)


/**
 Create @c CGPath for RSS icon; a circle in the lower left bottom and two radio waves going outwards.
 @param connection If @c NO, draw only one radio wave and a pause icon in the upper right
 */
static inline void AddRSSIconPath(CGContextRef c, CGFloat size, BOOL connection) {
	FlipCoordinateSystem(c, size);
	svgCircle(c, size/100, 13, 87, 13, NO);
	svgPath(c, size/100, "M0,55v-20c43,0,65,22,65,65h-20c0-30-15-45-45-45Z");
	if (connection) {
		svgPath(c, size/100, "M0,20V0c67,0,100,33,100,100h-20C80,47,53,20,0,20Z");
	} else {
		// pause icon
		svgRect(c, size/100, CGRectMake(60, 0, 15, 50));
		svgRect(c, size/100, CGRectMake(85, 0, 15, 50));
	}
}

/// Draw monochrome RSS icon with rounded corners
static void RoundedRSS_Monochrome(CGRect r, BOOL connection) {
	CGContextRef c = NSGraphicsContext.currentContext.CGContext;
	CGContextSetFillColorWithColor(c, [NSColor menuBarIconColor].CGColor);
	// background rounded rect
	svgRoundedRect(c, 1, r, ShorterSide(r.size) * 0.4/2);
	// RSS icon
	SetContentScale(c, r.size, 0.7);
	AddRSSIconPath(c, ShorterSide(r.size), connection);
	CGContextEOFillPath(c);
}

/// Draw RSS icon with orange gradient background
static void RoundedRSS_Gradient(CGRect r, NSColor *color) {
	const CGFloat size = ShorterSide(r.size);
	CGContextRef c = NSGraphicsContext.currentContext.CGContext;
	CGContextSetFillColorWithColor(c, NSColor.whiteColor.CGColor);
	// background rounded rect
	svgRoundedRect(c, 1, r, ShorterSide(r.size) * 0.4/2);
	// Gradient
	CGContextSaveGState(c);
	CGContextClip(c);
	DrawGradient(c, size, color);
	CGContextRestoreGState(c);
	// RSS icon
	SetContentScale(c, r.size, 0.7);
	AddRSSIconPath(c, size, YES);
	CGContextEOFillPath(c);
}



#pragma mark - Appearance Settings


/// Draw icon representing global `status bar icon` (rounded RSS icon with neighbor items)
static void Appearance_MenuBarIcon(CGRect r) {
	const CGFloat size = ShorterSide(r.size);
	CGContextRef c = NSGraphicsContext.currentContext.CGContext;
	CGContextSetFillColorWithColor(c, [NSColor controlTextColor].CGColor);
	
	// menu bar
	CGContextSetAlpha(c, .23);
	const CGFloat barHeightInset = round(size*.06);
	svgRect(c, 1, CGRectInset(r, 0, barHeightInset));
	CGContextFillPath(c);
	
	const CGFloat offset = round(size*.75);
	const CGFloat iconInset = round(size*.2);
	const CGFloat iconCorner = size*.12;
	CGContextSetAlpha(c, .66);
	
	// left neighbor
	CGContextTranslateCTM(c, -offset, 0);
	svgRoundedRect(c, 1, CGRectInset(r, iconInset, iconInset), iconCorner);
	CGContextFillPath(c);
	
	// right neighbor
	CGContextTranslateCTM(c, +2*offset, 0);
	svgRoundedRect(c, 1, CGRectInset(r, iconInset, iconInset), iconCorner);
	CGContextFillPath(c);
	
	// main icon
	CGContextSetAlpha(c, 1);
	CGContextTranslateCTM(c, -offset, 0);
	svgRoundedRect(c, 1, CGRectInset(r, iconInset, iconInset), iconCorner);
	SetContentScale(c, r.size, .47);
	AddRSSIconPath(c, size, YES);
	CGContextEOFillPath(c);
}

/// Draw icon representing `Main Menu` (menu bar)
static void Appearance_MainMenu(CGRect r) {
	const CGFloat size = ShorterSide(r.size);
	CGContextRef c = NSGraphicsContext.currentContext.CGContext;
	CGContextSetFillColorWithColor(c, [NSColor controlTextColor].CGColor);
	FlipCoordinateSystem(c, r.size.height);
	// menu
	svgRect(c, size/16, CGRectMake(0, 0, 16, 3));
	svgRect(c, size/16, CGRectMake(5, 4, 9, 12));
	svgRect(c, size/16, CGRectMake(6, 3, 7, 12));
	// entries
	svgRect(c, size/16, CGRectMake(6, 12, 6, 1));
	svgRect(c, size/16, CGRectMake(6, 9, 6, 1));
	svgRect(c, size/16, CGRectMake(6, 6, 6, 1));
	CGContextEOFillPath(c);
}

/// Draw icon representing `FeedGroup` (folder)
static void Appearance_Group(CGRect r) {
	const CGFloat size = ShorterSide(r.size);
	CGContextRef c = NSGraphicsContext.currentContext.CGContext;
	FlipCoordinateSystem(c, r.size.height);
	SetContentScale(c, r.size, 0.92);
	// folder path
	svgPath(c, size/100, "M15,87c-12,0-15-3-15-15V21c0-10,3-13,13-13h11c10,0,8,8,18,8h43c12,0,15,3,15,15v41c0,12-3,15-15,15H15Z");
	// line
	svgPath(c, size/100, "M7,32h86Z");
	CGContextSetLineWidth(c, size * 0.08);
	CGContextSetStrokeColorWithColor(c, [NSColor controlTextColor].CGColor);
	CGContextStrokePath(c);
}

/// Draw icon representing `Feed` (group + RSS)
static void Appearance_Feed(CGRect r) {
	CGContextRef c = NSGraphicsContext.currentContext.CGContext;
	CGContextSetFillColorWithColor(c, [NSColor controlTextColor].CGColor);
	SetContentScale(c, r.size, 14/16.0);
	AddRSSIconPath(c, ShorterSide(r.size), YES);
	CGContextFillPath(c);
}

/// Draw icon representing `Article` (RSS inside text document)
static void Appearance_Article(CGRect r) {
	const CGFloat size = ShorterSide(r.size);
	CGContextRef c = NSGraphicsContext.currentContext.CGContext;
	CGContextSetFillColorWithColor(c, [NSColor controlTextColor].CGColor);
	FlipCoordinateSystem(c, r.size.height);
	// text lines
	svgRect(c, size/16, CGRectMake(0, 14, 16, 1));
	svgRect(c, size/16, CGRectMake(0, 10, 16, 1));
	svgRect(c, size/16, CGRectMake(9, 6, 7, 1));
	svgRect(c, size/16, CGRectMake(9, 2, 7, 1));
	// picture
	//svgRect(c, size/16, CGRectMake(1, 1, 7, 7));
	// RSS icon
	CGContextTranslateCTM(c, size/16 * 1, size/16 * 1);
	CGContextScaleCTM(c, 7.0/16, 7.0/16);
	FlipCoordinateSystem(c, r.size.height);
	AddRSSIconPath(c, ShorterSide(r.size), YES);
	CGContextEOFillPath(c);
}


#pragma mark - Other Icons


/// Draw unread icon (blue dot for unread menu item)
static void DrawUnreadIcon(CGRect r, NSColor *color) {
	const CGFloat radius = ShorterSide(r.size) / 2.0;
	CGContextRef c = NSGraphicsContext.currentContext.CGContext;
	CGMutablePathRef path = CGPathCreateMutable();
	SetContentScale(c, r.size, 0.7);
	CGContextTranslateCTM(c, 0, radius * -0.15); // align with baseline of menu item text
	
	// outer ring (opaque)
	CGContextSetFillColorWithColor(c, color.CGColor);
	CGPathAddArc(path, NULL, radius, radius, radius, 0, M_PI * 2, YES);
	CGPathAddArc(path, NULL, radius, radius, radius*.7, 0, M_PI * -2, YES);
	CGContextAddPath(c, path);
	CGContextEOFillPath(c);
	
	// inner circle (translucent)
	CGContextSetFillColorWithColor(c, [color colorWithAlphaComponent:0.5].CGColor);
	CGPathAddArc(path, NULL, radius, radius, radius, 0, M_PI * 2, YES);
	CGContextAddPath(c, path);
	CGContextFillPath(c);
	CGPathRelease(path);
}

/// Draw "(.*)" as vector path
static void DrawRegexIcon(CGRect r) {
	const CGFloat size = ShorterSide(r.size);
	CGContextRef c = NSGraphicsContext.currentContext.CGContext;
	
	svgRoundedRect(c, 1, r, .2 * size);
	CGContextSetFillColorWithColor(c, NSColor.redColor.CGColor);
	CGContextFillPath(c);
	
	// SVG files use bottom-left corner coordinate system. Quartz uses top-left.
	FlipCoordinateSystem(c, r.size.height);
	SetContentScale(c, r.size, 0.8);
	// "("
	svgPath(c, size/1000, "m184 187c-140 205-134 432-1 622l-66 44c-159-221-151-499 0-708z");
	// "."
	svgCircle(c, size/1000, 315, 675, 70, NO);
	// "*"
	svgPath(c, size/1000, "m652 277 107-35 21 63-109 36 68 92-54 39-68-93-66 91-52-41 67-88-109-37 21-63 108 37v-113h66v112z");
	// ")"
	svgPath(c, size/1000, "m816 813c140-205 134-430 1-621l66-45c159 221 151 499 0 708z");
	
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
	// Default feed icon (fallback icon if no favicon found)
	Register(16, RSSImageDefaultRSSIcon, NSLocalizedString(@"Default feed icon", nil), ^(NSRect r) { RoundedRSS_Gradient(r, [NSColor rssOrange]); return YES; });
	// Menu bar icon
	Register(16, RSSImageMenuBarIconActive, NSLocalizedString(@"Menu bar icon", nil), ^(NSRect r) { RoundedRSS_Monochrome(r, YES); return YES; });
	Register(16, RSSImageMenuBarIconPaused, NSLocalizedString(@"Menu bar icon, paused", nil), ^(NSRect r) { RoundedRSS_Monochrome(r, NO); return YES; });
	// Appearance settings
	Register(16, RSSImageSettingsGlobalIcon, NSLocalizedString(@"Global settings, menu bar icon", nil), ^(NSRect r) { Appearance_MenuBarIcon(r); return YES; });
	Register(16, RSSImageSettingsGlobalMenu, NSLocalizedString(@"Global settings, main menu", nil), ^(NSRect r) { Appearance_MainMenu(r); return YES; });
	Register(16, RSSImageSettingsGroup, NSLocalizedString(@"Group settings", nil), ^(NSRect r) { Appearance_Group(r); return YES; });
	Register(16, RSSImageSettingsFeed, NSLocalizedString(@"Feed settings", nil), ^(NSRect r) { Appearance_Feed(r); return YES; });
	Register(16, RSSImageSettingsArticle, NSLocalizedString(@"Article settings", nil), ^(NSRect r) { Appearance_Article(r); return YES; });
	// Other settings
	Register(14, RSSImageMenuItemUnread, NSLocalizedString(@"Unread indicator", nil), ^(NSRect r) { DrawUnreadIcon(r, [NSColor unreadIndicatorColor]); return YES; });
	Register(32, RSSImageRegexIcon, NSLocalizedString(@"Regex icon", nil), ^(NSRect r) { DrawRegexIcon(r); return YES; });
}
