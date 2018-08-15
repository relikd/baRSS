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

#import "BarMenu.h"
#import "StoreCoordinator.h"
#import "DrawImage.h"
#import "Preferences.h"

@interface BarMenu()
@property (strong) NSStatusItem *barItem;
@property (strong) Preferences *prefWindow;
@property (weak) NSMenu *mm;
@end


@implementation BarMenu

- (instancetype)init {
	self = [super init];
	self.barItem = [self statusItem];
	[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(preferencesClosed) name:@"baRSSPreferencesClosed" object:nil];
//	[self donothing];
	return self;
}

- (void)donothing {
	dispatch_async(dispatch_get_main_queue(), ^{
		[self.mm itemAtIndex:4].title = [NSString stringWithFormat:@"%@", [NSDate date]];
	});
	sleep(1);
	[self performSelectorInBackground:@selector(donothing) withObject:nil];
}

-(void)dealloc {
	[[NSNotificationCenter defaultCenter] removeObserver:self];
}

- (NSStatusItem*)statusItem {
	NSStatusItem *item = [NSStatusBar.systemStatusBar statusItemWithLength:NSVariableStatusItemLength];
	item.title = @"me";
	item.menu = self.mainMenu;
	item.highlightMode = YES;
	item.image = [[RSSIcon templateIcon:16 tint:nil] image];
	item.image.template = YES;
	return item;
}

- (void)openPreferences {
	if (!self.prefWindow)
		self.prefWindow = [[Preferences alloc] initWithWindowNibName:@"Preferences"];
	[NSApp activateIgnoringOtherApps:YES];
	[self.prefWindow showWindow:nil];
}

- (void)preferencesClosed {
	self.prefWindow = nil;
}

#pragma mark - Main Menu Item Actions

- (void)pauseUpdates {
	NSLog(@"1pause");
}

- (void)updateAllFeeds {
	NSLog(@"1update all");
}

- (void)openAllUnread {
	NSLog(@"1all unread");
}

- (void)openFeedURL:(NSMenuItem*)sender {
	id obj = [StoreCoordinator objectWithID:sender.representedObject];
	NSString *url = nil;
	if ([obj isKindOfClass:[FeedItem class]]) {
		url = [(FeedItem*)obj link];
	} else if ([obj isKindOfClass:[FeedConfig class]]) {
		url = [[(FeedConfig*)obj feed] link];
	}
	if (!url || url.length == 0) return;
	[[NSWorkspace sharedWorkspace] openURLs:@[[NSURL URLWithString:url]] withAppBundleIdentifier:@"com.apple.Safari" options:NSWorkspaceLaunchDefault additionalEventParamDescriptor:nil launchIdentifiers:nil];
}

#pragma mark - Menu Generator

- (NSMenu*)mainMenu {
	NSMenu *menu = [NSMenu new];
	menu.autoenablesItems = NO;
//	self.mm = menu;
	[self addTitle:@"Pause Updates" selector:@selector(pauseUpdates) key:@"" toMenu:menu];
	[self addTitle:@"Update all feeds" selector:@selector(updateAllFeeds) key:@"" toMenu:menu];
	[self addTitle:@"Open all unread" selector:@selector(openAllUnread) key:@"" toMenu:menu];
	[menu addItem:[NSMenuItem separatorItem]];
	
	NSArray<FeedConfig*> *items = [StoreCoordinator sortedFeedConfigItems];
	for (FeedConfig *fc in items) {
		[menu addItem:[self menuItemForFeedConfig:fc]];
	}
	
	[menu addItem:[NSMenuItem separatorItem]];
	[self addTitle:@"Preferences" selector:@selector(openPreferences) key:@"," toMenu:menu];
	[menu addItemWithTitle:@"Quit" action:@selector(terminate:) keyEquivalent:@"q"];
	return menu;
}

- (void)addTitle:(NSString*)title selector:(SEL)selector key:(NSString*)key toMenu:(NSMenu*)menu {
	NSMenuItem *item = [[NSMenuItem alloc] initWithTitle:title action:selector keyEquivalent:key];
	item.target = self;
	[menu addItem:item];
}

- (NSMenuItem*)menuItemForFeedConfig:(FeedConfig*)fc {
	NSMenuItem *item;
	if (fc.typ == SEPARATOR) {
		item = [NSMenuItem separatorItem];
	} else {
		item = [[NSMenuItem alloc] initWithTitle:fc.name action:nil keyEquivalent:@""];
		if (fc.typ == FEED) {
			item.submenu = [self menuForFeed:fc.feed];
			item.action = @selector(openFeedURL:);
			item.target = self;
			item.toolTip = fc.feed.subtitle;
			item.enabled = (fc.feed.link.length > 0);
			static NSImage *defaultRSSIcon;
			if (!defaultRSSIcon)
				defaultRSSIcon = [[[RSSIcon iconWithSize:NSMakeSize(16, 16)] autoGradient] image];
			item.image = defaultRSSIcon;
		} else {
			item.submenu = [self menuForFeedConfig:fc];
			item.image = [NSImage imageNamed:NSImageNameFolder];
			item.image.size = NSMakeSize(16, 16);
		}
	}
	item.representedObject = fc.objectID;
	return item;
}

- (NSMenu*)menuForFeedConfig:(FeedConfig*)parent {
	NSMenu *menu = [NSMenu new];
	menu.autoenablesItems = NO;
	// TODO: open unread for groups ...
	for (FeedConfig *fc in parent.sortedChildren) {
		[menu addItem:[self menuItemForFeedConfig:fc]];
	}
	return menu;
}

- (NSMenu*)menuForFeed:(Feed*)feed {
	NSMenu *menu = [NSMenu new];
	menu.autoenablesItems = NO;
	// TODO: open unread for feed only ...
	for (FeedItem *entry in feed.items) {
		[menu addItem:[self menuItemForFeedItem:entry]];
	}
	return menu;
}

- (NSMenuItem*)menuItemForFeedItem:(FeedItem*)item {
	NSMenuItem *mi = [[NSMenuItem alloc] initWithTitle:item.title action:@selector(openFeedURL:) keyEquivalent:@""];
	mi.target = self;
	mi.representedObject = item.objectID;
	mi.toolTip = item.subtitle;
	mi.enabled = (item.link.length > 0);
	return mi;
}

//- (NSIndexPath*)indexPathForMenu:(NSMenu*)menu {
//	NSMenu *parent = menu.supermenu;
//	if (parent == nil) {
//		return [NSIndexPath new];
//	} else {
//		return [[self indexPathForMenu:parent] indexPathByAddingIndex:(NSUInteger)[parent indexOfItemWithSubmenu:menu]];
//	}
//}

@end
