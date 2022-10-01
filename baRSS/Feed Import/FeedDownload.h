@import Cocoa;
@class RSParsedFeed, RSHTMLMetadataFeedLink, Feed, FaviconDownload;
@protocol FeedDownloadDelegate;

NS_ASSUME_NONNULL_BEGIN

/**
 All properties will be parsed and stored in local variables.
 This will avoid unnecessary core data operations if user decides to cancel the edit.
 */
@interface FeedDownload : NSObject
@property (readonly, nonnull) NSURLRequest *request;
@property (readonly, nullable) NSHTTPURLResponse* response;
@property (readonly, nullable) RSParsedFeed *xmlfeed;
@property (readonly, nullable) NSError *error;
@property (readonly, nullable) NSString *faviconURL;

typedef void (^FeedDownloadBlock)(FeedDownload *sender);

// Instantiation methods
+ (instancetype)withURL:(NSString*)url;
+ (instancetype)withFeed:(Feed*)feed forced:(BOOL)flag;
// Actions
- (instancetype)startWithDelegate:(id<FeedDownloadDelegate>)delegate;
- (instancetype)startWithBlock:(nonnull FeedDownloadBlock)block;
- (void)cancel;
- (BOOL)copyValuesTo:(nonnull Feed*)feed ignoreError:(BOOL)flag;
// Getter
- (FaviconDownload*)faviconDownload;
@end



/// Protocol for handling an in memory download
@protocol FeedDownloadDelegate <NSObject>
@optional
/// Delegate must return chosen URL. If not implemented, the first URL will be used.
- (NSString*)feedDownload:(FeedDownload*)sender selectFeedFromList:(NSArray<RSHTMLMetadataFeedLink*>*)list;
/// Only called if an URL redirect occured.
- (void)feedDownload:(FeedDownload*)sender urlRedirected:(NSString*)newURL;
/// Called after xml data is loaded and parsed. Called on error, but not if download is cancled.
- (void)feedDownloadDidFinish:(FeedDownload*)sender;
@end

NS_ASSUME_NONNULL_END
