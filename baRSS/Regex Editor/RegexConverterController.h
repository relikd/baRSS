@import Cocoa;
@class RegexConverter, RegexConverterModal, Feed;

NS_ASSUME_NONNULL_BEGIN

@interface RegexConverterController : NSViewController <NSTextFieldDelegate>
+ (instancetype)withData:(NSData *)data andConverter:(nullable RegexConverter*)converter;
- (RegexConverterModal*)getModalSheet;
- (void)applyChanges:(Feed *)feed;
@end

NS_ASSUME_NONNULL_END
