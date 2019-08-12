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

#import "WebFeed.h"
#import "UpdateScheduler.h"
#import "Constants.h"
#import "StoreCoordinator.h"
#import "Feed+Ext.h"
#import "FeedMeta+Ext.h"
#import "FeedGroup+Ext.h"
#import "NSDate+Ext.h"
#import "NSString+Ext.h"

#include <stdatomic.h>

static BOOL _requestsAreUrgent = NO;
static _Atomic(NSUInteger) _queueSize = 0;

@implementation WebFeed

/// Disables @c NSURLNetworkServiceTypeBackground (ideally only temporarily)
+ (void)setRequestsAreUrgent:(BOOL)flag { _requestsAreUrgent = flag; }

/// @return Number of feeds being currently downloaded.
+ (NSUInteger)feedsInQueue { return _queueSize; }


#pragma mark - Request Generator


/// @return Base URL part. E.g., https://stackoverflow.com/a/15897956/10616114 ==> https://stackoverflow.com/
+ (NSURL*)hostURL:(NSString*)urlStr {
	return [[NSURL URLWithString:@"/" relativeToURL:[self fixURL:urlStr]] absoluteURL];
}

/// Check if any scheme is set. If not, prepend 'http://'.
+ (NSURL*)fixURL:(NSString*)urlStr {
	NSURL *url = [NSURL URLWithString:urlStr];
	if (!url.scheme) {
		url = [NSURL URLWithString:[NSString stringWithFormat:@"http://%@", urlStr]]; // usually will redirect to https if necessary
	}
	return url;
}

/// @return New request with no caching policy and timeout interval of 30 seconds.
+ (NSMutableURLRequest*)newRequestURL:(NSString*)urlStr {
	return [NSMutableURLRequest requestWithURL:[self fixURL:urlStr]];
}

/// @return New request with etag and modified headers set (or not, if @c flag @c == @c YES ).
+ (NSURLRequest*)newRequest:(FeedMeta*)meta ignoreCache:(BOOL)flag {
	NSMutableURLRequest *req = [self newRequestURL:meta.url];
	if (!flag) {
		if (meta.etag.length > 0)
			[req setValue:meta.etag forHTTPHeaderField:@"If-None-Match"]; // ETag
		else if (meta.modified.length > 0)
			[req setValue:meta.modified forHTTPHeaderField:@"If-Modified-Since"];
	}
	if (!_requestsAreUrgent) // any request that is not forced, is a background update
		req.networkServiceType = NSURLNetworkServiceTypeBackground;
	return req;
}

+ (NSURLSession*)nonCachingSession {
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
	return session; // [NSURLSession sharedSession];
}

/// Helper method to start new @c NSURLSession. If @c (http.statusCode==304) then set @c data @c = @c nil.
+ (void)asyncRequest:(NSURLRequest*)request block:(nonnull void(^)(NSData * _Nullable data, NSError * _Nullable error, NSHTTPURLResponse *response))block {
	[[[self nonCachingSession] dataTaskWithRequest:request completionHandler:^(NSData * _Nullable data, NSURLResponse * _Nullable response, NSError * _Nullable error) {
		NSHTTPURLResponse* httpResponse = (NSHTTPURLResponse*)response;
		NSInteger status = [httpResponse statusCode];
		if (error || status == 304) { // 304 Not Modified
			data = nil;
		} else if (status >= 500 && status < 600) { // 5xx Server Error
			NSString *reason = [NSString stringWithFormat:NSLocalizedString(@"Server HTTP error %ld.\n––––\n%@", nil),
								status, [NSString plainTextFromHTMLData:data]];
			error = [NSError errorWithDomain:NSURLErrorDomain code:NSURLErrorBadServerResponse userInfo:@{NSLocalizedDescriptionKey: reason}];
			data = nil;
		}
		block(data, error, httpResponse); // if status == 304, data & error nil
	}] resume];
}


#pragma mark - Download RSS Feed


/**
 Start download session of RSS or Atom feed, parse feed and return result on the main thread.
 
 @param xmlBlock Called immediately after @c RSXMLData is initialized. E.g., to use this data as HTML parser.
                 Return @c YES to to exit without calling @c feedBlock.
                 If @c NO and @c err @c != @c nil skip feed parsing and call @c feedBlock(nil,err,response).
 @param feedBlock Called when parsing finished or an @c NSURL error occured.
                  If content did not change (status code 304) both, error and result will be @c nil.
                  Will be called on main thread.
 */
+ (void)parseFeedRequest:(NSURLRequest*)request xmlBlock:(nullable BOOL(^)(RSXMLData *xml, NSError **err))xmlBlock feedBlock:(nonnull void(^)(RSParsedFeed *rss, NSError *error, NSHTTPURLResponse *response))feedBlock {
	[self asyncRequest:request block:^(NSData * _Nullable data, NSError * _Nullable error, NSHTTPURLResponse *response) {
		RSParsedFeed *result = nil;
		if (data) { // data = nil if (error || 304)
			RSXMLData *xml = [[RSXMLData alloc] initWithData:data url:response.URL];
			if (xmlBlock && xmlBlock(xml, &error)) {
				return;
			}
			if (!error) { // metaBlock may set error
				RSFeedParser *parser = [RSFeedParser parserWithXMLData:xml];
				parser.dontStopOnLowerAsciiBytes = YES;
				result = [parser parseSync:&error];
			}
		}
		dispatch_async(dispatch_get_main_queue(), ^{
			feedBlock(result, error, response);
		});
	}];
}

/**
 Perform feed download request from URL alone. Not updating any @c Feed item.
 
 @note @c askUser will not be called if url is XML already.
 
 @param urlStr XML URL or HTTP URL that will be parsed to find feed URLs.
 @param askUser Use @c list to present user a list of detected feed URLs.
 @param block Called after webpage has been fully parsed (including html autodetect).
 */
+ (void)newFeed:(NSString *)urlStr askUser:(nonnull NSString*(^)(RSHTMLMetadata *meta))askUser block:(nonnull void(^)(RSParsedFeed *parsed, NSError *error, NSHTTPURLResponse *response))block {
	[self parseFeedRequest:[self newRequestURL:urlStr] xmlBlock:^BOOL(RSXMLData *xml, NSError **err) {
		if (![xml.parserClass isHTMLParser])
			return NO;
		RSHTMLMetadataParser *parser = [RSHTMLMetadataParser parserWithXMLData:xml];
		RSHTMLMetadata *parsedMeta = [parser parseSync:err];
		if (*err)
			return NO;
		if (!parsedMeta || parsedMeta.feedLinks.count == 0) {
			*err = RSXMLMakeErrorWrongParser(RSXMLErrorExpectingFeed, RSXMLErrorExpectingHTML, xml.url);
			return NO;
		}
		__block NSString *chosenURL = nil;
		dispatch_sync(dispatch_get_main_queue(), ^{ // sync! (thread is already in background)
			chosenURL = askUser(parsedMeta);
		});
		if (!chosenURL || chosenURL.length == 0) { // User canceled operation, show appropriate error message
			NSString *reason = NSLocalizedString(@"Operation canceled.", nil);
			*err = [NSError errorWithDomain:NSURLErrorDomain code:NSURLErrorCancelled userInfo:@{NSLocalizedDescriptionKey: reason}];
			return NO;
		}
		[self parseFeedRequest:[self newRequestURL:chosenURL] xmlBlock:nil feedBlock:block];
		return YES;
	} feedBlock:block];
}

/**
 Start download request with existing @c Feed object. Reuses etag and modified headers (unless articles count is 0).
 
 @note Will post a @c kNotificationFeedUpdated notification if download was successful and @b not status code 304.
 
 @param alert If @c YES display Error Popup to user.
 @param block Parameter @c success is only @c YES if download was successful or if status code is 304 (not modified).
 */
+ (void)backgroundUpdateFeed:(Feed*)feed showErrorAlert:(BOOL)alert finally:(nullable void(^)(BOOL success))block {
	NSManagedObjectID *oid = feed.objectID;
	NSManagedObjectContext *moc = feed.managedObjectContext;
	NSURLRequest *req = [self newRequest:feed.meta ignoreCache:(feed.articles.count == 0)];
	NSString *reqURL = req.URL.absoluteString;
	[self parseFeedRequest:req xmlBlock:nil feedBlock:^(RSParsedFeed *rss, NSError *error, NSHTTPURLResponse *response) {
		Feed *f = [moc objectWithID:oid];
		BOOL success = NO;
		BOOL needsNotification = NO;
		if (error) {
			if (alert) {
				NSAlert *alertPopup = [NSAlert alertWithError:error];
				alertPopup.informativeText = [NSString stringWithFormat:@"Error loading source: %@", reqURL];
				[alertPopup runModal];
			}
			[f.meta setErrorAndPostponeSchedule];
		} else {
			success = YES;
			[f.meta setSucessfulWithResponse:response];
			if (rss && rss.articles.count > 0) {
				[f updateWithRSS:rss postUnreadCountChange:YES];
				needsNotification = YES;
			}
		}
		[StoreCoordinator saveContext:moc andParent:YES];
		if (needsNotification)
			PostNotification(kNotificationFeedUpdated, oid);
		if (block) block(success);
	}];
}

/**
 Download feed at url and append to persistent store in root folder.
 On error present user modal alert.
 
 Creates new @c FeedGroup, @c Feed, @c FeedMeta and @c FeedArticle instances and saves them to the persistent store.
 Update duration is set to the default of 30 minutes.
 */
+ (void)autoDownloadAndParseURL:(NSString*)url addAnyway:(BOOL)flag modify:(nullable void(^)(Feed *feed))block {
	NSManagedObjectContext *moc = [StoreCoordinator createChildContext];
	Feed *f = [Feed appendToRootWithDefaultIntervalInContext:moc];
	f.meta.url = url;
	[self backgroundUpdateBoth:f favicon:YES alert:!flag finally:^(BOOL successful){
		if (!flag && !successful) {
			[moc deleteObject:f.group];
		} else if (block) {
			block(f); // only on success
		}
		[StoreCoordinator saveContext:moc andParent:YES];
		[moc reset];
		if (successful) {
			PostNotification(kNotificationGroupInserted, f.group.objectID);
			[UpdateScheduler scheduleNextFeed];
		}
	}];
}

/// Insert Github URL for version releases with update interval 2 days and rename @c FeedGroup item.
+ (void)autoDownloadAndParseUpdateURL {
	[self autoDownloadAndParseURL:versionUpdateURL addAnyway:YES modify:^(Feed *feed) {
		feed.group.name = NSLocalizedString(@"baRSS releases", nil);
		[feed.meta setRefreshAndSchedule:2 * TimeUnitDays];
	}];
}

/**
 Start download of feed xml, then continue with favicon download (optional).
 
 @param fav If @c YES continue with favicon download after xml download finished.
 @param alert If @c YES display Error Popup to user.
 @param block Parameter @c success is @c YES if xml download succeeded (regardless of favicon result).
 */
+ (void)backgroundUpdateBoth:(Feed*)feed favicon:(BOOL)fav alert:(BOOL)alert finally:(nullable void(^)(BOOL success))block {
	[self backgroundUpdateFeed:feed showErrorAlert:alert finally:^(BOOL success) {
		if (fav && success) {
			[self backgroundUpdateFavicon:feed replaceExisting:NO finally:^{
				if (block) block(YES);
			}];
		} else {
			if (block) block(success);
		}
	}];
}

/**
 Start download of all feeds in list. Either with or without favicons.
 
 @param list Download list using @c feed.meta.url as download url. (while reusing etag and modified headers)
 @param fav If @c YES continue with favicon download after xml download finished.
 @param alert If @c YES display Error Popup to user.
 @param block Called after all downloads finished.
 */
+ (void)batchDownloadFeeds:(NSArray<Feed*> *)list favicons:(BOOL)fav showErrorAlert:(BOOL)alert finally:(nullable os_block_t)block {
	[UpdateScheduler beginUpdate];
	atomic_fetch_add_explicit(&_queueSize, list.count, memory_order_relaxed);
	PostNotification(kNotificationBackgroundUpdateInProgress, @(_queueSize));
	dispatch_group_t group = dispatch_group_create();
	for (Feed *f in list) {
		dispatch_group_enter(group);
		[self backgroundUpdateBoth:f favicon:fav alert:alert finally:^(BOOL success){
			atomic_fetch_sub_explicit(&_queueSize, 1, memory_order_relaxed);
			PostNotification(kNotificationBackgroundUpdateInProgress, @(_queueSize));
			dispatch_group_leave(group);
		}];
	}
	dispatch_group_notify(group, dispatch_get_main_queue(), ^{
		if (block) block();
		[UpdateScheduler endUpdate];
		PostNotification(kNotificationBackgroundUpdateInProgress, @(0));
	});
}


#pragma mark - Download Favicon


/**
 Start favicon download request on existing @c Feed object.
 
 @note Will post a @c kNotificationFeedIconUpdated notification if icon was updated.
 
 @param overwrite If @c YES and icon is present already, @c block will return immediatelly.
 */
+ (void)backgroundUpdateFavicon:(Feed*)feed replaceExisting:(BOOL)overwrite finally:(nullable os_block_t)block {
	if (!overwrite && feed.icon != nil) {
		if (block) block();
		return; // skip existing icons if replace == NO
	}
	NSManagedObjectID *oid = feed.objectID;
	NSManagedObjectContext *moc = feed.managedObjectContext;
	NSString *faviconURL = (feed.link.length > 0 ? feed.link : feed.meta.url);
	[self downloadFavicon:faviconURL finished:^(NSImage *img) {
		Feed *f = [moc objectWithID:oid];
		if (f && [f setIconImage:img]) {
			[StoreCoordinator saveContext:moc andParent:YES];
			PostNotification(kNotificationFeedIconUpdated, oid);
		}
		if (block) block();
	}];
}

/// Download favicon located at http://.../ @c favicon.ico. Callback @c block will be called on main thread.
+ (void)downloadFavicon:(NSString*)urlStr finished:(void(^)(NSImage * _Nullable img))block {
	NSURL *host = [self hostURL:urlStr];
	NSString *hostURL = host.absoluteString;
	NSString *favURL = [host URLByAppendingPathComponent:@"favicon.ico"].absoluteString;
	[self downloadImage:favURL finished:^(NSImage * _Nullable img) {
		if (img) {
			block(img); // is on main already (from downloadImage:)
		} else {
			[self downloadFaviconByParsingHTML:hostURL finished:block];
		}
	}];
}

/// Download html page and parse all icon urls. Starting a successive request on the favicon url.
+ (void)downloadFaviconByParsingHTML:(NSString*)hostURL finished:(void(^)(NSImage * _Nullable img))block {
	[self asyncRequest:[self newRequestURL:hostURL] block:^(NSData * _Nullable htmlData, NSError * _Nullable error, NSHTTPURLResponse *response) {
		if (htmlData) {
			// TODO: use session delegate to stop downloading after <head>
			RSXMLData *xml = [[RSXMLData alloc] initWithData:htmlData url:response.URL];
			RSHTMLMetadataParser *parser = [RSHTMLMetadataParser parserWithXMLData:xml];
			RSHTMLMetadata *meta = [parser parseSync:&error];
			if (error) meta = nil;
			NSString *iconURL = [self faviconUrlForMetadata:meta];
			if (iconURL) {
				// if everything went well we can finally start a request on the url we found.
				[self downloadImage:iconURL finished:block];
				return;
			}
		}
		dispatch_async(dispatch_get_main_queue(), ^{ block(nil); }); // on failure
	}];
}

/// Extract favicon URL from parsed HTML metadata.
+ (nullable NSString*)faviconUrlForMetadata:(RSHTMLMetadata*)meta {
	if (meta) {
		if (meta.faviconLink.length > 0) {
			return meta.faviconLink;
		}
		else if (meta.iconLinks.count > 0) {
			// at least any url (even if all items in list have size 0)
			NSString *iconURL = meta.iconLinks.firstObject.link;
			double best = DBL_MAX;
			for (RSHTMLMetadataIconLink *icon in meta.iconLinks) {
				CGSize size = [icon getSize];
				CGFloat area = size.width * size.height;
				if (area > 0) {
					// find icon with closest matching size 32x32
					double match = fabs(log10(area) - log10(32*32));
					if (match < best) {
						best = match;
						iconURL = icon.link;
					}
				}
			}
			if (iconURL && iconURL.length > 0)
				return iconURL;
		}
	}
	return nil;
}

/// Download image in a background thread and notify once finished.
+ (void)downloadImage:(NSString*)url finished:(void(^)(NSImage * _Nullable img))block {
	[self asyncRequest:[self newRequestURL:url] block:^(NSData * _Nullable data, NSError * _Nullable e, NSHTTPURLResponse *r) {
		NSImage *img = [[NSImage alloc] initWithData:data];
		if (!img || ![img isValid])
			img = nil;
//		if (img.size.width > 16 || img.size.height > 16) {
//			NSImage *smallImage = [NSImage imageWithSize:NSMakeSize(16, 16) flipped:NO drawingHandler:^BOOL(NSRect dstRect) {
//				[img drawInRect:dstRect];
//				return YES;
//			}];
//			if (img.TIFFRepresentation.length > smallImage.TIFFRepresentation.length)
//				img = smallImage;
//		}
		dispatch_async(dispatch_get_main_queue(), ^{ block(img); });
	}];
}

@end
