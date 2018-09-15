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

@implementation NSColor (RandomColor)
+ (NSColor*)randomColor {
	return [NSColor colorWithRed:(arc4random()%50+20)/100.0
						   green:(arc4random()%50+20)/100.0
							blue:(arc4random()%50+20)/100.0
						   alpha:1];
}
+ (NSColor*)rssOrange {
	return [NSColor colorWithCalibratedRed:0.984 green:0.639 blue:0.227 alpha:1.0];
}
@end

// ################################################################
// #
// #  DrawImage
// #
// ################################################################

@implementation DrawImage
@synthesize roundness = _roundness, contentScale = _contentScale;

-(id)init{self=[super init];if(self)[self initialize];return self;}
-(id)initWithFrame:(CGRect)f{self=[super initWithFrame:f];if(self)[self initialize];return self;}
-(id)initWithCoder:(NSCoder*)c{self=[super initWithCoder:c];if(self)[self initialize];return self;}

//#if !TARGET_INTERFACE_BUILDER #endif
- (void)initialize {
	_contentScale = 1.0;
	_imageView = [NSImageView imageViewWithImage:[self drawnImage]];
	[_imageView setFrameSize:self.frame.size];
	_imageView.autoresizingMask = NSViewWidthSizable | NSViewHeightSizable;
	[self addSubview:_imageView];
}

- (instancetype)initWithSize:(CGFloat)w scale:(CGFloat)s {
	self = [super initWithFrame:NSMakeRect(0, 0, w, w)];
	self.roundness = 40;
	self.contentScale = s;
	self.showBackground = YES;
	return self;
}

- (NSImage*)drawnImage {
	return [NSImage imageWithSize:self.frame.size flipped:NO drawingHandler:^BOOL(NSRect rect) {
		[self drawImageInRect:rect];
		return YES;
	}];
}

- (void)setRoundness:(CGFloat)r {
	_roundness = 0.5 * (r < 0 ? 0 : r > 100 ? 100 : r);
}

- (CGFloat)shorterSide {
	if (self.frame.size.width < self.frame.size.height)
		return self.frame.size.width;
	return self.frame.size.height;
}

- (void)drawImageInRect:(NSRect)r {
	const CGFloat s = [self shorterSide];
	CGContextRef c = [[NSGraphicsContext currentContext] CGContext];
	
	if (_showBackground) {
		CGMutablePathRef pth = CGPathCreateMutable();
		const CGFloat corner = s * (_roundness / 100.0);
		if (corner > 0) {
			CGPathAddRoundedRect(pth, NULL, r, corner, corner);
		} else {
			CGPathAddRect(pth, NULL, r);
		}
		CGContextSetFillColorWithColor(c, [_color CGColor]);
		CGContextAddPath(c, pth);
		CGPathRelease(pth);
		if ([self isMemberOfClass:[DrawImage class]])
			CGContextFillPath(c); // fill only if not a subclass
	}
	if (_contentScale != 1.0) {
		CGFloat offset = s * (1 - _contentScale) / 2;
		CGContextTranslateCTM(c, offset, offset);
		CGContextScaleCTM(c, _contentScale, _contentScale);
	}
}
@end

// ################################################################
// #
// #  RSSIcon
// #
// ################################################################

@implementation RSSIcon // content scale 0.75 works fine
+ (NSImage*)iconWithSize:(CGFloat)s {
	RSSIcon *icon = [[RSSIcon alloc] initWithSize:s scale:0.7];
	icon.barsColor = [NSColor whiteColor];
	icon.gradientColor = [NSColor rssOrange];
	return [icon drawnImage];
}

+ (NSImage*)templateIcon:(CGFloat)s tint:(NSColor*)color {
	RSSIcon *icon = [[RSSIcon alloc] initWithSize:s scale:0.7];
	icon.color = (color ? color : [NSColor blackColor]);
	return [icon drawnImage];
}

- (void)drawImageInRect:(NSRect)r {
	[super drawImageInRect:r];
	
	const CGFloat s = [self shorterSide];
	CGContextRef c = [[NSGraphicsContext currentContext] CGContext];
	CGContextSetFillColorWithColor(c, [self.color CGColor]);
	
	CGMutablePathRef bars = CGPathCreateMutable(); // the rss bars
	// circle
	const CGFloat r1 = s * 0.125; // circle radius
	CGPathAddArc(bars, NULL, r1, r1, r1, 0, M_PI * 2, YES);
	// 1st bar
	CGPathMoveToPoint(bars, NULL, 0, s * 0.65);
	CGPathAddArc(bars, NULL, 0, 0, s * 0.65, M_PI_2, 0, YES);
	CGPathAddLineToPoint(bars, NULL, s * 0.45, 0);
	CGPathAddArc(bars, NULL, 0, 0, s * 0.45, 0, M_PI_2, NO);
	CGPathCloseSubpath(bars);
	// 2nd bar
	CGPathMoveToPoint(bars, NULL, 0, s);
	CGPathAddArc(bars, NULL, 0, 0, s, M_PI_2, 0, YES);
	CGPathAddLineToPoint(bars, NULL, s * 0.8, 0);
	CGPathAddArc(bars, NULL, 0, 0, s * 0.8, 0, M_PI_2, NO);
	CGPathCloseSubpath(bars);
	
	CGContextAddPath(c, bars);
	
	if (_gradientColor) {
		CGContextSaveGState(c);
		CGContextClip(c);
		[self drawGradient:c side:s / self.contentScale];
		CGContextRestoreGState(c);
	} else {
		CGContextEOFillPath(c);
	}
	
	if (_barsColor) {
		CGContextSetFillColorWithColor(c, [_barsColor CGColor]);
		CGContextAddPath(c, bars);
		CGContextEOFillPath(c);
	}
	CGPathRelease(bars);
}

- (void)drawGradient:(CGContextRef)c side:(CGFloat)w {
	CGFloat h = 0, s = 1, b = 1, a = 1;
	@try {
		NSColor *rgbColor = [_gradientColor colorUsingColorSpace:[NSColorSpace deviceRGBColorSpace]];
		[rgbColor getHue:&h saturation:&s brightness:&b alpha:&a];
	} @catch (NSException *e) {}
	
	static const CGFloat impact = 0.3;
	NSColor *darker = [NSColor colorWithHue:h saturation:(s + impact > 1 ? 1 : s + impact) brightness:b alpha:a];
	NSColor *lighter = [NSColor colorWithHue:h saturation:(s - impact < 0 ? 0 : s - impact) brightness:b alpha:a];
	const void* cgColors[] = {
		[darker CGColor],
		[lighter CGColor],
		[darker CGColor]
	};
	CFArrayRef colors = CFArrayCreate(NULL, cgColors, 3, NULL);
	CGGradientRef gradient = CGGradientCreateWithColors(NULL, colors, NULL);
	
	CGContextDrawLinearGradient(c, gradient, CGPointMake(0, w), CGPointMake(w, 0), kCGGradientDrawsBeforeStartLocation | kCGGradientDrawsAfterEndLocation);
	CGGradientRelease(gradient);
	CFRelease(colors);
}
@end

// ################################################################
// #
// #  SettingsIconGlobal
// #
// ################################################################

@implementation SettingsIconGlobal // content scale 0.7 works fine
- (void)drawImageInRect:(NSRect)r {
	[super drawImageInRect:r]; // add path of rounded rect
	
	const CGFloat w = r.size.width;
	const CGFloat h = r.size.height;
	
	CGMutablePathRef menu = CGPathCreateMutable();
	CGPathAddRect(menu, NULL, CGRectMake(0, 0.8 * h, w, 0.2 * h));
	CGPathAddRect(menu, NULL, CGRectMake(0.3 * w, 0, 0.55 * w, 0.75 * h));
	CGPathAddRect(menu, NULL, CGRectMake(0.35 * w, 0.05 * h, 0.45 * w, 0.75 * h));
	
	CGFloat entryHeight = 0.1 * h; // 0.075
	for (int i = 0; i < 3; i++) { // 4
		//CGPathAddRect(menu, NULL, CGRectMake(0.37 * w, (2 * i + 1) * entryHeight, 0.42 * w, entryHeight)); // uncomment path above
		CGPathAddRect(menu, NULL, CGRectMake(0.35 * w, (2 * i + 1.5) * entryHeight, 0.4 * w, entryHeight * 0.8));
	}
	
	CGContextRef c = [[NSGraphicsContext currentContext] CGContext];
	CGContextSetFillColorWithColor(c, [self.color CGColor]);
	
	CGContextAddPath(c, menu);
	CGContextEOFillPath(c);
	CGPathRelease(menu);
}
@end

// ################################################################
// #
// #  SettingsIconGroup
// #
// ################################################################

@implementation SettingsIconGroup // content scale 0.8 works fine
- (void)drawImageInRect:(NSRect)r {
	[super drawImageInRect:r];
	
	const CGFloat w = r.size.width;
	const CGFloat h = r.size.height;
	const CGFloat s = (w < h ? w : h); // shorter side
	const CGFloat l = s * 0.04; // line width (half size)
	const CGFloat r1 = s * 0.05; // corners
	const CGFloat r2 = s * 0.08; // upper part, name tag
	const CGFloat r3 = s * 0.15; // lower part, corners inside
	const CGFloat posTop = 0.85 * h - l;
	const CGFloat posMiddle = 0.6 * h - l - r3;
	const CGFloat posBottom = 0.15 * h + l + r1;
	const CGFloat posNameTag = 0.3 * w - l;
	
	CGMutablePathRef upper = CGPathCreateMutable();
	CGPathMoveToPoint(upper, NULL, l, 0.5 * h);
	CGPathAddLineToPoint(upper, NULL, l, posTop - r1);
	CGPathAddArc(upper, NULL, l + r1, posTop - r1, r1, M_PI, M_PI_2, YES);
	CGPathAddArc(upper, NULL, posNameTag, posTop - r2, r2, M_PI_2, M_PI_4, YES);
	CGPathAddArc(upper, NULL, posNameTag + 2 * r2, posTop, r2, M_PI + M_PI_4, -M_PI_2, NO);
	CGPathAddArc(upper, NULL, w - l - r1, posTop - r1 - r2, r1, M_PI_2, 0, YES);
	CGPathAddArc(upper, NULL, w - l - r1, posBottom, r1, 0, -M_PI_2, YES);
	CGPathAddArc(upper, NULL, l + r1, posBottom, r1, -M_PI_2, M_PI, YES);
	CGPathCloseSubpath(upper);
	
	CGMutablePathRef lower = CGPathCreateMutable();
	CGPathMoveToPoint(lower, NULL, l, 0.5 * h);
	CGPathAddArc(lower, NULL, l + r3, posMiddle, r3, M_PI, M_PI_2, YES);
	CGPathAddArc(lower, NULL, w - l - r3, posMiddle, r3, M_PI_2, 0, YES);
	CGPathAddArc(lower, NULL, w - l - r1, posBottom, r1, 0, -M_PI_2, YES);
	CGPathAddArc(lower, NULL, l + r1, posBottom, r1, -M_PI_2, M_PI, YES);
	CGPathCloseSubpath(lower);
	
	CGContextRef c = [[NSGraphicsContext currentContext] CGContext];
	CGContextSetFillColorWithColor(c, [self.color CGColor]);
	CGContextSetStrokeColorWithColor(c, [self.color CGColor]);
	CGContextSetLineWidth(c, l * 2);
	
	CGContextAddPath(c, upper);
	CGContextAddPath(c, lower);
	if (self.showBackground) {
		CGContextAddPath(c, lower);
		CGContextEOFillPath(c);
		CGContextSetLineWidth(c, l); // thinner line
		CGContextAddPath(c, lower);
	}
	CGContextStrokePath(c);
	CGPathRelease(upper);
	CGPathRelease(lower);
}
@end

// ################################################################
// #
// #  DrawSeparator
// #
// ################################################################

@implementation DrawSeparator
- (void)drawRect:(NSRect)dirtyRect {
	NSGradient *grdnt = [[NSGradient alloc] initWithStartingColor:[NSColor darkGrayColor] endingColor:[[NSColor darkGrayColor] colorWithAlphaComponent:0.0]];
	NSRect separatorRect = NSMakeRect(1, self.frame.size.height / 2.0 - 1, self.frame.size.width - 2, 2);
	NSBezierPath *rounded = [NSBezierPath bezierPathWithRoundedRect:separatorRect xRadius:1 yRadius:1];
	[grdnt drawInBezierPath:rounded angle:0];
}
@end


