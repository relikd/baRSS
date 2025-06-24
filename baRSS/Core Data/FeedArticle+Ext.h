@import Cocoa;
#import "FeedArticle+CoreDataClass.h"
@class RSParsedArticle;

NS_ASSUME_NONNULL_BEGIN

@interface FeedArticle (Ext)
+ (instancetype)newArticle:(RSParsedArticle*)entry inContext:(NSManagedObjectContext*)moc;
- (void)updateArticleIfChanged:(RSParsedArticle*)entry;
- (NSMenuItem*)newMenuItem;
@end

NS_ASSUME_NONNULL_END
