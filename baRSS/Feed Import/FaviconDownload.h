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
+ (nullable NSString*)urlForMetadata:(nullable RSHTMLMetadata*)meta;
@end


@protocol FaviconDownloadDelegate <NSObject>
@required
/// Called after image download. Called on error, but not if download is cancled.
- (void)faviconDownload:(FaviconDownload*)sender didFinish:(nullable NSURL*)path;
@end

NS_ASSUME_NONNULL_END
