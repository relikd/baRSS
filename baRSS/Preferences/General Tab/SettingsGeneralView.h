@import Cocoa;
@class SettingsGeneral;

NS_ASSUME_NONNULL_BEGIN

@interface SettingsGeneralView : NSView
@property (strong) IBOutlet NSTextField *defaultReader;
@property (strong) IBOutlet NSPopUpButton* popupHttpApplication;
@property (strong) IBOutlet NSPopUpButton* popupNotificationType;

- (instancetype)initWithController:(SettingsGeneral*)controller NS_DESIGNATED_INITIALIZER;
- (instancetype)initWithFrame:(NSRect)frameRect NS_UNAVAILABLE;
- (nullable instancetype)initWithCoder:(NSCoder *)decoder NS_UNAVAILABLE;
@end

NS_ASSUME_NONNULL_END
