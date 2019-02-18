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
#import "Constants.h"
#import "StoreCoordinator.h"
#import "Feed+Ext.h"
#import "FeedMeta+Ext.h"
#import "FeedGroup+Ext.h"

#import <SystemConfiguration/SystemConfiguration.h>

static NSTimer *_timer;
static SCNetworkReachabilityRef _reachability = NULL;
static BOOL _isReachable = NO;
static BOOL _isUpdating = NO;
static BOOL _updatePaused = NO;
static BOOL _nextUpdateIsForced = NO;


@implementation FeedDownload


#pragma mark - User Interaction -

/// @return Date when background update will fire. If updates are paused, date is @c distantFuture.
+ (NSDate *)dateScheduled { return _timer.fireDate; }

/// @return @c YES if current network state is reachable and updates are not paused by user.
+ (BOOL)allowNetworkConnection { return (_isReachable && !_updatePaused); }

/// @return @c YES if batch update is running
+ (BOOL)isUpdating { return _isUpdating; }

/// @return @c YES if update is paused by user.
+ (BOOL)isPaused { return _updatePaused; }

/// Set paused flag and cancel timer regardless of network connectivity.
+ (void)setPaused:(BOOL)flag {
	_updatePaused = flag;
	if (_updatePaused)
		[self pauseUpdates];
	else
		[self resumeUpdates];
}

/// Cancel current timer and stop any updates until enabled again.
+ (void)pauseUpdates {
	[self scheduleTimer:nil];
}

/// Start normal (non forced) schedule if network is reachable.
+ (void)resumeUpdates {
	if (_isReachable)
		[self scheduleUpdateForUpcomingFeeds];
}


#pragma mark - Update Feed Timer -


/**
 Get date of next up feed and start the timer.
 */
+ (void)scheduleUpdateForUpcomingFeeds {
	if (![self allowNetworkConnection]) // timer will restart once connection exists
		return;
	NSDate *nextTime = [StoreCoordinator nextScheduledUpdate]; // if nextTime = nil, then no feeds to update
	if (nextTime && [nextTime timeIntervalSinceNow] < 1) { // mostly, if app was closed for a long time
		nextTime = [NSDate dateWithTimeIntervalSinceNow:1];
	}
	[self scheduleTimer:nextTime];
}

/**
 Start download of all feeds (immediatelly) regardless of @c .scheduled property.
 */
+ (void)forceUpdateAllFeeds {
	if (![self allowNetworkConnection]) // timer will restart once connection exists
		return;
	_nextUpdateIsForced = YES;
	[self scheduleTimer:[NSDate dateWithTimeIntervalSinceNow:0.05]];
}

/**
 Set new @c .fireDate and @c .tolerance for update timer.

 @param nextTime If @c nil timer will be disabled with a @c .fireDate very far in the future.
 */
+ (void)scheduleTimer:(NSDate*)nextTime {
	static dispatch_once_t onceToken;
	dispatch_once(&onceToken, ^{
		_timer = [NSTimer timerWithTimeInterval:NSTimeIntervalSince1970 target:[self class] selector:@selector(updateTimerCallback) userInfo:nil repeats:YES];
		[[NSRunLoop mainRunLoop] addTimer:_timer forMode:NSRunLoopCommonModes];
	});
	if (!nextTime)
		nextTime = [NSDate distantFuture];
	NSTimeInterval tolerance = [nextTime timeIntervalSinceNow] * 0.15;
	_timer.tolerance = (tolerance < 1 ? 1 : tolerance); // at least 1 sec
	_timer.fireDate = nextTime;
}

/**
 Called when schedule timer runs out (earliest @c .schedule date). Or if forced by user request.
 */
+ (void)updateTimerCallback {
	NSLog(@"fired");
	BOOL updateAll = _nextUpdateIsForced;
	_nextUpdateIsForced = NO;
	
	NSManagedObjectContext *moc = [StoreCoordinator createChildContext];
	NSArray<Feed*> *list = [StoreCoordinator getListOfFeedsThatNeedUpdate:updateAll inContext:moc];
	//NSAssert(list.count > 0, @"ERROR: Something went wrong, timer fired too early.");
	if (![self allowNetworkConnection]) {
		[moc reset];
		return;
	}
	[self batchDownloadFeeds:list favicons:updateAll showErrorAlert:NO finally:^{
		[StoreCoordinator saveContext:moc andParent:YES]; // save parents too ...
		[moc reset];
		[self resumeUpdates]; // always reset the timer
	}];
}


#pragma mark - Request Generator -


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
	if (!_nextUpdateIsForced) // any request that is not forced, is a background update
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
		if (error || [httpResponse statusCode] == 304)
			data = nil;
		block(data, error, httpResponse); // if status == 304, data & error nil
	}] resume];
}


#pragma mark - Download RSS Feed -


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
			RSXMLData *xml = [[RSXMLData alloc] initWithData:data urlString:response.URL.absoluteString];
			if (xmlBlock && xmlBlock(xml, &error)) {
				return;
			}
			if (!error) { // metaBlock may set error
				RSFeedParser *parser = [RSFeedParser parserWithXMLData:xml];
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
			*err = RSXMLMakeErrorWrongParser(RSXMLErrorExpectingFeed, RSXMLErrorExpectingHTML);
			return NO;
		}
		__block NSString *chosenURL = nil;
		dispatch_sync(dispatch_get_main_queue(), ^{ // sync! (thread is already in background)
			chosenURL = askUser(parsedMeta);
		});
		if (!chosenURL || chosenURL.length == 0)
			return NO;
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
		[StoreCoordinator saveContext:moc andParent:NO];
		if (needsNotification)
			[[NSNotificationCenter defaultCenter] postNotificationName:kNotificationFeedUpdated object:oid];
		if (block) block(success);
	}];
}

/**
 Download feed at url and append to persistent store in root folder.
 On error present user modal alert.
 
 Creates new @c FeedGroup, @c Feed, @c FeedMeta and @c FeedArticle instances and saves them to the persistent store.
 Update duration is set to the default of 30 minutes.
 */
+ (void)autoDownloadAndParseURL:(NSString*)url successBlock:(nullable os_block_t)block {
	NSManagedObjectContext *moc = [StoreCoordinator createChildContext];
	Feed *f = [Feed appendToRootWithDefaultIntervalInContext:moc];
	f.meta.url = url;
	[self backgroundUpdateBoth:f favicon:YES alert:YES finally:^(BOOL successful){
		if (!successful) {
			[moc deleteObject:f.group];
		}
		[StoreCoordinator saveContext:moc andParent:YES];
		[moc reset];
		if (successful) {
			[self scheduleUpdateForUpcomingFeeds];
			if (block) block();
		}
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
	_isUpdating = YES;
	[[NSNotificationCenter defaultCenter] postNotificationName:kNotificationBackgroundUpdateInProgress object:@(list.count)];
	dispatch_group_t group = dispatch_group_create();
	for (Feed *f in list) {
		dispatch_group_enter(group);
		[self backgroundUpdateBoth:f favicon:fav alert:alert finally:^(BOOL success){
			dispatch_group_leave(group);
		}];
	}
	dispatch_group_notify(group, dispatch_get_main_queue(), ^{
		if (block) block();
		_isUpdating = NO;
		[[NSNotificationCenter defaultCenter] postNotificationName:kNotificationBackgroundUpdateInProgress object:@(0)];
	});
}


#pragma mark - Download Favicon -


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
			[StoreCoordinator saveContext:moc andParent:NO];
			[[NSNotificationCenter defaultCenter] postNotificationName:kNotificationFeedIconUpdated object:oid];
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

/// Download html page and parse all icon urls. Starting a successive request on the url of the smallest icon.
+ (void)downloadFaviconByParsingHTML:(NSString*)hostURL finished:(void(^)(NSImage * _Nullable img))block {
	[self asyncRequest:[self newRequestURL:hostURL] block:^(NSData * _Nullable htmlData, NSError * _Nullable error, NSHTTPURLResponse *response) {
		if (htmlData) {
			// TODO: use session delegate to stop downloading after <head>
			RSXMLData *xml = [[RSXMLData alloc] initWithData:htmlData urlString:hostURL];
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
			// we dont need much, lets find the smallest icon ...
			int smallest = 9001;
			for (RSHTMLMetadataIconLink *icon in meta.iconLinks) {
				int size = (int)[icon getSize].width;
				if (size > 0 && size < smallest) {
					smallest = size;
					iconURL = icon.link;
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


#pragma mark - Network Connection & Reachability -


/// Set callback on @c self to listen for network reachability changes.
+ (void)registerNetworkChangeNotification {
	// https://stackoverflow.com/questions/11240196/notification-when-wifi-connected-os-x
	if (_reachability != NULL) return;
	_reachability = SCNetworkReachabilityCreateWithName(NULL, "1.1.1.1");
	if (_reachability == NULL) return;
	// If reachability information is available now, we don't get a callback later
	SCNetworkConnectionFlags flags;
	if (SCNetworkReachabilityGetFlags(_reachability, &flags))
		networkReachabilityCallback(_reachability, flags, NULL);
	if (!SCNetworkReachabilitySetCallback(_reachability, networkReachabilityCallback, NULL) ||
		!SCNetworkReachabilityScheduleWithRunLoop(_reachability, [[NSRunLoop currentRunLoop] getCFRunLoop], kCFRunLoopCommonModes))
	{
		CFRelease(_reachability);
		_reachability = NULL;
	}
}

/// Remove @c self callback (network reachability changes).
+ (void)unregisterNetworkChangeNotification {
	if (_reachability != NULL) {
		SCNetworkReachabilitySetCallback(_reachability, nil, nil);
		SCNetworkReachabilitySetDispatchQueue(_reachability, nil);
		CFRelease(_reachability);
		_reachability = NULL;
	}
}

/// Called when network interface or reachability changes.
static void networkReachabilityCallback(SCNetworkReachabilityRef target, SCNetworkConnectionFlags flags, void *object) {
	if (_reachability == NULL) return;
	_isReachable = [FeedDownload hasConnectivity:flags];
	[[NSNotificationCenter defaultCenter] postNotificationName:kNotificationNetworkStatusChanged object:@(_isReachable)];
	if (_isReachable) {
		[FeedDownload resumeUpdates];
	} else {
		[FeedDownload pauseUpdates];
	}
}

/// @return @c YES if network connection established.
+ (BOOL)hasConnectivity:(SCNetworkReachabilityFlags)flags {
	if ((flags & kSCNetworkReachabilityFlagsReachable) == 0)
		return NO;
	if ((flags & kSCNetworkReachabilityFlagsConnectionRequired) == 0)
		return YES;
	if ((flags & kSCNetworkReachabilityFlagsInterventionRequired) == 0 &&
		((flags & kSCNetworkReachabilityFlagsConnectionOnDemand) != 0 ||
		 (flags & kSCNetworkReachabilityFlagsConnectionOnTraffic) != 0))
		return YES; // no-intervention AND ( on-demand OR on-traffic )
	return NO;
}

@end