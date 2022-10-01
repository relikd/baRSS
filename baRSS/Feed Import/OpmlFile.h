@import Cocoa;
@class FeedGroup;

typedef NS_OPTIONS(NSUInteger, OpmlFileExportOptions) {
	OpmlFileExportOptionFlattened = 1 << 1,
	OpmlFileExportOptionFullBackup = 1 << 2,
};

NS_ASSUME_NONNULL_BEGIN

#pragma mark - Protocols

@protocol OpmlFileImportDelegate <NSObject>
@required
- (NSManagedObjectContext*)opmlFileImportContext; // currently called only once
@optional
- (void)opmlFileImportWillBegin:(NSManagedObjectContext*)moc;
- (void)opmlFileImportDidEnd:(NSManagedObjectContext*)moc;
@end


@protocol OpmlFileExportDelegate <NSObject>
@required
- (NSArray<FeedGroup*>*)opmlFileExportListOfFeedGroups:(OpmlFileExportOptions)options;
@end


#pragma mark - Classes

@interface OpmlFileImport : NSObject
@property (weak) id<OpmlFileImportDelegate> delegate;
+ (instancetype)withDelegate:(id<OpmlFileImportDelegate>)delegate;
- (void)showImportDialog:(NSWindow*)window;
- (void)importFiles:(NSArray<NSURL*>*)files;
@end


@interface OpmlFileExport : NSObject
@property (weak) id<OpmlFileExportDelegate> delegate;
+ (instancetype)withDelegate:(nullable id<OpmlFileExportDelegate>)delegate;
- (void)showExportDialog:(NSWindow*)window;
- (nullable NSError*)writeOPMLFile:(NSURL*)url withOptions:(OpmlFileExportOptions)opt;
@end

NS_ASSUME_NONNULL_END
