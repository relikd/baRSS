@import Cocoa;
#import "Feed+CoreDataClass.h"
@class RSParsedFeed;

NS_ASSUME_NONNULL_BEGIN

@interface Feed (Ext)
@property (readonly) BOOL hasIcon;
@property (nonnull, readonly) NSImage* iconImage16;

// Generator methods / Feed update
+ (instancetype)newFeedAndMetaInContext:(NSManagedObjectContext*)context;
- (NSString*)notificationID;
- (void)updateWithRSS:(RSParsedFeed*)obj postUnreadCountChange:(BOOL)flag;
- (NSMenuItem*)newMenuItem;
// Getter & Setter
- (void)calculateAndSetIndexPathString;
- (void)setNewIcon:(NSURL*)location;
// Article properties
- (nullable NSArray<FeedArticle*>*)sortedArticles;
- (NSUInteger)countUnread;
@end

NS_ASSUME_NONNULL_END
