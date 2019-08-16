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

#import "AppHook.h"
#import "Constants.h"
#import "BarStatusItem.h"
#import "WebFeed.h"
#import "UpdateScheduler.h"
#import "Preferences.h"
#import "DrawImage.h"
#import "SettingsFeeds+DragDrop.h"
#import "UserPrefs.h"
#import "StoreCoordinator.h"

@interface AppHook()
@property (strong) NSWindowController *prefWindow;
@end

@implementation AppHook

- (instancetype)init {
	self = [super init];
	self.delegate = self;
	return self;
}

- (void)applicationWillFinishLaunching:(NSNotification *)notification {
	RegisterImageViewNames();
	_statusItem = [BarStatusItem new];
	NSAppleEventManager *appleEventManager = [NSAppleEventManager sharedAppleEventManager];
	[appleEventManager setEventHandler:self andSelector:@selector(handleAppleEvent:withReplyEvent:)
						 forEventClass:kInternetEventClass andEventID:kAEGetURL];
	[self migrateVersionUpdate];
}

- (void)applicationDidFinishLaunching:(NSNotification *)aNotification {
	[_statusItem asyncReloadUnreadCount];
	[UpdateScheduler registerNetworkChangeNotification]; // will call update scheduler
	if ([StoreCoordinator isEmpty]) {
		[_statusItem showWelcomeMessage];
		[WebFeed autoDownloadAndParseUpdateURL];
	}
}

- (void)applicationWillTerminate:(NSNotification *)aNotification {
	[UpdateScheduler unregisterNetworkChangeNotification];
}

/// Called during application start. Perform any version dependent updates here
- (void)migrateVersionUpdate {
	// Currently unused, but you'll be thankful to know the previous version number in the future
	[UserPrefs dbUpdateFileVersion];
	[UserPrefs dbUpdateAppVersion];
}


#pragma mark - App Preferences


/// Called whenever the user activates the preferences (either through menu click or hotkey).
- (Preferences*)openPreferences {
	if (!self.prefWindow) {
		self.prefWindow = [[NSWindowController alloc] initWithWindow:[Preferences window]];
		[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(preferencesClosed:) name:NSWindowWillCloseNotification object:self.prefWindow.window];
	}
	[NSApp activateIgnoringOtherApps:YES];
	[self.prefWindow showWindow:nil];
	return (Preferences*)self.prefWindow.window;
}

/// Callback method after user closes the preferences window.
- (void)preferencesClosed:(id)sender {
	[[NSNotificationCenter defaultCenter] removeObserver:self name:NSWindowWillCloseNotification object:self.prefWindow.window];
	self.prefWindow = nil;
	[UpdateScheduler scheduleNextFeed];
}

/// Close previous preferences window and re-open at the same position (will drop undo manager stack!)
- (void)reopenPreferencesIfOpen {
	if (self.prefWindow) {
		CGPoint screenPoint = self.prefWindow.window.frame.origin;
		[self.prefWindow close];
		[[self openPreferences] setFrameOrigin:screenPoint];
	}
}


#pragma mark - Core Data stack


@synthesize persistentContainer = _persistentContainer;

- (NSPersistentContainer *)persistentContainer {
	// The persistent container for the application. This implementation creates and returns a container, having loaded the store for the application to it.
	@synchronized (self) {
		if (_persistentContainer == nil) {
			_persistentContainer = [[NSPersistentContainer alloc] initWithName:@"DBv1"];
			[_persistentContainer loadPersistentStoresWithCompletionHandler:^(NSPersistentStoreDescription *storeDescription, NSError *error) {
				if (error != nil) {
					NSLog(@"Couldn't read NSPersistentContainer: %@, %@", error, error.userInfo);
					abort();
				}
			}];
		}
	}
	return _persistentContainer;
}

- (NSApplicationTerminateReply)applicationShouldTerminate:(NSApplication *)sender {
	// Save changes in the application's managed object context before the application terminates.
	NSManagedObjectContext *context = self.persistentContainer.viewContext;
	
	if (![context commitEditing]) {
		NSLog(@"%@:%@ unable to commit editing to terminate", [self class], NSStringFromSelector(_cmd));
		return NSTerminateCancel;
	}
	
	if (!context.hasChanges) {
		return NSTerminateNow;
	}
	
	NSError *error = nil;
	if (![context save:&error]) {
		
		// Customize this code block to include application-specific recovery steps.
		BOOL result = [sender presentError:error];
		if (result) {
			return NSTerminateCancel;
		}
		
		NSString *question = NSLocalizedString(@"Could not save changes while quitting. Quit anyway?", @"Quit without saves error question message");
		NSString *info = NSLocalizedString(@"Quitting now will lose any changes you have made since the last successful save", @"Quit without saves error question info");
		NSString *quitButton = NSLocalizedString(@"Quit anyway", @"Quit anyway button title");
		NSString *cancelButton = NSLocalizedString(@"Cancel", @"Cancel button title");
		NSAlert *alert = [[NSAlert alloc] init];
		[alert setMessageText:question];
		[alert setInformativeText:info];
		[alert addButtonWithTitle:quitButton];
		[alert addButtonWithTitle:cancelButton];
		
		NSInteger answer = [alert runModal];
		
		if (answer == NSAlertSecondButtonReturn) {
			return NSTerminateCancel;
		}
	}
	return NSTerminateNow;
}


#pragma mark - Application Input (URLs and Files)


/**
 Callback method fired on opml file import
 */
- (void)application:(NSApplication *)sender openFiles:(NSArray<NSString *> *)filenames {
	NSMutableArray<NSURL*> *urls = [NSMutableArray arrayWithCapacity:filenames.count];
	for (NSString *file in filenames) {
		NSURL *u = [NSURL fileURLWithPath:file];
		if (u) [urls addObject:u];
	}
	SettingsFeeds *sf = [[self openPreferences] selectTab:1];
	[sf importOpmlFiles:urls];
	[sender replyToOpenOrPrint:NSApplicationDelegateReplySuccess];
}

/**
 Callback method fired when opened with an URL (@c feed: and @c barss: scheme)
 */
- (void)handleAppleEvent:(NSAppleEventDescriptor *)event withReplyEvent:(NSAppleEventDescriptor *)replyEvent {
	NSString *url = [[event paramDescriptorForKeyword:keyDirectObject] stringValue];
	NSString *scheme = [[[NSURL URLWithString:url] scheme] lowercaseString];
	url = [url substringFromIndex:scheme.length + 1]; // + ':'
	if (url.length >= 2 && [[url substringToIndex:2] isEqualToString:@"//"]) {
		url = [url substringFromIndex:2];
	}
	if ([scheme isEqualToString:kURLSchemeFeed]) {
		[WebFeed autoDownloadAndParseURL:url addAnyway:NO modify:nil];
	} else if ([scheme isEqualToString:kURLSchemeBarss]) {
		NSMutableArray<NSString*> *comp = [[url pathComponents] mutableCopy];
		NSString *action = comp.firstObject;
		if (action) {
			[comp removeObjectAtIndex:0];
			[self handleConfigURLScheme:action parameters:comp];
		}
	}
}

/**
 Helper method for handling the @c barss: scheme (see below).
       @textblock
 barss:open/preferences[/0-4]
 barss:config/fixcache[/silent]
       @/textblock
 */
- (void)handleConfigURLScheme:(const NSString*)action parameters:(NSArray<NSString*>*)params {
	if ([action isEqualToString:kURLActionOpen]) {
		if ([params.firstObject isEqualToString:kURLParamPreferences]) {
			NSDecimalNumber *num = [NSDecimalNumber decimalNumberWithString:params.lastObject];
			[[self openPreferences] selectTab:num.unsignedIntegerValue];
		}
	} else if ([action isEqualToString:kURLActionConfig]) {
		if ([params.firstObject isEqualToString:kURLParamFixCache]) {
			[StoreCoordinator cleanupAndShowAlert:![params.lastObject isEqualToString:kURLParamSilent]];
		}
	}
}


#pragma mark - Event Handling, Forward Send Key Down Events


static NSEventModifierFlags fnKeyFlags = NSEventModifierFlagShift | NSEventModifierFlagControl | NSEventModifierFlagOption | NSEventModifierFlagCommand | NSEventModifierFlagFunction;

- (void) sendEvent:(NSEvent *)event {
	if ([event type] == NSEventTypeKeyDown) {
		if (!event.characters || event.characters.length == 0) {
			[super sendEvent:event];
			return;
		}
		NSEventModifierFlags flags = (event.modifierFlags & fnKeyFlags); // ignore caps lock, etc.
		unichar key = [event.characters characterAtIndex:0]; // charactersIgnoringModifiers
		if (flags == NSEventModifierFlagCommand) {
			switch (key) {
				case 'x': if ([self sendAction:@selector(cut:) to:nil from:self]) return; break;
				case 'c': if ([self sendAction:@selector(copy:) to:nil from:self]) return; break;
				case 'v': if ([self sendAction:@selector(paste:) to:nil from:self]) return; break;
				case 'a': if ([self sendAction:@selector(selectAll:) to:nil from:self]) return; break;
				case 'q': if ([self sendAction:@selector(performClose:) to:nil from:self]) return; break;
				case 'w': if ([self sendAction:@selector(performClose:) to:nil from:self]) return; break;
				case 'r': if ([self sendAction:@selector(reloadData) to:nil from:self]) return; break;
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wundeclared-selector"
				case 'z': if ([self sendAction:@selector(undo:) to:nil from:self]) return; break;
			}
		} else if (flags == (NSEventModifierFlagCommand | NSEventModifierFlagShift)) {
			if (key == 'z') {
				if ([self sendAction:@selector(redo:) to:nil from:self])
					return;
			}
		}
#pragma clang diagnostic pop
	}
	[super sendEvent:event];
}

@end
