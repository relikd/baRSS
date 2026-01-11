@import Cocoa;
#import "DBv1+CoreDataModel.h"

NS_ASSUME_NONNULL_BEGIN

@interface StoreCoordinator : NSObject
// Managing contexts
+ (NSManagedObjectContext*)getMainContext;
+ (NSManagedObjectContext*)createChildContext;
+ (void)saveContext:(NSManagedObjectContext*)context andParent:(BOOL)flag;

// Options
+ (nullable NSString*)optionForKey:(NSString*)key;
+ (void)setOption:(NSString*)key value:(NSString*)value;

// Feed update
+ (NSDate*)nextScheduledUpdate;
+ (NSArray<Feed*>*)feedsThatNeedUpdate:(nullable NSManagedObjectContext*)moc;
+ (NSArray<Feed*>*)feedsWithIndexPath:(nullable NSString*)path inContext:(nullable NSManagedObjectContext*)moc;

// Count elements
+ (BOOL)isEmpty;
+ (NSUInteger)countTotalUnread;
+ (NSUInteger)countRootItemsInContext:(NSManagedObjectContext*)moc;
+ (NSArray<NSDictionary*>*)countAggregatedUnread;

// Get List Of Elements
+ (NSArray<FeedGroup*>*)sortedFeedGroupsWithParent:(nullable id)parent inContext:(nullable NSManagedObjectContext*)moc;
+ (Feed*)feedWithIndexPath:(nonnull NSString*)path inContext:(nullable NSManagedObjectContext*)moc;
+ (NSString*)urlForFeedWithIndexPath:(nonnull NSString*)path;

// Unread articles list & mark articled read
+ (NSArray<FeedArticle*>*)articlesAtPath:(nullable NSString*)path isFeed:(BOOL)feedFlag sorted:(BOOL)sortFlag unread:(BOOL)readFlag inContext:(NSManagedObjectContext*)moc limit:(NSUInteger)limit;
+ (nullable NSArray<NSString*>*)updateArticles:(NSArray<FeedArticle*>*)list markRead:(BOOL)markRead andOpen:(BOOL)openLinks inContext:(NSManagedObjectContext*)moc;

// Restore sound state
+ (void)cleanupAndShowAlert:(BOOL)flag;
+ (NSUInteger)cleanupFavicons;
@end

NS_ASSUME_NONNULL_END
