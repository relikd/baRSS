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

@import Cocoa;
@class Feed, RSHTMLMetadata, FeedDownload;
@protocol FaviconDownloadDelegate;

NS_ASSUME_NONNULL_BEGIN

@interface FaviconDownload : NSObject
/// @c img and @c path are @c nil if image is not valid or couldn't be downloaded.
typedef void(^FaviconDownloadBlock)(NSImage * _Nullable img, NSURL * _Nullable path);

// Instantiation methods
+ (instancetype)withURL:(nonnull NSString*)urlStr isImageURL:(BOOL)flag;
+ (instancetype)updateFeed:(Feed*)feed finally:(nullable os_block_t)block;
// Actions
- (instancetype)startWithDelegate:(id<FaviconDownloadDelegate>)observer;
- (instancetype)startWithBlock:(nonnull FaviconDownloadBlock)block;
- (void)cancel;
// Extract from HTML metadata
+ (nullable NSString*)urlForMetadata:(RSHTMLMetadata*)meta;
@end


@protocol FaviconDownloadDelegate <NSObject>
@required
/// Called after image download. Called on error, but not if download is cancled.
- (void)faviconDownload:(FaviconDownload*)sender didFinish:(nullable NSURL*)path;
@end

NS_ASSUME_NONNULL_END
