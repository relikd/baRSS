#import "AppHook.h"
#import "DrawImage.h"
#import "UserPrefs.h"
#import "Preferences.h"
#import "BarStatusItem.h"
#import "UpdateScheduler.h"
#import "StoreCoordinator.h"
#import "SettingsFeeds+DragDrop.h"
#import "URLScheme.h"
#import "NSURL+Ext.h"
#import "NSError+Ext.h"

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
	UserPrefsInit();
	RegisterImageViewNames();
	_statusItem = [BarStatusItem new];
	NSAppleEventManager *appleEventManager = [NSAppleEventManager sharedAppleEventManager];
	[appleEventManager setEventHandler:self andSelector:@selector(handleAppleEvent:withReplyEvent:)
						 forEventClass:kInternetEventClass andEventID:kAEGetURL];
	[self migrateVersionUpdate];
}

- (void)applicationDidFinishLaunching:(NSNotification *)aNotification {
	BOOL initial = [[NSURL faviconsCacheURL] mkdir];
	[_statusItem asyncReloadUnreadCount];
	[UpdateScheduler registerNetworkChangeNotification]; // will call update scheduler
	if ([StoreCoordinator isEmpty]) {
		// stupid macOS bugs ... status-bar-menu-item frame is zero without delay
		// [_statusItem showWelcomeMessage];
		[_statusItem performSelector:@selector(showWelcomeMessage) withObject:nil afterDelay:.2];
		[UpdateScheduler autoDownloadAndParseUpdateURL];
	} else {
		// mostly for version migration 0.9.4 ~> 1.0 (favicon storage)
		if (initial) [UpdateScheduler updateAllFavicons];
	}
}

- (void)applicationWillTerminate:(NSNotification *)aNotification {
	[UpdateScheduler unregisterNetworkChangeNotification];
}

/// Called during application start. Perform any version migration updates here.
- (void)migrateVersionUpdate {
	// Currently unused, but you'll be thankful in the future for a previously saved version number
	[StoreCoordinator setOption:@"app-version" value: UserPrefsAppVersion()];
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


#pragma mark - Core Data stack


@synthesize persistentContainer = _persistentContainer;

/// The persistent container for the application. This implementation creates and returns a container, having loaded the store for the application to it.
- (NSPersistentContainer *)persistentContainer {
	@synchronized (self) {
		if (_persistentContainer == nil) {
			NSManagedObjectModel *mom = [NSManagedObjectModel mergedModelFromBundles:nil];
			_persistentContainer = [[NSPersistentContainer alloc] initWithName:@"Library" managedObjectModel:mom];
			[_persistentContainer loadPersistentStoresWithCompletionHandler:^(NSPersistentStoreDescription *storeDescription, NSError *error) {
				if ([error inCaseLog:"Couldn't read NSPersistentContainer"])
					abort();
			}];
		}
	}
	return _persistentContainer;
}

/// Save changes in the application's managed object context before the application terminates.
- (NSApplicationTerminateReply)applicationShouldTerminate:(NSApplication *)sender {
	NSManagedObjectContext *context = self.persistentContainer.viewContext;
	if (![context commitEditing]) {
		NSLogCaller(@"unable to commit editing to terminate");
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
		
		if ([alert runModal] == NSAlertSecondButtonReturn) {
			return NSTerminateCancel;
		}
	}
	return NSTerminateNow;
}


#pragma mark - Application Input (URLs and Files)


/// Callback method fired on opml file import
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

/// Callback method fired when opened with an URL (@c feed: and @c barss: scheme)
- (void)handleAppleEvent:(NSAppleEventDescriptor *)event withReplyEvent:(NSAppleEventDescriptor *)replyEvent {
	[URLScheme withURL:[[event paramDescriptorForKeyword:keyDirectObject] stringValue]];
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
