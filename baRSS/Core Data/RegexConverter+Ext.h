@import Cocoa;
#import "RegexConverter+CoreDataClass.h"

NS_ASSUME_NONNULL_BEGIN

@interface RegexConverter (Ext)
+ (instancetype)newInContext:(NSManagedObjectContext*)moc;
- (void)setEntryIfChanged:(nullable NSString*)pattern;
- (void)setHrefIfChanged:(nullable NSString*)pattern;
- (void)setTitleIfChanged:(nullable NSString*)pattern;
- (void)setDescIfChanged:(nullable NSString*)pattern;
- (void)setDateIfChanged:(nullable NSString*)pattern;
- (void)setDateFormatIfChanged:(nullable NSString*)pattern;
@end

NS_ASSUME_NONNULL_END
