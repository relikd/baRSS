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

#import "Statistics.h"
#import "NSDate+Ext.h"

@implementation Statistics

#pragma mark - Generate Refresh Interval Statistics

/**
 @return @c nil if list contains less than 2 entries. Otherwise: @{min, max, avg, median, earliest, latest}
 */
+ (NSDictionary*)refreshInterval:(NSArray<NSDate*> *)list {
	if (!list || list.count == 0)
		return nil;
	
	NSDate *earliest = [NSDate distantFuture];
	NSDate *latest = [NSDate distantPast];
	NSDate *prev = nil;
	NSMutableArray<NSNumber*> *differences = [NSMutableArray array];
	for (NSDate *d in list) {
		if (![d isKindOfClass:[NSDate class]]) // because valueForKeyPath: can return NSNull
			continue;
		earliest = [d earlierDate:earliest];
		latest = [d laterDate:latest];
		if (prev) {
			int dif = abs((int)[d timeIntervalSinceDate:prev]);
			[differences addObject:[NSNumber numberWithInt:dif]];
		}
		prev = d;
	}
	if (differences.count == 0)
		return nil;
	
	[differences sortUsingDescriptors:@[[NSSortDescriptor sortDescriptorWithKey:@"integerValue" ascending:YES]]];
	
	NSUInteger i = (differences.count/2);
	NSNumber *median = differences[i];
	if ((differences.count % 2) == 0) { // even feed count, use median of two values
		median = [NSNumber numberWithInteger:(median.integerValue + differences[i-1].integerValue) / 2];
	}
	return @{@"min" : differences.firstObject,
			 @"max" : differences.lastObject,
			 @"avg" : [differences valueForKeyPath:@"@avg.self"],
			 @"median" : median,
			 @"earliest" : earliest,
			 @"latest" : latest };
}


#pragma mark - Feed Statistics UI

/**
 Generate UI with buttons for min, max, avg and median. Also show number of articles and latest article date.

 @param info The dictionary generated with @c -refreshInterval:
 @param count Article count.
 @param callback If set, @c sender will be called with @c -refreshIntervalButtonClicked:.
                 If not disable button border and display as bold inline text.
 @return Centered view without autoresizing.
 */
+ (NSView*)viewForRefreshInterval:(NSDictionary*)info articleCount:(NSUInteger)count callback:(nullable id<RefreshIntervalButtonDelegate>)callback {
	NSString *lbl = [NSString stringWithFormat:NSLocalizedString(@"%lu articles.", nil), count];
	if (!info || info.count == 0)
		return [self grayLabel:lbl];
	
	// Subview with 4 button (min, max, avg, median)
	NSView *buttonsView = [[NSView alloc] init];
	NSPoint origin = NSZeroPoint;
	for (NSString *str in @[@"min", @"max", @"avg", @"median"]) {
		NSString *title = [str stringByAppendingString:@":"];
		NSView *v = [self viewWithLabel:title andInterval:info[str] callback:callback];
		[v setFrameOrigin:origin];
		[buttonsView addSubview:v];
		origin.x += NSWidth(v.frame);
	}
	[buttonsView setFrameSize:NSMakeSize(origin.x, NSHeight(buttonsView.subviews.firstObject.frame))];
	
	// Subview with article count and latest article date
	NSDate *lastUpdate = [info valueForKey:@"latest"];
	NSString *mod = [NSDateFormatter localizedStringFromDate:lastUpdate dateStyle:NSDateFormatterMediumStyle timeStyle:NSDateFormatterShortStyle];
	NSTextField *dateView = [self grayLabel:[lbl stringByAppendingFormat:@" (latest: %@)", mod]];
	
	// Feed wasn't updated in a while ...
	if ([lastUpdate timeIntervalSinceNow] < (-360 * 24 * 60 * 60)) {
		NSMutableAttributedString *as = dateView.attributedStringValue.mutableCopy;
		[as addAttribute:NSForegroundColorAttributeName value:[NSColor systemRedColor] range:NSMakeRange(lbl.length, as.length - lbl.length)];
		[dateView setAttributedStringValue:as];
	}
	
	// Calculate offset and align both horizontally centered
	CGFloat maxWidth = NSWidth(buttonsView.frame);
	if (maxWidth < NSWidth(dateView.frame))
		maxWidth = NSWidth(dateView.frame);
	[buttonsView setFrameOrigin:NSMakePoint(0.5f*(maxWidth - NSWidth(buttonsView.frame)), 0)];
	[dateView setFrameOrigin:NSMakePoint(0.5f*(maxWidth - NSWidth(dateView.frame)), NSHeight(buttonsView.frame))];
	
	// Dump both into single parent view and make that view centered during resize
	NSView *parent = [[NSView alloc] initWithFrame:NSMakeRect(0, 0, maxWidth, NSMaxY(dateView.frame))];
	parent.autoresizingMask = NSViewMinXMargin | NSViewMaxXMargin;// | NSViewMinYMargin | NSViewMaxYMargin;
	parent.autoresizesSubviews = NO;
//	parent.layer = [CALayer layer];
//	parent.layer.backgroundColor = [NSColor systemYellowColor].CGColor;
	[parent addSubview:dateView];
	[parent addSubview:buttonsView];
	return parent;
}

/**
 Create view with duration button, e.g., '3.4h' and label infornt of it.
 */
+ (NSView*)viewWithLabel:(NSString*)title andInterval:(NSNumber*)value callback:(nullable id<RefreshIntervalButtonDelegate>)callback {
	static const int buttonPadding = 5;
	NSButton *button = [self grayInlineButton:value];
	if (callback) {
		button.target = callback;
		button.action = @selector(refreshIntervalButtonClicked:);
	} else {
		button.bordered = NO;
		button.enabled = NO;
	}
	NSTextField *label;
	if (title && title.length > 0) {
		label = [self grayLabel:title];
		[label setFrameOrigin:NSMakePoint(0, button.alignmentRectInsets.bottom + 0.5f*(NSHeight(button.frame) - NSHeight(label.frame)))];
	}
	[button setFrameOrigin:NSMakePoint(NSWidth(label.frame), 0)];
	
	CGFloat maxHeight = NSHeight(button.frame);
	if (maxHeight < NSHeight(label.frame))
		maxHeight = NSHeight(label.frame);
	
	NSView *parent = [[NSView alloc] initWithFrame: NSMakeRect(0, 0, NSMaxX(button.frame) + buttonPadding, maxHeight + buttonPadding)];
	[parent addSubview:label];
	[parent addSubview:button];
	return parent;
}

/**
 @return Rounded, gray inline button with tag equal to refresh interval.
 */
+ (NSButton*)grayInlineButton:(NSNumber*)num {
	NSButton *button = [NSButton buttonWithTitle:[NSDate stringForInterval:num.intValue rounded:YES] target:nil action:nil];
	button.font = [NSFont monospacedDigitSystemFontOfSize: NSFont.labelFontSize weight:NSFontWeightBold];
	button.bezelStyle = NSBezelStyleInline;
	button.controlSize = NSControlSizeSmall;
	TimeUnitType unit = [NSDate unitForInterval:num.intValue rounded:YES];
	button.tag = (NSInteger)(roundf(num.floatValue / unit) * unit); // rounded inteval
	[button sizeToFit];
	return button;
}

/**
 @return Simple Label with smaller gray text, non-editable.
 */
+ (NSTextField*)grayLabel:(NSString*)text {
	NSTextField *label = [NSTextField textFieldWithString:text];
	label.font = [NSFont monospacedDigitSystemFontOfSize: NSFont.labelFontSize weight:NSFontWeightRegular];
	label.textColor = [NSColor systemGrayColor];
	label.drawsBackground = NO;
	label.selectable = NO;
	label.editable = NO;
	label.bezeled = NO;
	[label sizeToFit];
	return label;
}

@end
