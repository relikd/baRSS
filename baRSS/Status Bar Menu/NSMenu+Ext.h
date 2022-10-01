@import Cocoa;
@class FeedGroup, MapUnreadTotal;

NS_ASSUME_NONNULL_BEGIN

@interface NSMenu (Ext)
@property (nonnull, copy, readonly) NSString *titleIndexPath;
@property (nullable, readonly) NSMenuItem* parentItem;
@property (readonly) BOOL isMainMenu;
@property (readonly) BOOL isFeedMenu;

// Generator
- (nullable NSMenuItem*)insertFeedGroupItem:(FeedGroup*)fg withUnread:(MapUnreadTotal*)unreadMap;
- (void)insertDefaultHeader;
// Update menu
- (void)setHeaderHasUnread:(BOOL)hasUnread hasRead:(BOOL)hasRead;
- (nullable NSMenuItem*)deepestItemWithPath:(nonnull NSString*)path;
@end


@interface NSMenuItem (Ext)
- (instancetype)alternateWithTitle:(NSString*)title;
- (void)setTitleCount:(NSUInteger)count;
@end

NS_ASSUME_NONNULL_END
