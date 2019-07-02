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
	[self generateMenuForPopup:self.view.popupHttpApplication withScheme:@"https"];
	[self.view.popupHttpApplication insertItemWithTitle:NSLocalizedString(@"System Default", @"Default web browser application") atIndex:0];
	[self selectBundleID:[UserPrefs getHttpApplication] inPopup:self.view.popupHttpApplication];
	// Default RSS Reader application
	[self generateMenuForPopup:self.view.popupDefaultRSSReader withScheme:@"feed"];
	[self selectBundleID:[self defaultBundleIdForScheme:@"feed"] inPopup:self.view.popupDefaultRSSReader];
}

#pragma mark - UI interaction with IBAction

- (void)fixCache:(NSButton *)sender {
	NSUInteger deleted = [StoreCoordinator deleteUnreferenced];
	[StoreCoordinator restoreFeedIndexPaths];
	[[NSNotificationCenter defaultCenter] postNotificationName:kNotificationTotalUnreadCountReset object:nil];
	// show only if >0, but hey, this button will vanish anyway ...
	NSAlert *alert = [[NSAlert alloc] init];
	alert.messageText = [NSString stringWithFormat:@"Removed %lu unreferenced core data entries.", deleted];
	alert.alertStyle = NSAlertStyleInformational;
	[alert runModal];
}

- (void)changeHttpApplication:(NSPopUpButton *)sender {
	[UserPrefs setHttpApplication:sender.selectedItem.representedObject];
}

- (void)changeDefaultRSSReader:(NSPopUpButton *)sender {
	if ([self setDefaultRSSApplication:sender.selectedItem.representedObject] == NO) {
		// in case anything went wrong, restore previous selection
		[self selectBundleID:[self defaultBundleIdForScheme:@"feed"] inPopup:sender];
	}
}

#pragma mark - Helper methods

/**
 Populate @c NSPopUpButton menu with all available application for that scheme.

 @param scheme URL scheme like @c 'feed' or @c 'https'
 */
- (void)generateMenuForPopup:(NSPopUpButton*)popup withScheme:(NSString*)scheme {
	[popup removeAllItems];
	NSArray<NSString*> *apps = [self listOfBundleIdsForScheme:scheme];
	for (NSString *bundleID in apps) {
		NSString *appName = [self applicationNameForBundleId:bundleID];
		if (!appName)
			appName = bundleID;
		[popup addItemWithTitle:appName];
		popup.lastItem.representedObject = bundleID;
	}
}

/**
 For a given @c NSPopUpButton select the item which represents the @c bundleID.
 */
- (void)selectBundleID:(NSString*)bundleID inPopup:(NSPopUpButton*)popup {
	[popup selectItemAtIndex:[popup indexOfItemWithRepresentedObject:bundleID]];
}

/**
 Get human readable, application name from @c bundleID.

 @param bundleID as defined in @c Info.plist
 @return Application name such as 'Safari' or 'baRSS'
 */
- (NSString*)applicationNameForBundleId:(NSString*)bundleID {
	CFStringRef bundleIDRef = CFBridgingRetain(bundleID);
	if (!bundleIDRef)
		return nil;
	CFArrayRef arr = LSCopyApplicationURLsForBundleIdentifier(bundleIDRef, NULL);
	CFRelease(bundleIDRef);
	if (!arr)
		return nil;
	CFDictionaryRef infoDict = NULL;
	if (CFArrayGetCount(arr) > 0)
		infoDict = CFBundleCopyInfoDictionaryForURL(CFArrayGetValueAtIndex(arr, 0));
	CFRelease(arr);
	if (!infoDict)
		return nil;
	NSString *name = CFDictionaryGetValue(infoDict, kCFBundleNameKey);
	CFRelease(infoDict);
	return name;
}

/**
 Get a list of all installed applications supporting that URL scheme.

 @param scheme URL scheme like @c 'feed' or @c 'https'
 @return Array of @c bundleIDs of installed applications supporting that url scheme.
 */
- (NSArray<NSString*>*)listOfBundleIdsForScheme:(NSString*)scheme {
	CFStringRef schemeRef = CFBridgingRetain(scheme);
	if (!schemeRef)
		return nil;
	CFArrayRef allHandlers = LSCopyAllHandlersForURLScheme(schemeRef);
	CFRelease(schemeRef);
	return (NSArray*)CFBridgingRelease(allHandlers);
}

/**
 Get current default application for provided URL scheme. (e.g.,  )

 @param scheme URL scheme like @c 'feed' or @c 'https'
 @return @c bundleID of default application
 */
- (NSString*)defaultBundleIdForScheme:(NSString*)scheme {
	CFStringRef schemeRef = CFBridgingRetain(scheme);
	if (!schemeRef)
		return nil;
	CFStringRef defaultHandler = LSCopyDefaultHandlerForURLScheme(schemeRef);
	CFRelease(schemeRef);
	return (NSString*)CFBridgingRelease(defaultHandler);
}

/**
 Sets the default application for @c feed:// urls. (system wide)

 @param bundleID as defined in @c Info.plist
 @return Return @c YES if operation was successfull. @c NO otherwise.
 */
- (BOOL)setDefaultRSSApplication:(NSString*)bundleID {
	// TODO: Does not work with sandboxing.
	CFStringRef bundleIDRef = CFBridgingRetain(bundleID);
	if (!bundleIDRef)
		return NO;
	CFStringRef schemeRef = CFBridgingRetain(@"feed");
	if (!schemeRef) {
		CFRelease(bundleIDRef);
		return NO;
	}
	OSStatus s = LSSetDefaultHandlerForURLScheme(schemeRef, bundleIDRef);
	CFRelease(schemeRef);
	CFRelease(bundleIDRef);
	return s == 0;
}

@end
