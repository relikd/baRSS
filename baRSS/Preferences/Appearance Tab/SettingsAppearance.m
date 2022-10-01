#import "SettingsAppearance.h"
#import "SettingsAppearanceView.h"
#import "AppHook.h"
#import "BarStatusItem.h"
#import "UserPrefs.h"

@implementation SettingsAppearance

- (void)loadView {
	self.view = [SettingsAppearanceView new];
	for (NSButton *button in self.view.subviews) {
		if ([button isKindOfClass:[NSButton class]]) { // for all checkboxes
			[button setAction:@selector(didSelectCheckbox:)];
			[button setTarget:self];
		}
	}
}

#pragma mark - Checkbox Callback Method

/// Sync new value with UserDefaults and update status bar icon
- (void)didSelectCheckbox:(NSButton*)sender {
	NSString *pref = sender.identifier;
	UserPrefsSetBool(pref, (sender.state == NSControlStateValueOn));
	if (pref == Pref_globalUnreadCount || pref == Pref_globalTintMenuIcon) { // == because static string
		[[(AppHook*)NSApp statusItem] updateBarIcon];
	}
}

@end
