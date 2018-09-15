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
+ (NSColor*)randomColor { // just for testing purposes
	return [NSColor colorWithRed:(arc4random()%50+20)/100.0
						   green:(arc4random()%50+20)/100.0
							blue:(arc4random()%50+20)/100.0
						   alpha:1];
}
@end


@implementation RSSIcon

+ (NSColor*)rssOrange {
	return [NSColor colorWithCalibratedRed:0.984 green:0.639 blue:0.227 alpha:1.0];
}

+ (instancetype)iconWithSize:(NSSize)size {
	RSSIcon *icon = [[super alloc] init];
	icon.size = size;
	icon.barsColor = [NSColor whiteColor];
	icon.squareColor = [RSSIcon rssOrange];
	return icon;
}

+ (instancetype)templateIcon:(CGFloat)s tint:(NSColor*)color {
	RSSIcon *icon = [[super alloc] init];
	icon.size = NSMakeSize(s, s);
	icon.squareColor = (color ? color : [NSColor blackColor]);
	icon.isTemplate = YES;
	return icon;
}

- (instancetype)autoGradient {
	const CGFloat h = self.squareColor.hueComponent;
	const CGFloat s = self.squareColor.saturationComponent;
	const CGFloat b = self.squareColor.brightnessComponent;
	const CGFloat a = self.squareColor.alphaComponent;
	static const CGFloat impact = 0.3;
	self.squareGradientColor = [NSColor colorWithHue:h saturation:(s - impact < 0 ? 0 : s - impact) brightness:b alpha:a];
	self.squareColor = [NSColor colorWithHue:h saturation:(s + impact > 1 ? 1 : s + impact) brightness:b alpha:a];
	return self;
}

- (NSImage*)image {
	return [NSImage imageWithSize:self.size flipped:NO drawingHandler:^BOOL(NSRect rect) {
		CGFloat s = (self.size.height < self.size.width ? self.size.height : self.size.width);
		CGFloat corner = s * 0.2;
		
		CGMutablePathRef square = CGPathCreateMutable(); // the brackground
		CGPathAddRoundedRect(square, NULL, rect, corner, corner);
		
		CGMutablePathRef bars = CGPathCreateMutable(); // the rss bars
		CGAffineTransform at = CGAffineTransformMake(0.75, 0, 0, 0.75, s * 0.15, s * 0.15); // scale 0.75, translate 0.15
		// circle
		CGPathAddEllipseInRect(bars, &at, CGRectMake(0, 0, s * 0.25, s * 0.25));
		// 1st bar
		CGPathMoveToPoint(bars, &at, 0, s * 0.65);
		CGPathAddArc(bars, &at, 0, 0, s * 0.65, M_PI_2, 0, YES);
		CGPathAddLineToPoint(bars, &at, s * 0.45, 0);
		CGPathAddArc(bars, &at, 0, 0, s * 0.45, 0, M_PI_2, NO);
		CGPathCloseSubpath(bars);
		// 2nd bar
		CGPathMoveToPoint(bars, &at, 0, s);
		CGPathAddArc(bars, &at, 0, 0, s, M_PI_2, 0, YES);
		CGPathAddLineToPoint(bars, &at, s * 0.8, 0);
		CGPathAddArc(bars, &at, 0, 0, s * 0.8, 0, M_PI_2, NO);
		CGPathCloseSubpath(bars);
		
		CGContextRef c = [[NSGraphicsContext currentContext] CGContext];
		CGContextSetFillColorWithColor(c, [self.squareColor CGColor]);
		CGContextAddPath(c, square);
		if (!self.isTemplate) {
			if (self.squareGradientColor) {
				CGContextClip(c);
				const void* cgColors[] = {
					[self.squareColor CGColor],
					[self.squareGradientColor CGColor],
					[self.squareColor CGColor]
				};
				CFArrayRef colors = CFArrayCreate(NULL, cgColors, 3, NULL);
				CGGradientRef gradient = CGGradientCreateWithColors(NULL, colors, NULL);
				CGContextDrawLinearGradient(c, gradient, CGPointMake(0, s), CGPointMake(s, 0), 0);
				CGGradientRelease(gradient);
				CFRelease(colors);
			} else {
				CGContextFillPath(c);
			}
			CGContextSetFillColorWithColor(c, [self.barsColor CGColor]);
		}
		CGContextAddPath(c, bars);
		CGContextEOFillPath(c);
		
		CGPathRelease(square);
		CGPathRelease(bars);
		return YES;
	}];
}

@end



@implementation DrawSeparator
- (void)drawRect:(NSRect)dirtyRect {
	NSGradient *grdnt = [[NSGradient alloc] initWithStartingColor:[NSColor darkGrayColor] endingColor:[[NSColor darkGrayColor] colorWithAlphaComponent:0.0]];
	NSRect separatorRect = NSMakeRect(1, self.frame.size.height / 2.0 - 1, self.frame.size.width - 2, 2);
	NSBezierPath *rounded = [NSBezierPath bezierPathWithRoundedRect:separatorRect xRadius:1 yRadius:1];
	[grdnt drawInBezierPath:rounded angle:0];
}
@end



@implementation DrawImage
@synthesize roundness = _roundness;

//#if !TARGET_INTERFACE_BUILDER #endif
- (instancetype)initWithCoder:(NSCoder *)decoder {
	self = [super initWithCoder:decoder];
	_imageView = [NSImageView imageViewWithImage:[self drawnImage]];
	[_imageView setFrameSize:self.frame.size];
	_imageView.autoresizingMask = NSViewWidthSizable | NSViewHeightSizable;
	[self addSubview:_imageView];
	return self;
}

- (NSImage*)drawnImage {
	return [NSImage imageWithSize:self.frame.size flipped:NO drawingHandler:^BOOL(NSRect rect) {
		[self drawImageInRect:rect];
		return YES;
	}];
}

- (CGFloat)roundness { return _roundness; }
- (void)setRoundness:(CGFloat)roundness {
	if (roundness < 0) roundness = 0;
	else if (roundness > 100) roundness = 100;
	_roundness = roundness / 2;
}

- (CGFloat)shorterSide {
	if (self.frame.size.width < self.frame.size.height)
		return self.frame.size.width;
	return self.frame.size.height;
}

- (void)drawImageInRect:(NSRect)r {
	CGMutablePathRef pth = CGPathCreateMutable();
	CGFloat corner = (_roundness / 100.0);
	if (corner > 0) {
		corner *= [self shorterSide];
		CGPathAddRoundedRect(pth, NULL, r, corner, corner);
	} else {
		CGPathAddRect(pth, NULL, r);
	}
	CGContextRef c = [[NSGraphicsContext currentContext] CGContext];
	CGContextSetFillColorWithColor(c, [_color CGColor]);
	CGContextAddPath(c, pth);
	CGPathRelease(pth);
	if ([self isMemberOfClass:[DrawImage class]])
		CGContextFillPath(c); // fill only if not a subclass
}
@end


@implementation SettingsIconGlobal
- (void)drawImageInRect:(NSRect)r {
	CGFloat w = r.size.width;
	CGFloat h = r.size.height;
	
	CGMutablePathRef menu = CGPathCreateMutable();
//	CGFloat s = (w < h ? w : h);
	CGAffineTransform at = CGAffineTransformIdentity;//CGAffineTransformMake(0.7, 0, 0, 0.7, s * 0.15, s * 0.15); // scale 0.7, translate 0.15
	CGPathAddRect(menu, &at, CGRectMake(0, 0.8 * h, w, 0.2 * h));
	CGPathAddRect(menu, &at, CGRectMake(0.3 * w, 0, 0.55 * w, 0.75 * h));
	CGPathAddRect(menu, &at, CGRectMake(0.35 * w, 0.05 * h, 0.45 * w, 0.75 * h));
	
	CGFloat entryHeight = 0.1 * h; // 0.075
	for (int i = 0; i < 3; i++) { // 4
		//CGPathAddRect(menu, &at, CGRectMake(0.37 * w, (2 * i + 1) * entryHeight, 0.42 * w, entryHeight)); // uncomment path above
		CGPathAddRect(menu, &at, CGRectMake(0.35 * w, (2 * i + 1.5) * entryHeight, 0.4 * w, entryHeight * 0.8));
	}
	
	CGContextRef c = [[NSGraphicsContext currentContext] CGContext];
	CGContextSetFillColorWithColor(c, [self.color CGColor]);
	
//	[super drawImageInRect:r]; // add path of rounded rect
	CGContextAddPath(c, menu);
	CGPathRelease(menu);
	CGContextEOFillPath(c);
}
@end


@implementation SettingsIconGroup
- (void)drawImageInRect:(NSRect)r {
	CGFloat w = r.size.width;
	CGFloat h = r.size.height;
	CGFloat s = (w < h ? w : h); // shorter side
	CGFloat l = s * 0.04; // line size (half)
	CGFloat r1 = s * 0.05; // corners
	CGFloat r2 = s * 0.08; // upper part, name tag
	CGFloat r3 = s * 0.15; // lower part, corners inside
	CGFloat posTop = 0.85 * h - l;
	CGFloat posMiddle = 0.6 * h - l - r3;
	CGFloat posBottom = 0.15 * h + l + r1;
	CGFloat posNameTag = 0.3 * w - l;
	
	CGContextRef c = [[NSGraphicsContext currentContext] CGContext];
	CGAffineTransform at = CGAffineTransformIdentity;//CGAffineTransformMake(0.7, 0, 0, 0.7, s * 0.15, s * 0.15); // scale 0.7, translate 0.15
	CGContextSetFillColorWithColor(c, [self.color CGColor]);
	CGContextSetStrokeColorWithColor(c, [self.color CGColor]);
	CGContextSetLineWidth(c, l * 2);
	
	CGMutablePathRef upper = CGPathCreateMutable();
	CGPathMoveToPoint(upper, &at, l, 0.5 * h);
	CGPathAddLineToPoint(upper, &at, l, posTop - r1);
	CGPathAddArc(upper, &at, l + r1, posTop - r1, r1, M_PI, M_PI_2, YES);
	CGPathAddArc(upper, &at, posNameTag, posTop - r2, r2, M_PI_2, M_PI_4, YES);
	CGPathAddArc(upper, &at, posNameTag + 2 * r2, posTop, r2, M_PI + M_PI_4, -M_PI_2, NO);
	CGPathAddArc(upper, &at, w - l - r1, posTop - r1 - r2, r1, M_PI_2, 0, YES);
	CGPathAddArc(upper, &at, w - l - r1, posBottom, r1, 0, -M_PI_2, YES);
	CGPathAddArc(upper, &at, l + r1, posBottom, r1, -M_PI_2, M_PI, YES);
	CGPathCloseSubpath(upper);
	
	CGMutablePathRef lower = CGPathCreateMutable();
	CGPathMoveToPoint(lower, &at, l, 0.5 * h);
	CGPathAddArc(lower, &at, l + r3, posMiddle, r3, M_PI, M_PI_2, YES);
	CGPathAddArc(lower, &at, w - l - r3, posMiddle, r3, M_PI_2, 0, YES);
	CGPathAddArc(lower, &at, w - l - r1, posBottom, r1, 0, -M_PI_2, YES);
	CGPathAddArc(lower, &at, l + r1, posBottom, r1, -M_PI_2, M_PI, YES);
	CGPathCloseSubpath(lower);
	
	CGContextAddPath(c, upper);
	CGContextAddPath(c, lower);
	CGContextStrokePath(c);
	CGPathRelease(upper);
	CGPathRelease(lower);
}
@end
