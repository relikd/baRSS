#import "RegexFeed.h"
#import "RegexConverter+Ext.h"

@interface RegexFeedEntry()
@property (nullable, copy) NSString *href;
@property (nullable, copy) NSString *title;
@property (nullable, copy) NSString *desc;
@property (nullable, copy) NSString *dateString;
@property (nullable, retain) NSDate *date;

@property (nullable, copy) NSString *rawMatch;
@end

@implementation RegexFeedEntry
@end


@implementation RegexFeed

+ (RegexFeed *)from:(RegexConverter*)regex {
	RegexFeed *x = [RegexFeed new];
	x.rxEntry = regex.entry;
	x.rxHref = regex.href;
	x.rxTitle = regex.title;
	x.rxDesc = regex.desc;
	x.rxDate = regex.date;
	x.dateFormat = regex.dateFormat;
	return x;
}

- (NSArray<RegexFeedEntry*>*)process:(NSString*)rawData error:(NSError * __autoreleasing *)err {
	NSRegularExpression *re_entries = [self regex:_rxEntry error:err];
	if (!re_entries) {
		return @[];
	}
	NSDateFormatter *dateFormatter = [NSDateFormatter new];
	[dateFormatter setDateFormat:_dateFormat];
	[dateFormatter setTimeZone:[NSTimeZone timeZoneWithName:@"UTC"]];
	// TODO: we probably need to handle locale. Especially for "d. MMM" like "3. Dec"

	NSMutableArray<RegexFeedEntry*> *rv = [NSMutableArray new];
	NSRegularExpression *re4 = [self regex:_rxDate error:err];
	NSRegularExpression *re3 = [self regex:_rxDesc error:err];
	NSRegularExpression *re2 = [self regex:_rxTitle error:err];
	NSRegularExpression *re1 = [self regex:_rxHref error:err];
	NSArray<NSTextCheckingResult*> *matches = [re_entries matchesInString:rawData options:0 range:NSMakeRange(0, rawData.length)];
	
	for (NSTextCheckingResult *match in matches) {
		NSString *subdata = [rawData substringWithRange:match.range];
		RegexFeedEntry *entry = [[RegexFeedEntry alloc] init];
		entry.rawMatch = subdata;
		entry.href = [self firstMatch:subdata re:re1];
		entry.title = [self firstMatch:subdata re:re2];
		entry.desc = [self firstMatch:subdata re:re3];
		entry.dateString = [self firstMatch:subdata re:re4];
		entry.date = (_dateFormat.length && entry.dateString.length) ? [dateFormatter dateFromString:entry.dateString] : nil;
		[rv addObject:entry];
	};
	return rv;
}

- (nullable NSRegularExpression*)regex:(NSString*)pattern error:(NSError * __autoreleasing *)err {
	if (pattern.length == 0) {
		return nil;
	}
	NSRegularExpression *re = [[NSRegularExpression alloc] initWithPattern:pattern options:NSRegularExpressionDotMatchesLineSeparators error:err];
	if (*err) {
		return nil;
	}
	return re;
}

- (nonnull NSString*)firstMatch:(NSString*)str re:(NSRegularExpression*)re {
	NSTextCheckingResult *match = [[re matchesInString:str options:0 range:NSMakeRange(0, str.length)] firstObject];
	if (match) {
		if (match.numberOfRanges < 2) {
			return NSLocalizedString(@"Regex error: Missing match-group? ('outer(.*?)text')", nil);
		}else if (match.numberOfRanges > 2) {
			return NSLocalizedString(@"Regex error: Multiple match-groups found", nil);
		}
		return [str substringWithRange:[match rangeAtIndex:1]];
	}
	return @"";
}

@end
