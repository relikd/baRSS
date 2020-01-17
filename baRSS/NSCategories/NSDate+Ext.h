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

@import Cocoa;

typedef int32_t Interval;
typedef NS_ENUM(int32_t, TimeUnitType) {
	TimeUnitSeconds = 1,
	TimeUnitMinutes = 60,
	TimeUnitHours = 60 * 60,
	TimeUnitDays = 24 * 60 * 60,
	TimeUnitWeeks = 7 * 24 * 60 * 60,
	TimeUnitYears = 365 * 24 * 60 * 60
};

NS_ASSUME_NONNULL_BEGIN

@interface NSDate (Ext)
+ (NSString*)timeStringISO8601;
+ (NSString*)dayStringISO8601;
+ (NSString*)dayStringLocalized;
@end


@interface NSDate (Interval)
+ (nullable NSString*)intStringForInterval:(Interval)intv;
+ (nonnull NSString*)floatStringForInterval:(Interval)intv;
+ (nullable NSString*)stringForRemainingTime:(NSDate*)other;
+ (Interval)floatToIntInterval:(Interval)intv;
@end


@interface NSDate (RefreshControlsUI)
+ (Interval)intervalForPopup:(NSPopUpButton*)unit andField:(NSTextField*)value;
+ (void)setInterval:(Interval)intv forPopup:(NSPopUpButton*)popup andField:(NSTextField*)field animate:(BOOL)flag;
+ (void)populateUnitsMenu:(NSPopUpButton*)popup selected:(TimeUnitType)unit;
@end


@interface NSDate (Statistics)
+ (NSDictionary*)refreshIntervalStatistics:(NSArray<NSDate*> *)list;
@end

NS_ASSUME_NONNULL_END
