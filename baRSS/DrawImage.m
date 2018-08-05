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
			}
			CGContextFillPath(c);
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
	NSBezierPath *rounded = [NSBezierPath bezierPathWithRoundedRect:NSMakeRect(1, self.bounds.size.height/2.0-1, self.bounds.size.width-2, 2) xRadius:1 yRadius:1];
	[grdnt drawInBezierPath:rounded angle:0];
}
@end
