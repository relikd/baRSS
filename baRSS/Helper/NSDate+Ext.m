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

#import "NSDate+Ext.h"

#import <QuartzCore/QuartzCore.h>

static const char _shortnames[] = {'y','w','d','h','m','s'};
static const char *_names[] = {"Years", "Weeks", "Days", "Hours", "Minutes", "Seconds"};
static const TimeUnitType _values[] = {
	TimeUnitYears,
	TimeUnitWeeks,
	TimeUnitDays,
	TimeUnitHours,
	TimeUnitMinutes,
	TimeUnitSeconds,
};


@implementation NSDate (Ext)

/// If @c flag @c = @c YES, print @c 1.1f float string with single char unit: e.g., 3.3m, 1.7h.
+ (nonnull NSString*)stringForInterval:(Interval)intv rounded:(BOOL)flag {
	if (flag) {
		unsigned short i = [self floatUnitIndexForInterval:abs(intv)];
		return [NSString stringWithFormat:@"%1.1f%c", intv / (float)_values[i], _shortnames[i]];
	}
	unsigned short i = [self exactUnitIndexForInterval:abs(intv)];
	return [NSString stringWithFormat:@"%d%c", intv / _values[i], _shortnames[i]];
}

/// @return Highest non-zero unit ( @c flag=YES ). Or highest integer-dividable unit ( @c flag=NO ).
+ (TimeUnitType)unitForInterval:(Interval)intv rounded:(BOOL)flag {
	if (flag) {
		return _values[[self floatUnitIndexForInterval:abs(intv)]];
	}
	return _values[[self exactUnitIndexForInterval:abs(intv)]];
}

/// @return Highest unit type that allows integer division. E.g., '61 minutes'.
+ (unsigned short)exactUnitIndexForInterval:(Interval)intv {
	for (unsigned short i = 0; i < 5; i++)
		if (intv % _values[i] == 0) return i;
	return 5; // seconds
}

/// @return Highest non-zero unit type. Can be used with fractions e.g., '1.1 hours'.
+ (unsigned short)floatUnitIndexForInterval:(Interval)intv {
	for (unsigned short i = 0; i < 5; i++)
		if (intv > _values[i]) return i;
	return 5; // seconds
}
/* NOT USED
/// Convert any unit to the next smaller one. Unit does not have to be exact.
+ (TimeUnitType)smallerUnit:(TimeUnitType)unit {
	if (unit <= TimeUnitHours) return TimeUnitSeconds;
	if (unit <= TimeUnitDays) return TimeUnitMinutes; // > hours
	if (unit <= TimeUnitWeeks) return TimeUnitHours; // > days
	if (unit <= TimeUnitYears) return TimeUnitDays; // > weeks
	return TimeUnitWeeks; // > years
}

/// @return Formatted string from @c timeIntervalSinceNow.
- (nonnull NSString*)intervalStringWithDecimal:(BOOL)flag {
	return [NSDate stringForInterval:(Interval)[self timeIntervalSinceNow] rounded:flag];
}

/// @return Highest non-zero unit ( @c flag=YES ). Or highest integer-dividable unit ( @c flag=NO ).
- (TimeUnitType)unitWithDecimal:(BOOL)flag {
	Interval absIntv = abs((Interval)[self timeIntervalSinceNow]);
	if (flag) {
		return _values[ [NSDate floatUnitIndexForInterval:absIntv] ];
	}
	return _values[ [NSDate exactUnitIndexForInterval:absIntv] ];
}
*/
@end


@implementation NSDate (RefreshControlsUI)

/// @return Interval by multiplying the text field value with the currently selected popup unit.
+ (Interval)intervalForPopup:(NSPopUpButton*)unit andField:(NSTextField*)value {
	return value.intValue * (Interval)unit.selectedTag;
}

/// Configure both @c NSControl elements based on the provided interval @c intv.
+ (void)setInterval:(Interval)intv forPopup:(NSPopUpButton*)popup andField:(NSTextField*)field animate:(BOOL)flag {
	TimeUnitType unit = [self unitForInterval:intv rounded:NO];
	int num = (int)(intv / unit);
	if (flag && popup.selectedTag != unit) [self animateControlSize:popup];
	if (flag && field.intValue != num)     [self animateControlSize:field];
	[popup selectItemWithTag:unit];
	field.intValue = num;
}

/// Insert all @c TimeUnitType items into popup button. Save unit value into @c tag attribute.
+ (void)populateUnitsMenu:(NSPopUpButton*)popup selected:(TimeUnitType)unit {
	[popup removeAllItems];
	for (NSUInteger i = 0; i < 6; i++) {
		[popup addItemWithTitle:[NSString stringWithUTF8String:_names[i]]];
		NSMenuItem *item = popup.lastItem;
		[item setKeyEquivalent:[[NSString stringWithFormat:@"%c", _shortnames[i]] uppercaseString]];
		item.tag = _values[i];
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
