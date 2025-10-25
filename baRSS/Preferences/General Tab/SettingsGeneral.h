@import Cocoa;

NS_ASSUME_NONNULL_BEGIN

@interface SettingsGeneral : NSViewController
- (void)clickHowToDefaults:(NSButton *)sender;
- (void)changeHttpApplication:(NSPopUpButton *)sender;
- (void)changeNotificationType:(NSPopUpButton *)sender;
@end

NS_ASSUME_NONNULL_END
