@import Cocoa;

@interface StrictUIntFormatter : NSFormatter
/// Note: must contain `%ld` and is used as formatter string.
@property (nullable, copy) NSString *unit;
@end
