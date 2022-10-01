@import Cocoa;
@class BarStatusItem, Preferences;

@interface AppHook : NSApplication <NSApplicationDelegate>
@property (readonly, strong) BarStatusItem *statusItem;
@property (readonly, strong) NSPersistentContainer *persistentContainer;

- (Preferences*)openPreferences;
@end
