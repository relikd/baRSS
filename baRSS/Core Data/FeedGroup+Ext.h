@import Cocoa;
#import "FeedGroup+CoreDataClass.h"

/// Enum type to distinguish different @c FeedGroup types: @c GROUP, @c FEED, @c SEPARATOR
typedef NS_ENUM(int16_t, FeedGroupType) {
	/// Other types: @c GROUP, @c FEED, @c SEPARATOR
	GROUP = 0, FEED = 1, SEPARATOR = 2
};

NS_ASSUME_NONNULL_BEGIN

@interface FeedGroup (Ext)
/// Overwrites @c type attribute with enum. Use one of: @c GROUP, @c FEED, @c SEPARATOR.
@property (nonatomic) FeedGroupType type;
@property (nonnull, readonly) NSString *anyName;
@property (nonnull, readonly) NSImage* groupIconImage16;
@property (nonnull, readonly) NSImage* iconImage16;

+ (instancetype)newGroup:(FeedGroupType)type inContext:(NSManagedObjectContext*)context;
+ (instancetype)appendToRoot:(FeedGroupType)type inContext:(NSManagedObjectContext*)moc;
- (void)setParent:(nullable FeedGroup *)parent andSortIndex:(int32_t)sortIndex;
- (void)setSortIndexIfChanged:(int32_t)sortIndex;
- (void)setNameIfChanged:(nullable NSString*)name;
- (NSMenuItem*)newMenuItem;
// Handle children and parents
- (NSString*)indexPathString;
- (nullable NSArray<FeedGroup*>*)sortedChildren;
- (NSMutableArray<FeedGroup*>*)allParents;
// Printing
- (NSString*)readableDescription;
@end

NS_ASSUME_NONNULL_END
