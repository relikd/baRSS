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
