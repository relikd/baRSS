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

@import RSXML2;
#import "FaviconDownload.h"
#import "Feed+Ext.h"
#import "FeedMeta+Ext.h"
#import "NSURL+Ext.h"
#import "NSURLRequest+Ext.h"

@interface FaviconDownload()
@property (nonatomic, weak) id<FaviconDownloadDelegate> delegate;
@property (nonatomic, strong) FaviconDownloadBlock block;
@property (nonatomic, weak) NSURLSessionTask *currentDownload;
@property (nonatomic, assign) BOOL canceled;

@property (nonatomic, assign) BOOL assertIsImageURL; // prohibit processing of HTML data
@property (nonatomic, strong) NSURL *remoteURL; // remote absolute path
@property (nonatomic, strong) NSURL *hostURL; // remote base domain
@property (nonatomic, strong) NSURL *fileURL; // local location
@end

@implementation FaviconDownload

//  ---------------------------------------------------------------
// |  MARK: - Class methods
//  ---------------------------------------------------------------

/**
 Start favicon download request on existing @c Feed object.
 @note Will post a @c kNotificationFeedIconUpdated notification on success.
 */
+ (instancetype)updateFeed:(Feed*)feed finally:(nullable os_block_t)block {
	NSString *url = feed.link;
	if (!url) url = feed.meta.url;
	NSManagedObjectContext *moc = feed.managedObjectContext;
	NSManagedObjectID *oid = feed.objectID;
	return [[self withURL:url isImageURL:NO] startWithBlock:^(NSImage * _Nullable img, NSURL * _Nullable path) {
		if (path) [(Feed*)[moc objectWithID:oid] setNewIcon:path];
		if (block) block();
	}];
}

/**
 Instantiate new loader from URL.
 @param flag If @c YES skip parsing of html.
 */
+ (instancetype)withURL:(nonnull NSString*)urlStr isImageURL:(BOOL)flag {
	FaviconDownload *this = [super new];
	this.remoteURL = [NSURL URLWithString:urlStr];
	this.assertIsImageURL = flag;
	return this;
}

//  ---------------------------------------------------------------
// |  MARK: - Actions
//  ---------------------------------------------------------------

/// Start download request and notify @c oberserver during the various steps.
- (instancetype)startWithDelegate:(id<FaviconDownloadDelegate>)observer {
	self.delegate = observer;
	[self performSelectorInBackground:@selector(start) withObject:nil];
	return self;
}

/// Start download request and notify @c block once finished.
- (instancetype)startWithBlock:(nonnull FaviconDownloadBlock)block {
	self.block = block;
	[self performSelectorInBackground:@selector(start) withObject:nil];
	return self;
}

/// Cancel running download task immediately. Will notify neither @c delegate nor @c block
- (void)cancel {
	self.canceled = YES;
	self.delegate = nil;
	self.block = nil;
	[self.currentDownload cancel];
}

/// Called for both; delegate and block observer.
- (void)start {
	if (self.canceled)
		return;
	// Base URL part. E.g., https://stackoverflow.com/a/15897956/10616114 ==> https://stackoverflow.com/
	self.hostURL = [[NSURL URLWithString:@"/" relativeToURL:self.remoteURL] absoluteURL];
	self.assertIsImageURL ? [self continueWithImageDownload] : [self continueWithHTMLDownload];
}

/// Start request on HTML metadata and try parsing it. Will update @c remoteURL (@c nil on error)
- (void)continueWithHTMLDownload {
	if (self.canceled)
		return;
	self.remoteURL = nil;
	self.currentDownload = [[NSURLRequest requestWithURL:self.hostURL] dataTask:^(NSData * _Nullable htmlData, NSError * _Nullable error, NSHTTPURLResponse *response) {
		if (self.canceled)
			return;
		if (htmlData) {
			// TODO: use session delegate to stop download after <head>
			RSXMLData *xml = [[RSXMLData alloc] initWithData:htmlData url:response.URL];
			RSHTMLMetadataParser *parser = [RSHTMLMetadataParser parserWithXMLData:xml];
			RSHTMLMetadata *meta = [parser parseSync:&error];
			if (error) meta = nil;
			NSString *u = [FaviconDownload urlForMetadata:meta];
			if (u) self.remoteURL = [NSURL URLWithString:u];
		}
		[self continueWithImageDownload];
	}];
}

/// Choose action based on whether @c .remoteURL is set.
- (void)continueWithImageDownload {
	if (self.canceled)
		return;
	self.remoteURL ? [self loadImageFromRemoteURL] : [self loadImageFromDefaultLocation];
}

/// Download image from default location @c /favicon.ico
- (void)loadImageFromDefaultLocation {
	self.remoteURL = [self.hostURL URLByAppendingPathComponent:@"favicon.ico"];
	self.hostURL = nil; // prevent recursion in loadImageFromRemoteURL
	[self loadImageFromRemoteURL];
}

/// Start download of favicon whether from already parsed favicon URL or default location.
- (void)loadImageFromRemoteURL {
	if (self.canceled)
		return;
	self.currentDownload = [[NSURLRequest requestWithURL:self.remoteURL] downloadTask:^(NSURL * _Nullable path, NSError * _Nullable error) {
		if (error) path = nil; // will also nullify img
		NSImage *img = path ? [[NSImage alloc] initByReferencingURL:path] : nil;
		if (img.valid) {
			// move image to temporary destination, otherwise dataTask: will delete it.
			NSString *tmpFile = NSProcessInfo.processInfo.globallyUniqueString;
			self.fileURL = [[path URLByDeletingLastPathComponent] file:tmpFile ext:nil];
			[path moveTo:self.fileURL];
		} else if (self.hostURL) {
			[self loadImageFromDefaultLocation]; // starts a new request
			return;
		}
		[self finishAndNotify];
	}];
}

/// Called after trying all favicon URLs. May be @c nil if none of the URLs were successful.
- (void)finishAndNotify {
	if (self.canceled)
		return;
	NSURL *path = self.fileURL;
	NSImage *img = [[NSImage alloc] initByReferencingURL:path];
	if (!img.valid) { path = nil; img = nil; }
#if DEBUG && ENV_LOG_DOWNLOAD
	printf("ICON %1.0fx%1.0f %s\n", img.size.width, img.size.height, self.remoteURL.absoluteString.UTF8String);
	printf(" ↳ %s\n", path.absoluteString.UTF8String);
#endif
	dispatch_async(dispatch_get_main_queue(), ^{
		[self.delegate faviconDownload:self didFinish:path];
		if (self.block) { self.block(img, path); self.block = nil; }
	});
}

//  ---------------------------------------------------------------
// |  MARK: - Extract from HTML metadata
//  ---------------------------------------------------------------

/// Extract favicon URL from parsed HTML metadata.
+ (nullable NSString*)urlForMetadata:(RSHTMLMetadata*)meta {
	if (!meta) return nil;
	
	double bestScore = DBL_MAX;
	NSString *iconURL = nil;
	if (meta.faviconLink.length > 0) {
		bestScore = ScoreIcon(nil);
		iconURL = meta.faviconLink; // Replaced below if size is between 18 and 56
	}
	if (meta.iconLinks.count > 0) {
		for (RSHTMLMetadataIconLink *icon in meta.iconLinks) {
			double currentScore = ScoreIcon(icon);
			if (currentScore < bestScore) {
				bestScore = currentScore;
				iconURL = icon.link;
			}
		}
		if (!iconURL) // return first, even if all items in list have size 0
			return meta.iconLinks.firstObject.link;
	}
	return iconURL;
}

/// Find icon with closest matching size 32x32 (lower score means better match)
static double ScoreIcon(RSHTMLMetadataIconLink *icon) {
	if ([icon.sizes isEqualToString:@"any"])
		return DBL_MAX; // exclude svg
	CGSize size = [icon getSize];
	double area = size.width * size.height;
	if (area <= 0) {
		if ([icon.title hasPrefix:@"apple-touch-icon"])
			area = 180 * 180; // https://webhint.io/docs/user-guide/hints/hint-apple-touch-icons/
		else
			area = 18 * 18; // Size could be 16, 32, or 48. Assuming its better than 16px.
	}
	double match = log10(area) - log10(32 * 32);
	return fabs(match) + (match < 0 ? 1e-5 : 0); // slightly prefer larger icons (64px over 16px)
}

@end
