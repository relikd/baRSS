#include "Download3rdParty.h"

@implementation YouTubePlugin

/**
 Transforms YouTube URL to XML feed URL. @c https://www.youtube.com/{channel|user|playlist]}/{id}
 
 @note
 Some YouTube HTML pages contain the 'alternate' tag, others don't.
 This method will only be executed, if no other feed url was found.

 @return @c nil if @c url is not properly formatted, YouTube feed URL otherwise.
 */
+ (NSString*)feedURL:(NSURL*)url data:(NSData*)html {
	if (![url.host hasSuffix:@"youtube.com"]) // 'youtu.be' & 'youtube-nocookie.com' will redirect
		return nil;
	// https://www.youtube.com/channel/[channel-id]
	// https://www.youtube.com/user/[user-name]
	// https://www.youtube.com/playlist?list=[playlist-id]
	// https://www.youtube.com/c/[channel-name]
#if DEBUG && ENV_LOG_YOUTUBE
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
		} else if ([type isEqualToString:@"c"]) {
			NSData *m_head = [@"<meta itemprop=\"channelId\" content=\"" dataUsingEncoding:NSUTF8StringEncoding];
			NSRange tmp = [html rangeOfData:m_head options:0 range:NSMakeRange(0, html.length)];
			if (tmp.location == NSNotFound) {
				NSData *m_json = [@"\"channelId\":\"" dataUsingEncoding:NSUTF8StringEncoding];
				tmp = [html rangeOfData:m_json options:0 range:NSMakeRange(0, html.length)];
			}
			NSUInteger start = tmp.location + tmp.length;
			NSUInteger end = html.length - start;
			if (end > 50) end = 50; // no need to search till the end
			NSString *substr = [[NSString alloc] initWithData:[html subdataWithRange:NSMakeRange(start, end)] encoding:NSUTF8StringEncoding];
			if (substr) {
				NSUInteger to = [substr rangeOfString:@"\""].location;
				if (to != NSNotFound) {
					found = [ytBase stringByAppendingFormat:@"?channel_id=%@", [substr substringToIndex:to]];
				}
			}
		}
	}
#if DEBUG && ENV_LOG_YOUTUBE
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

/// @return @c http://i.ytimg.com/vi/<videoid>/maxresdefault.jpg
+ (NSString*)videoImage4k:(NSString*)videoid {
	return [NSString stringWithFormat:@"http://i.ytimg.com/vi/%@/maxresdefault.jpg", videoid];
}

@end

