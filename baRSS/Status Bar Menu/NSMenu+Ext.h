@import Cocoa;
@class FeedGroup, MapUnreadTotal, UnreadTotal;

NS_ASSUME_NONNULL_BEGIN

@interface NSMenu (Ext)
@property (nonnull, copy, readonly) NSString *titleIndexPath;
@property (nullable, readonly) NSMenuItem* parentItem;
@property (readonly) BOOL isFeedMenu;

// Generator
- (nullable NSMenuItem*)insertFeedGroupItem:(FeedGroup*)fg withUnread:(MapUnreadTotal*)unreadMap showHidden:(BOOL)showHidden;
- (void)insertDefaultHeader;
// Update menu
- (void)setHeaderHasUnread:(UnreadTotal*)count;
- (void)recursiveSetNetworkAvailable:(BOOL)flag;
- (nullable NSMenuItem*)deepestItemWithPath:(nonnull NSString*)path;
@end


@interface NSMenuItem (Ext)
- (instancetype)alternateWithTitle:(NSString*)title;
- (void)setTitleCount:(NSUInteger)count;
@end

NS_ASSUME_NONNULL_END
