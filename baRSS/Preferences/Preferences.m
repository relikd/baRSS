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
#import "SettingsGeneral.h"
#import "SettingsFeeds.h"
#import "SettingsAppearance.h"
#import "SettingsAbout.h"
#import "UserPrefs.h"

/// Managing individual tabs in application preferences
@interface PrefTabs : NSTabViewController
@end

@implementation PrefTabs

- (instancetype)init {
	self = [super init];
	if (self) {
		self.tabStyle = NSTabViewControllerTabStyleToolbar;
		self.transitionOptions = NSViewControllerTransitionNone;
		
		NSTabViewItem *flexibleWidth = [[NSTabViewItem alloc] initWithIdentifier:NSToolbarFlexibleSpaceItemIdentifier];
		flexibleWidth.viewController = [NSViewController new];
		
		self.tabViewItems = @[
			TabItem(NSImageNamePreferencesGeneral, NSLocalizedString(@"General", nil), [SettingsGeneral class]),
			TabItem(NSImageNameUserAccounts, NSLocalizedString(@"Feeds", nil), [SettingsFeeds class]),
			TabItem(NSImageNameFontPanel, NSLocalizedString(@"Appearance", nil), [SettingsAppearance class]),
			flexibleWidth,
			TabItem(NSImageNameInfo, NSLocalizedString(@"About", nil), [SettingsAbout class]),
		];
		[self switchToTab: UserPrefsUInt(Pref_prefSelectedTab)];
	}
	return self;
}

/// Helper method to generate tab item with image, label, and controller.
static inline NSTabViewItem* TabItem(NSImageName imageName, NSString *text, Class class) {
	NSTabViewItem *item = [NSTabViewItem tabViewItemWithViewController: [class new]];
	item.image = [NSImage imageNamed:imageName];
	item.label = text;
	return item;
}

/// Safely set selected index without out of bounds exception
- (__kindof NSViewController*)switchToTab:(NSUInteger)index {
	if (index < 0 || index >= self.tabViewItems.count)
		return nil;
	NSTabViewItem *tab = self.tabViewItems[index];
	if (tab.identifier == NSToolbarFlexibleSpaceItemIdentifier)
		return nil;
	self.selectedTabViewItemIndex = (NSInteger)index;
	return [tab viewController];
}

/// Delegate method, store last selected tab to user preferences
- (void)tabView:(NSTabView*)tabView didSelectTabViewItem:(nullable NSTabViewItem*)tabViewItem {
	[super tabView:tabView didSelectTabViewItem:tabViewItem];
	NSInteger newIndex = self.selectedTabViewItemIndex;
	if (UserPrefsInt(Pref_prefSelectedTab) != newIndex)
		UserPrefsSetInt(Pref_prefSelectedTab, newIndex);
}

@end


@implementation Preferences

+ (instancetype)window {
	NSWindowStyleMask style = NSWindowStyleMaskTitled | NSWindowStyleMaskClosable | NSWindowStyleMaskResizable | NSWindowStyleMaskUnifiedTitleAndToolbar;
	Preferences *w = [[Preferences alloc] initWithContentRect:NSMakeRect(0, 0, 320, 327) styleMask:style backing:NSBackingStoreBuffered defer:YES];
	w.contentMinSize = NSMakeSize(320, 327);
	w.windowController.shouldCascadeWindows = YES;
	w.title = [NSString stringWithFormat:NSLocalizedString(@"%@ Preferences", nil), NSProcessInfo.processInfo.processName];
	w.contentViewController = [PrefTabs new];
	w.delegate = w;
	NSWindowPersistableFrameDescriptor prevFrame = UserPrefsString(Pref_prefWindowFrame);
	if (!prevFrame) {
		[w setContentSize:NSMakeSize(320, 327)];
		[w center];
	} else {
		[w setFrameFromString:prevFrame];
	}
	return w;
}

/// Selects tab (if not flexible space or out of bounds) and returns associated view controller
- (__kindof NSViewController*)selectTab:(NSUInteger)index {
	return [(PrefTabs*)self.contentViewController switchToTab:index];
}

- (void)windowWillClose:(NSNotification *)notification {
	UserPrefsSet(Pref_prefWindowFrame, self.stringWithSavedFrame);
}

/// Do not respond to Cmd-Z and Cmd-Shift-Z. Will be handled in subview controllers.
- (BOOL)respondsToSelector:(SEL)aSelector {
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wundeclared-selector"
	if (aSelector == @selector(undo:) || aSelector == @selector(redo:)) {
#pragma clang diagnostic pop
		return NO;
	}
	return [super respondsToSelector:aSelector];
}

@end

