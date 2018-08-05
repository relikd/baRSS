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

#import "AppDelegate.h"
#import "PyHandler.h"
#import "DrawImage.h"

@interface AppDelegate ()
@property (strong) NSStatusItem *statusItem;
@property (weak) IBOutlet NSMenu *statusMenu;
@end

@implementation AppDelegate

- (void)applicationDidFinishLaunching:(NSNotification *)aNotification {
	self.statusItem = [NSStatusBar.systemStatusBar statusItemWithLength:NSVariableStatusItemLength];
	self.statusItem.title = @"me";
	self.statusItem.menu = self.statusMenu;
	self.statusItem.highlightMode = YES;
	self.statusItem.image = [[RSSIcon templateIcon:16 tint:nil] image];
	self.statusItem.image.template = YES;
	[PyHandler prepare];
	printf("up and running\n");
}

- (void)applicationWillTerminate:(NSNotification *)aNotification {
	[PyHandler shutdown];
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
			NSUndoManager *um = [[NSUndoManager alloc] init];
			um.levelsOfUndo = 30;
			_persistentContainer.viewContext.undoManager = um;
        }
    }
    
    return _persistentContainer;
}

#pragma mark - Core Data Saving and Undo support

- (IBAction)saveAction:(id)sender {
    // Performs the save action for the application, which is to send the save: message to the application's managed object context. Any encountered errors are presented to the user.
    NSManagedObjectContext *context = self.persistentContainer.viewContext;

    if (![context commitEditing]) {
        NSLog(@"%@:%@ unable to commit editing before saving", [self class], NSStringFromSelector(_cmd));
    }
    
    NSError *error = nil;
    if (context.hasChanges && ![context save:&error]) {
        // Customize this code block to include application-specific recovery steps.              
        [[NSApplication sharedApplication] presentError:error];
    }
}

- (NSUndoManager *)windowWillReturnUndoManager:(NSWindow *)window {
    // Returns the NSUndoManager for the application. In this case, the manager returned is that of the managed object context for the application.
    return self.persistentContainer.viewContext.undoManager;
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

@end
