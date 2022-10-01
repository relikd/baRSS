@import Cocoa;

NS_ASSUME_NONNULL_BEGIN

@interface NSString (PlainHTML)
+ (NSString*)plainTextFromHTMLData:(NSData*)data;
- (nonnull NSString*)htmlToPlainText;
@end

@interface NSString (HexColor)
- (nullable NSColor*)hexColor;
@end

NS_ASSUME_NONNULL_END
