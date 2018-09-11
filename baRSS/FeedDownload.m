//
//  The MIT License (MIT)
//  Copyright (c) 2018 Oleg Geier
//
//  Permission is hereby granted, free of charge, to any person obtaining a copy of
//  this software and associated documentation files (the "Software"), to deal in
//  the Software without restriction, including without limitation the rights to
//  use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies
//  of the Software, and to permit persons to whom the Software is furnished to do
//  so, subject to the following conditions:
//
//  The above copyright notice and this permission notice shall be included in all
//  copies or substantial portions of the Software.
//
//  THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
//  IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
//  FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
//  AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
//  LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
//  OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
//  SOFTWARE.

#import "FeedDownload.h"

@implementation FeedDownload

+ (void)getFeed:(NSString *)url block:(void(^)(RSParsedFeed *feed, NSError* error, NSHTTPURLResponse* response))block {
	NSMutableURLRequest *req = [NSMutableURLRequest requestWithURL:[NSURL URLWithString:url]];
	req.timeoutInterval = 30;
	req.cachePolicy = NSURLRequestReloadIgnoringCacheData;
//	[req setValue:@"Mon, 10 Sep 2018 10:32:19 GMT" forHTTPHeaderField:@"If-Modified-Since"];
//	[req setValue:@"wII2pETT9EGmlqyCHBFJpm25/7w" forHTTPHeaderField:@"If-None-Match"]; // ETag
	[[[NSURLSession sharedSession] dataTaskWithRequest:req completionHandler:^(NSData * _Nullable data, NSURLResponse * _Nullable response, NSError * _Nullable error) {
		NSHTTPURLResponse* httpResponse = (NSHTTPURLResponse*)response;
//		NSString* etag = [httpResponse allHeaderFields][@"Etag"];
//		if (etag.length > 5 && [[etag substringFromIndex:etag.length - 5] isEqualToString:@"-gzip"]) {
//			etag = [etag substringToIndex:etag.length - 5];
//		}
		if (error || [httpResponse statusCode] == 304) {
			block(nil, error, httpResponse);
			return;
		}
		RSXMLData *xml = [[RSXMLData alloc] initWithData:data urlString:url];
		RSParseFeed(xml, ^(RSParsedFeed * _Nullable parsedFeed, NSError * _Nullable err) {
			block(parsedFeed, err, httpResponse);
		});
	}] resume];
}

@end
