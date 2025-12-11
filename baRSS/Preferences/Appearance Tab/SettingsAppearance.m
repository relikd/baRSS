#import "SettingsAppearance.h"
#import "SettingsAppearanceView.h"
#import "AppHook.h"
#import "BarStatusItem.h"
#import "UserPrefs.h"

@implementation SettingsAppearance

- (void)loadView {
	self.view = [SettingsAppearanceView new];
	NSScrollView *scroll = self.view.subviews[0];
	NSView *contentView = scroll.documentView.subviews[0];
	for (NSControl *control in contentView.subviews) {
		if ([control isKindOfClass:[NSButton class]]) { // for all checkboxes
			[control setAction:@selector(didSelectCheckbox:)];
			[control setTarget:self];
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
