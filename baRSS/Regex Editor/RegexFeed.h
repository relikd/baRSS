@import Cocoa;
@class RegexConverter;

NS_ASSUME_NONNULL_BEGIN

@interface RegexFeedEntry : NSObject
@property (nullable, readonly) NSString *href;
@property (nullable, readonly) NSString *title;
@property (nullable, readonly) NSString *desc;
@property (nullable, readonly) NSString *dateString;
@property (nullable, readonly) NSDate *date;

@property (nullable, readonly) NSString *rawMatch;
@end


@interface RegexFeed : NSObject
@property (nullable, copy) NSString *rxEntry;
@property (nullable, copy) NSString *rxHref;
@property (nullable, copy) NSString *rxTitle;
@property (nullable, copy) NSString *rxDesc;
@property (nullable, copy) NSString *rxDate;
@property (nullable, copy) NSString *dateFormat;

+ (RegexFeed *)from:(RegexConverter*)regex;

- (NSArray<RegexFeedEntry*>*)process:(NSString*)rawData error:(NSError * __autoreleasing *)err;
@end

NS_ASSUME_NONNULL_END
