#import "NSURLRequest+Ext.h"
#import "NSString+Ext.h"
#import "NSError+Ext.h"

/// @return Shared URL session with caches disabled, enabled gzip encoding and custom user agent.
static NSURLSession* NonCachingURLSession(void) {
	static NSURLSession *session = nil;
	static dispatch_once_t onceToken;
	dispatch_once(&onceToken, ^{
		NSURLSessionConfiguration *conf = [NSURLSessionConfiguration defaultSessionConfiguration];
		conf.HTTPCookieAcceptPolicy = NSHTTPCookieAcceptPolicyNever;
		conf.HTTPShouldSetCookies = NO;
		conf.HTTPCookieStorage = nil; // disables '~/Library/Cookies/'
		conf.requestCachePolicy = NSURLRequestReloadIgnoringLocalCacheData;
		conf.URLCache = nil; // disables '~/Library/Caches/de.relikd.baRSS/'
		conf.HTTPAdditionalHeaders = @{ @"User-Agent": @"baRSS (macOS)",
										@"Accept-Encoding": @"gzip" };
		session = [NSURLSession sessionWithConfiguration:conf];
	});
	return session;
}


@implementation NSURLRequest (Ext)

/// @return New request from URL. Ensures that at least @c http scheme is set.
+ (instancetype)withURL:(NSString*)urlStr {
	NSURL *url = [NSURL URLWithString:urlStr];
	if (!url.scheme)
		url = [NSURL URLWithString:[NSString stringWithFormat:@"http://%@", urlStr]]; // will redirect to https
	return [self requestWithURL:url];
}

/// Perform request with non caching @c NSURLSession . If HTTP status code is @c 304 then @c data @c = @c nil.
- (NSURLSessionDataTask*)dataTask:(nonnull void(^)(NSData * _Nullable data, NSError * _Nullable error, NSHTTPURLResponse *response))block {
	NSURLSessionDataTask *task = [NonCachingURLSession() dataTaskWithRequest:self completionHandler:^(NSData * _Nullable data, NSURLResponse * _Nullable response, NSError * _Nullable error) {
		NSHTTPURLResponse* httpResponse = (NSHTTPURLResponse*)response;
		NSInteger status = [httpResponse statusCode];
#if DEBUG && ENV_LOG_DOWNLOAD
		/*if (status != 304)*/ printf("GET %ld %s\n", status, self.URL.absoluteString.UTF8String);
#endif
		if (error || status == 304) {
			data = nil; // if status == 304, data & error nil
		} else if (status >= 400 && status < 600) { // catch Client & Server errors
			error = [NSError statusCode:status reason:(status >= 500 ? [NSString plainTextFromHTMLData:data] : nil)];
			data = nil;
		}
		block(data, error, httpResponse);
	}];
	[task resume];
	return task;
}

/// Prepare a download task and immediatelly perform request with non caching URL session.
- (NSURLSessionDownloadTask*)downloadTask:(void(^)(NSURL * _Nullable path, NSError * _Nullable error))block {
	NSURLSessionDownloadTask *task = [NonCachingURLSession() downloadTaskWithRequest:self completionHandler:^(NSURL * _Nullable location, NSURLResponse * _Nullable response, NSError * _Nullable error) {
		block(location, error);
	}];
	[task resume];
	return task;
}

/*
 Developer Tip, error log:
 
 Task <..> HTTP load failed (error code: -1003 [12:8])
 Task <..> finished with error - code: -1003  ---  NSURLErrorCannotFindHost
 ==> NSURLErrorCannotFindHost in #import <Foundation/NSURLError.h>
 
 TIC TCP Conn Failed [21:0x1d417fb00]: 1:65 Err(65)  ---  EHOSTUNREACH, No route to host
 TIC Read Status [9:0x0]: 1:57  ---  ENOTCONN, Socket is not connected
 ==> EHOSTUNREACH in #import <sys/errno.h>
 */

@end
