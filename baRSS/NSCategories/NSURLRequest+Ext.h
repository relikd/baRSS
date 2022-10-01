@import Cocoa;

#define ENV_LOG_DOWNLOAD 1

NS_ASSUME_NONNULL_BEGIN

@interface NSURLRequest (Ext)
+ (instancetype)withURL:(NSString*)urlStr;
- (NSURLSessionDataTask*)dataTask:(nonnull void(^)(NSData * _Nullable data, NSError * _Nullable error, NSHTTPURLResponse *response))block;
- (NSURLSessionDownloadTask*)downloadTask:(void(^)(NSURL * _Nullable path, NSError * _Nullable error))block;
@end

NS_ASSUME_NONNULL_END
