#import "StrictUIntFormatter.h"

@implementation StrictUIntFormatter
/// Display object as integer formatted string.
- (NSString *)stringForObjectValue:(id)obj {
	return [NSString stringWithFormat:@"%d", [[NSString stringWithFormat:@"%@", obj] intValue]];
}
/// Parse any pasted input as integer.
- (BOOL)getObjectValue:(out id  _Nullable __autoreleasing *)obj forString:(NSString *)string errorDescription:(out NSString *__autoreleasing  _Nullable *)error {
	*obj = [[NSNumber numberWithInt:[string intValue]] stringValue];
	return YES;
}
/// Only digits, no other character allowed
- (BOOL)isPartialStringValid:(NSString *__autoreleasing  _Nonnull *)partialStringPtr proposedSelectedRange:(NSRangePointer)proposedSelRangePtr originalString:(NSString *)origString originalSelectedRange:(NSRange)origSelRange errorDescription:(NSString *__autoreleasing  _Nullable *)error {
	for (NSUInteger i = 0; i < [*partialStringPtr length]; i++) {
		unichar c = [*partialStringPtr characterAtIndex:i];
		if (c < '0' || c > '9')
			return NO;
	}
	return YES;
}
@end

