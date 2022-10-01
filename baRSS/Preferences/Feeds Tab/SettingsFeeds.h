@import Cocoa;

NS_ASSUME_NONNULL_BEGIN

/** Manages the NSOutlineView and Feed creation and editing */
@interface SettingsFeeds : NSViewController <NSOutlineViewDelegate>
@property (strong) NSTreeController *dataStore;
@property (strong, nullable) NSArray<NSTreeNode*> *currentlyDraggedNodes;

- (void)editSelectedItem;
- (void)doubleClickOutlineView:(NSOutlineView*)sender;
- (void)addFeed;
- (void)addGroup;
- (void)addSeparator;
- (void)remove:(id)sender;
- (void)openImportDialog;
- (void)openExportDialog;

- (void)beginCoreDataChange;
- (BOOL)endCoreDataChangeUndoEmpty:(BOOL)undoEmpty forceUndo:(BOOL)force;
- (void)restoreOrderingAndIndexPathStr:(NSArray<NSTreeNode*>*)parentsList;
@end

NS_ASSUME_NONNULL_END
