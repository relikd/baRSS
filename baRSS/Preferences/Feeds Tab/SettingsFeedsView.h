@import Cocoa;
@class SettingsFeeds;

NS_ASSUME_NONNULL_BEGIN

@interface SettingsFeedsView : NSView
@property (strong) IBOutlet NSOutlineView *outline;
@property (strong) IBOutlet NSTextField *status;
@property (strong) IBOutlet NSProgressIndicator *spinner;

- (instancetype)initWithController:(SettingsFeeds*)delegate NS_DESIGNATED_INITIALIZER;
- (instancetype)initWithFrame:(NSRect)frameRect NS_UNAVAILABLE;
- (nullable instancetype)initWithCoder:(NSCoder *)decoder NS_UNAVAILABLE;
@end


@interface NameColumnCell : NSTableCellView
extern NSUserInterfaceItemIdentifier const CustomCellName;
@end

@interface RefreshColumnCell : NSTableCellView
extern NSUserInterfaceItemIdentifier const CustomCellRefresh;
@end

@interface SeparatorColumnCell : NSTableCellView
extern NSUserInterfaceItemIdentifier const CustomCellSeparator;
@end

NS_ASSUME_NONNULL_END
