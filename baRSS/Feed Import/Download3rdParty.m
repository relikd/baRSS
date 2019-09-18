//
//  The MIT License (MIT)
//  Copyright (c) 2019 Oleg Geier
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

#include "Download3rdParty.h"

@implementation YouTubePlugin

/**
 Transforms YouTube URL to XML feed URL. @c https://www.youtube.com/{channel|user|playlist]}/{id}
 
 @note
 Some YouTube HTML pages contain the 'alternate' tag, others don't.
 This method will only be executed, if no other feed url was found.

 @return @c nil if @c url is not properly formatted, YouTube feed URL otherwise.
 */
+ (NSString*)feedURL:(NSURL*)url {
	if (![url.host hasSuffix:@"youtube.com"]) // 'youtu.be' & 'youtube-nocookie.com' will redirect
		return nil;
	// https://www.youtube.com/channel/[channel-id]
	// https://www.youtube.com/user/[user-name]
	// https://www.youtube.com/playlist?list=[playlist-id]
#ifdef DEBUG
	printf("resolving YouTube url:\n");
	printf(" ↳ %s\n", url.absoluteString.UTF8String);
#endif
	NSString *found = nil;
	NSArray<NSString*> *parts = url.pathComponents;
	if (parts.count > 1) { // first path component is always '/'
		static NSString* const ytBase = @"https://www.youtube.com/feeds/videos.xml";
		NSString *type = parts[1];
		if ([type isEqualToString:@"channel"]) {
			if (parts.count > 2)
				found = [ytBase stringByAppendingFormat:@"?channel_id=%@", parts[2]];
		} else if ([type isEqualToString:@"user"]) {
			if (parts.count > 2)
				found = [ytBase stringByAppendingFormat:@"?user=%@", parts[2]];
		} else if ([type isEqualToString:@"playlist"]) {
			NSURLComponents *uc = [NSURLComponents componentsWithURL:url resolvingAgainstBaseURL:NO];
			for (NSURLQueryItem *q in uc.queryItems) {
				if ([q.name isEqualToString:@"list"]) {
					found = [ytBase stringByAppendingFormat:@"?playlist_id=%@", q.value];
					break;
				}
			}
		}
	}
#ifdef DEBUG
	printf(" ↳ %s\n", found ? found.UTF8String : "could not resolve!");
#endif
	return found; // may be nil
}

/// @return @c http://i.ytimg.com/vi/<videoid>/default.jpg
+ (NSString*)videoImage:(NSString*)videoid {
	return [NSString stringWithFormat:@"http://i.ytimg.com/vi/%@/default.jpg", videoid];
}

/// @return @c http://i.ytimg.com/vi/<videoid>/hqdefault.jpg
+ (NSString*)videoImageHQ:(NSString*)videoid {
	return [NSString stringWithFormat:@"http://i.ytimg.com/vi/%@/hqdefault.jpg", videoid];
}

@end

