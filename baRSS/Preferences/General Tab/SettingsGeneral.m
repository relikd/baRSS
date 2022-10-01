#import "SettingsGeneral.h"
#import "UserPrefs.h"
#import "StoreCoordinator.h"
#import "Constants.h"
#import "SettingsGeneralView.h"

@interface SettingsGeneral()
@property (strong) IBOutlet SettingsGeneralView *view; // override
@end

@implementation SettingsGeneral
@dynamic view;

- (void)loadView {
	self.view = [[SettingsGeneralView alloc] initWithController:self];
	// Default http application for opening the feed urls
	NSPopUpButton *pop = self.view.popupHttpApplication;
	[pop removeAllItems];
	[pop addItemWithTitle:NSLocalizedString(@"System Default", @"Default web browser application")];
	NSArray<NSString*> *browsers = CFBridgingRelease(LSCopyAllHandlersForURLScheme(CFSTR("https")));
	for (NSString *bundleID in browsers) {
		[pop addItemWithTitle: [self applicationNameForBundleId:bundleID]];
		pop.lastItem.representedObject = bundleID;
	}
	[pop selectItemAtIndex:[pop indexOfItemWithRepresentedObject:UserPrefsString(Pref_defaultHttpApplication)]];
	// Default RSS Reader application
	NSString *feedBundleId = CFBridgingRelease(LSCopyDefaultHandlerForURLScheme(CFSTR("feed")));
	self.view.defaultReader.objectValue = [self applicationNameForBundleId:feedBundleId];
}

/// Get human readable application name such as 'Safari' or 'baRSS'
- (nonnull NSString*)applicationNameForBundleId:(nonnull NSString*)bundleID {
	NSString *name;
	NSArray<NSURL*> *urls = CFBridgingRelease(LSCopyApplicationURLsForBundleIdentifier((__bridge CFStringRef)bundleID, NULL));
	if (urls.count > 0) {
		NSDictionary *info = CFBridgingRelease(CFBundleCopyInfoDictionaryForURL((CFURLRef)urls.firstObject));
		name = info[(NSString*)kCFBundleExecutableKey];
	}
	return name ? name : bundleID;
}

#pragma mark - User interaction

// Callback method fired when user selects a different item from popup list
- (void)changeHttpApplication:(NSPopUpButton *)sender {
	UserPrefsSet(Pref_defaultHttpApplication, sender.selectedItem.representedObject);
}

// Callback method from round help button right of default feed reader text
- (void)clickHowToDefaults:(NSButton *)sender {
	NSAlert *alert = [[NSAlert alloc] init];
	alert.alertStyle = NSAlertStyleInformational;
	alert.messageText = NSLocalizedString(@"How to change default feed reader", nil);
	alert.informativeText = NSLocalizedString(@"Unfortunately sandboxed applications are not allowed to change the default application. However, there is an auxiliary application.\n\nFollow the instructions to change the 'feed:' scheme.", nil);
	[alert addButtonWithTitle:NSLocalizedString(@"Close", nil)];
	[alert addButtonWithTitle:NSLocalizedString(@"Go to download page", nil)].toolTip = auxiliaryAppURL;
	[alert beginSheetModalForWindow:self.view.window completionHandler:^(NSModalResponse returnCode) {
		if (returnCode == NSAlertSecondButtonReturn) {
			[[NSWorkspace sharedWorkspace] openURL:[NSURL URLWithString:auxiliaryAppURL]];
		}
	}];
}

// x-apple.systempreferences:com.apple.preferences.users?startupItemsPref

@end
