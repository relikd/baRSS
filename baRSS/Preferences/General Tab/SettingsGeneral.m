//
//  The MIT License (MIT)
//  Copyright (c) 2018 Oleg Geier
//
//  Permission is hereby granted, free of charge, to any person obtaining a copy of
//  this software and associated documentation files (the "Software"), to deal in
//  the Software without restriction, including without limitation the rights to
//  use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies
//  of the Software, and to permit persons to whom the Software is furnished to do
//  so, subject to the following conditions:
//
//  The above copyright notice and this permission notice shall be included in all
//  copies or substantial portions of the Software.
//
//  THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
//  IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
//  FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
//  AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
//  LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
//  OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
//  SOFTWARE.

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
	[pop selectItemAtIndex:[pop indexOfItemWithRepresentedObject:[UserPrefs getHttpApplication]]];
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
	[UserPrefs setHttpApplication:sender.selectedItem.representedObject];
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

@end
