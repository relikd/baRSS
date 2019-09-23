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

@import QuartzCore;
#import "NSDate+Ext.h"

static TimeUnitType const _values[] = {
	TimeUnitYears,
	TimeUnitWeeks,
	TimeUnitDays,
	TimeUnitHours,
	TimeUnitMinutes,
	TimeUnitSeconds,
};


@implementation NSDate (Ext)

/// @return Time as string in iso format: @c YYYY-MM-DD'T'hh:mm:ss'Z'
+ (NSString*)timeStringISO8601 {
	return [[[NSISO8601DateFormatter alloc] init] stringFromDate:[NSDate date]];
}

/// @return Day as string in iso format: @c YYYY-MM-DD
+ (NSString*)dayStringISO8601 {
	NSDateComponents *now = [[NSCalendar currentCalendar] components:NSCalendarUnitDay | NSCalendarUnitMonth | NSCalendarUnitYear fromDate:[NSDate date]];
	return [NSString stringWithFormat:@"%04ld-%02ld-%02ld", now.year, now.month, now.day];
}

/// @return Day as string in localized short format, e.g., @c DD.MM.YY
+ (NSString*)dayStringLocalized {
	return [NSDateFormatter localizedStringFromDate:[NSDate date] dateStyle:NSDateFormatterShortStyle timeStyle:NSDateFormatterNoStyle];
}

@end


@implementation NSDate (Interval)

/// Short interval formatter string (e.g., '30 min', '2 hrs')
+ (nullable NSString*)intStringForInterval:(Interval)intv {
	TimeUnitType unit = [self unitForInterval:intv];
	Interval num = intv / unit;
	NSDateComponents *dc = [[NSDateComponents alloc] init];
	switch (unit) {
		case TimeUnitSeconds: dc.second = num; break;
		case TimeUnitMinutes: dc.minute = num; break;
		case TimeUnitHours:   dc.hour = num; break;
		case TimeUnitDays:    dc.day = num; break;
		case TimeUnitWeeks:   dc.weekOfMonth = num; break;
		case TimeUnitYears:   dc.year = num; break;
	}
	return [NSDateComponentsFormatter localizedStringFromDateComponents:dc unitsStyle:NSDateComponentsFormatterUnitsStyleShort];
}

/// Print @c 1.1f float string with single char unit: e.g., 3.3m, 1.7h.
+ (nonnull NSString*)floatStringForInterval:(Interval)intv {
	unsigned short i = [self floatUnitIndexForInterval:abs(intv)];
	return [NSString stringWithFormat:@"%1.1f%c", intv / (float)_values[i], "ywdhms"[i]];
}

/// Short interval formatter string for remaining time until @c other date
+ (nullable NSString*)stringForRemainingTime:(NSDate*)other {
	NSDateComponentsFormatter *formatter = [[NSDateComponentsFormatter alloc] init];
	formatter.unitsStyle = NSDateComponentsFormatterUnitsStyleShort; // e.g., '30 min'
	formatter.maximumUnitCount = 1;
	return [formatter stringFromTimeInterval: other.timeIntervalSinceNow];
}

/// Round uneven intervals to highest unit interval. E.g., @c 1:40–>2:00 or @c 1:03–>1:00
+ (Interval)floatToIntInterval:(Interval)intv {
	TimeUnitType unit = _values[[self floatUnitIndexForInterval:abs(intv)]];
	return (Interval)(roundf((float)intv / unit) * unit);
}

/// @return Highest integer-dividable unit. E.g., '61 minutes'
+ (TimeUnitType)unitForInterval:(Interval)intv {
	if (intv == 0) return TimeUnitMinutes; // fallback to 0 minutes
	for (unsigned short i = 0; i < 5; i++) // try: years -> minutes
		if (intv % _values[i] == 0) return _values[i];
	return TimeUnitSeconds;
}

/// @return Highest non-zero unit type. Can be used with fractions e.g., '1.1 hours'.
+ (unsigned short)floatUnitIndexForInterval:(Interval)intv {
	if (intv == 0) return 4; // fallback to 0 minutes
	for (unsigned short i = 0; i < 5; i++)
		if (intv > _values[i]) return i;
	return 5; // seconds
}

@end


@implementation NSDate (RefreshControlsUI)

/// @return Interval by multiplying the text field value with the currently selected popup unit.
+ (Interval)intervalForPopup:(NSPopUpButton*)unit andField:(NSTextField*)value {
	return value.intValue * (Interval)unit.selectedTag;
}

/// Configure both @c NSControl elements based on the provided interval @c intv.
+ (void)setInterval:(Interval)intv forPopup:(NSPopUpButton*)popup andField:(NSTextField*)field animate:(BOOL)flag {
	TimeUnitType unit = [self unitForInterval:intv];
	int num = (int)(intv / unit);
	if (flag && popup.selectedTag != unit) [self animateControlSize:popup];
	if (flag && field.intValue != num)     [self animateControlSize:field];
	[popup selectItemWithTag:unit];
	field.intValue = num;
}

/// Insert all @c TimeUnitType items into popup button. Save unit value into @c tag attribute.
+ (void)populateUnitsMenu:(NSPopUpButton*)popup selected:(TimeUnitType)unit {
	[popup removeAllItems];
	[popup addItemsWithTitles:@[NSLocalizedString(@"Years", nil), NSLocalizedString(@"Weeks", nil),
								NSLocalizedString(@"Days", nil), NSLocalizedString(@"Hours", nil),
								NSLocalizedString(@"Minutes", nil), NSLocalizedString(@"Seconds", nil)]];
	for (int i = 0; i < 6; i++) {
		[popup itemAtIndex:i].tag = _values[i];
		[popup itemAtIndex:i].keyEquivalent = [NSString stringWithFormat:@"%d", i+1]; // Cmd+1 .. Cmd+6
	}
	[popup selectItemWithTag:unit];
}

/// Helper method to animate @c NSControl to draw user attention. View will be scalled up in a fraction of a second.
+ (void)animateControlSize:(NSView*)control {
	CABasicAnimation *scale = [CABasicAnimation animationWithKeyPath:@"transform"];
	CATransform3D tr = CATransform3DIdentity;
	tr = CATransform3DTranslate(tr, NSMidX(control.bounds), NSMidY(control.bounds), 0);
	tr = CATransform3DScale(tr, 1.1, 1.1, 1);
	tr = CATransform3DTranslate(tr, -NSMidX(control.bounds), -NSMidY(control.bounds), 0);
	scale.toValue = [NSValue valueWithCATransform3D:tr];
	scale.duration = 0.15f;
	scale.timingFunction = [CAMediaTimingFunction functionWithName:kCAMediaTimingFunctionEaseIn];
	[control.layer addAnimation:scale forKey:scale.keyPath];
}

@end


@implementation NSDate (Statistics)

/**
 @return @c nil if list contains less than 2 entries. Otherwise: @{min, max, avg, median, earliest, latest}
 */
+ (NSDictionary*)refreshIntervalStatistics:(NSArray<NSDate*> *)list {
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

@end
