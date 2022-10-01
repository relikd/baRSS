@import Cocoa;
@class ModalFeedEdit;

NS_ASSUME_NONNULL_BEGIN

@interface ModalFeedEditView : NSView
@property (strong) IBOutlet NSTextField *url;
@property (strong) IBOutlet NSProgressIndicator *spinnerURL;
@property (strong) IBOutlet NSImageView *favicon;

@property (strong) IBOutlet NSTextField *name;
@property (strong) IBOutlet NSProgressIndicator *spinnerName;

@property (strong) IBOutlet NSTextField *refreshNum;
@property (strong) IBOutlet NSPopUpButton *refreshUnit;

@property (strong) IBOutlet NSButton *warningButton;
@property NSPopover *warningPopover;
@property (strong) IBOutlet NSTextField *warningText;
@property (strong) IBOutlet NSButton *warningReload;

- (instancetype)initWithController:(ModalFeedEdit*)controller NS_DESIGNATED_INITIALIZER;
- (instancetype)initWithFrame:(NSRect)frameRect NS_UNAVAILABLE;
- (nullable instancetype)initWithCoder:(NSCoder *)decoder NS_UNAVAILABLE;
@end

NS_ASSUME_NONNULL_END
