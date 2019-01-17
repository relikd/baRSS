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

#import "Preferences.h"
#import "SettingsFeeds.h"
#import "SettingsGeneral.h"


@interface Preferences ()
@property (weak) IBOutlet SettingsGeneral *settingsGeneral;
@property (weak) IBOutlet SettingsFeeds *settingsFeeds;
@property (weak) IBOutlet NSView *aboutView;
@property (weak) IBOutlet NSTextField *lblAppName;
@property (weak) IBOutlet NSTextField *lblAppVersion;
@end

@implementation Preferences

/// Restore tab selection from previous session
- (void)windowDidLoad {
	[super windowDidLoad];
	NSUInteger idx = (NSUInteger)[[NSUserDefaults standardUserDefaults] integerForKey:@"preferencesTab"];
	if (idx >= self.window.toolbar.items.count)
		idx = 0;
	[self tabClicked:self.window.toolbar.items[idx]];
}

/// Replace content view according to selected tab
- (IBAction)tabClicked:(NSToolbarItem *)sender {
	self.window.contentView = nil;
	if ([sender.itemIdentifier isEqualToString:@"tabGeneral"]) {
		self.window.contentView = self.settingsGeneral.view;
	} else if ([sender.itemIdentifier isEqualToString:@"tabFeeds"]) {
		self.window.contentView = self.settingsFeeds.view;
	} else if ([sender.itemIdentifier isEqualToString:@"tabAbout"]) {
		NSDictionary *infoDict = [[NSBundle mainBundle] infoDictionary];
		self.lblAppName.objectValue = infoDict[@"CFBundleName"];
		self.lblAppVersion.stringValue = [NSString stringWithFormat:NSLocalizedString(@"Version %@", nil), infoDict[@"CFBundleShortVersionString"]];
		self.window.contentView = self.aboutView;
	}
	
	self.window.toolbar.selectedItemIdentifier = sender.itemIdentifier;
	[self.window recalculateKeyViewLoop];
	[self.window setInitialFirstResponder:self.window.contentView];
	
	NSInteger selectedIndex = (NSInteger)[self.window.toolbar.items indexOfObject:sender];
	[[NSUserDefaults standardUserDefaults] setInteger:selectedIndex forKey:@"preferencesTab"];
}

@end


/// A window that does not respond to Cmd-C, Cmd-Z, Cmd-Shift-Z and Enter-pressed events.
@interface NonRespondingWindow : NSWindow
@end

@implementation NonRespondingWindow
- (BOOL)respondsToSelector:(SEL)aSelector {
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wundeclared-selector"
	if (aSelector == @selector(enterPressed:) || aSelector == @selector(copy:)
		|| aSelector == @selector(undo:) || aSelector == @selector(redo:)) {
#pragma clang diagnostic pop
		return NO;
	}
	return [super respondsToSelector:aSelector];
}
@end
