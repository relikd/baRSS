#import "SettingsGeneral.h"
#import "UserPrefs.h"
#import "StoreCoordinator.h"
#import "Constants.h"
#import "SettingsGeneralView.h"
#import "NotifyEndpoint.h"

@interface SettingsGeneral()
@property (strong) IBOutlet SettingsGeneralView *view; // override
@end

@implementation SettingsGeneral
@dynamic view;

- (void)loadView {
	self.view = [[SettingsGeneralView alloc] initWithController:self];
	
	// Default RSS Reader application
	NSString *feedBundleId = CFBridgingRelease(LSCopyDefaultHandlerForURLScheme(CFSTR("feed")));
	self.view.defaultReader.objectValue = [self applicationNameForBundleId:feedBundleId];
	
	// Default http application for opening the feed urls
	NSPopUpButton *defaultApp = self.view.popupHttpApplication;
	[defaultApp removeAllItems];
	[defaultApp addItemWithTitle:NSLocalizedString(@"System Default", @"Default web browser application")];
	NSArray<NSString*> *browsers = CFBridgingRelease(LSCopyAllHandlersForURLScheme(CFSTR("https")));
	for (NSString *bundleID in browsers) {
		[defaultApp addItemWithTitle: [self applicationNameForBundleId:bundleID]];
		defaultApp.lastItem.representedObject = bundleID;
	}
	[defaultApp selectItemAtIndex:[defaultApp indexOfItemWithRepresentedObject:UserPrefsString(Pref_defaultHttpApplication)]];
	
	// Notification settings (disabled, per article, per feed, total)
	NSPopUpButton *notify = self.view.popupNotificationType;
	[notify removeAllItems];
	[notify addItemsWithTitles:@[
		NSLocalizedString(@"Disabled", @"No notifications"),
		NSLocalizedString(@"Per Article", nil),
		NSLocalizedString(@"Per Feed", nil),
		NSLocalizedString(@"Global “X unread articles”", nil),
	]];
	notify.itemArray[0].representedObject = NotificationTypeToString(NotificationTypeDisabled);
	notify.itemArray[1].representedObject = NotificationTypeToString(NotificationTypePerArticle);
	notify.itemArray[2].representedObject = NotificationTypeToString(NotificationTypePerFeed);
	notify.itemArray[3].representedObject = NotificationTypeToString(NotificationTypeGlobal);
	NotificationType savedType = UserPrefsNotificationType();
	[notify selectItemAtIndex:[notify indexOfItemWithRepresentedObject:NotificationTypeToString(savedType)]];
	self.view.notificationHelp.stringValue = [self notificationHelpString:savedType];
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

// Callback method fired when user selects a different item from popup list
- (void)changeHttpApplication:(NSPopUpButton *)sender {
	UserPrefsSet(Pref_defaultHttpApplication, sender.selectedItem.representedObject);
}

- (void)changeNotificationType:(NSPopUpButton *)sender {
	UserPrefsSet(Pref_notificationType, sender.selectedItem.representedObject);
	self.view.notificationHelp.stringValue = [self notificationHelpString:UserPrefsNotificationType()];
	if (@available(macOS 10.14, *)) {
		[NotifyEndpoint activate];
	}
}

/// Help string explaining the different notification settings (for the current configuration)
- (NSString*)notificationHelpString:(NotificationType)typ {
	switch (typ) {
		case NotificationTypeDisabled:
			return NSLocalizedString(@"Notifications are disabled. You will not get any notifications even if you enable them in System Settings.", nil);
		case NotificationTypePerArticle:
			return NSLocalizedString(@"You will get a notification for each article (“Feed Title: Article Title”). A click on the notification banner opens the article link and marks the item as read.", nil);
		case NotificationTypePerFeed:
			return NSLocalizedString(@"You will get a notification for each feed whenever one or more new articles are published (“Feed Title: X unread articles”). A click on the notification banner will open all unread articles of that feed.", nil);
		case NotificationTypeGlobal:
			return NSLocalizedString(@"You will get a single notification for all feeds combined (“baRSS: X unread articles”). A click on the notification banner will open all unread articles of all feeds.", nil);
	}
}

@end
