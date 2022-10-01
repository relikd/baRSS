#import "SettingsFeeds.h"
#import "OpmlFile.h"

NS_ASSUME_NONNULL_BEGIN

@interface SettingsFeeds (DragDrop) <NSOutlineViewDataSource, NSFilePromiseProviderDelegate, NSPasteboardTypeOwner, OpmlFileImportDelegate, OpmlFileExportDelegate>
- (void)prepareOutlineViewForDragDrop:(NSOutlineView*)outline;
- (void)importOpmlFiles:(NSArray<NSURL*>*)files;
@end

NS_ASSUME_NONNULL_END
