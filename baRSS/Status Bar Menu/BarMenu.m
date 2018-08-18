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
#import "MenuItemInfo.h"


@interface BarMenu()
typedef NS_OPTIONS(NSInteger, MenuItemTag) {
	ScopeGlobal = 1,
	ScopeGroup = (1<<1),
	ScopeLocal = (1<<2),
	PauseUpdates = (1<<3),
	UpdateFeed = (1<<4),
	MarkAllRead = (1<<5),
	MarkAllUnread = (1<<6),
	OpenAllUnread = (1<<7),
};

@property (strong) NSStatusItem *barItem;
@property (strong) Preferences *prefWindow;
@property (weak) NSMenu *mm;
@property (assign) int unreadCountTotal;
@end


@implementation BarMenu

- (instancetype)init {
	self = [super init];
	self.barItem = [NSStatusBar.systemStatusBar statusItemWithLength:NSVariableStatusItemLength];
	self.barItem.menu = self.mainMenu;
	self.barItem.highlightMode = YES;
	[self updateBarIcon];
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

- (void)updateBarIcon {
	// TODO: Option: unread count in menubar, Option: highlight color, Option: icon choice
	if (self.unreadCountTotal > 0) {
		self.barItem.title = [NSString stringWithFormat:@"%d", self.unreadCountTotal];
		self.barItem.image = [[RSSIcon templateIcon:16 tint:[RSSIcon rssOrange]] image];
	} else {
		self.barItem.title = @"";
		self.barItem.image = [[RSSIcon templateIcon:16 tint:nil] image];
		self.barItem.image.template = YES;
	}
}


#pragma mark - Menu Generator


- (NSMenu*)mainMenu {
	NSMenu *menu = [NSMenu new];
	menu.autoenablesItems = NO;
	[self addTitle:NSLocalizedString(@"Pause Updates", nil) selector:@selector(pauseUpdates:) key:@"" toMenu:menu tag:PauseUpdates];
	[self addTitle:NSLocalizedString(@"Update all feeds", nil) selector:@selector(updateAllFeeds:) key:@"" toMenu:menu tag:UpdateFeed];
	[menu addItem:[NSMenuItem separatorItem]];
	[self defaultHeaderForMenu:menu scope:ScopeGlobal];
	
	for (FeedConfig *fc in [StoreCoordinator sortedFeedConfigItems]) {
		[menu addItem:[self menuItemForFeedConfig:fc unread:&_unreadCountTotal]];
	}
	
	[menu addItem:[NSMenuItem separatorItem]];
	[self addTitle:NSLocalizedString(@"Preferences", nil) selector:@selector(openPreferences) key:@"," toMenu:menu tag:0];
	[menu addItemWithTitle:NSLocalizedString(@"Quit", nil) action:@selector(terminate:) keyEquivalent:@"q"];
	return menu;
}

- (NSMenuItem*)menuItemForFeedConfig:(FeedConfig*)fc unread:(int*)unread {
	NSMenuItem *item;
	if (fc.typ == SEPARATOR) {
		item = [NSMenuItem separatorItem];
		item.representedObject = [MenuItemInfo withID:fc.objectID];
		return item;
	}
	int count = 0;
	if (fc.typ == FEED) {
		item = [self feedItem:fc unread:&count];
	} else if (fc.typ == GROUP) {
		item = [self groupItem:fc unread:&count];
	}
	*unread += count;
	item.representedObject = [MenuItemInfo withID:fc.objectID];
	[item markReadAndUpdateTitle:-count];
	[self updateMenuHeader:item.submenu hasUnread:(count > 0)];
	return item;
}

- (NSMenuItem*)feedItem:(FeedConfig*)fc unread:(int*)unread {
	static NSImage *defaultRSSIcon;
	if (!defaultRSSIcon)
		defaultRSSIcon = [[[RSSIcon iconWithSize:NSMakeSize(16, 16)] autoGradient] image];
	
	NSMenuItem *item = [[NSMenuItem alloc] initWithTitle:fc.name action:@selector(openFeedURL:) keyEquivalent:@""];
	item.target = self;
	item.submenu = [self defaultHeaderForMenu:nil scope:ScopeLocal];
	for (FeedItem *obj in fc.feed.items) {
		if (obj.unread) ++(*unread);
		[item.submenu addItem:[self feedEntryItem:obj]];
	}
	item.toolTip = fc.feed.subtitle;
	item.enabled = (fc.feed.items.count > 0);
	item.image = defaultRSSIcon;
	return item;
}

- (NSMenuItem*)groupItem:(FeedConfig*)fc unread:(int*)unread {
	static NSImage *groupIcon;
	if (!groupIcon) {
		groupIcon = [NSImage imageNamed:NSImageNameFolder];
		groupIcon.size = NSMakeSize(16, 16);
	}
	NSMenuItem *item = [[NSMenuItem alloc] initWithTitle:fc.name action:nil keyEquivalent:@""];
	item.image = groupIcon;
	item.submenu = [self defaultHeaderForMenu:nil scope:ScopeGroup];
	for (FeedConfig *obj in fc.sortedChildren) {
		NSMenuItem *subItem = [self menuItemForFeedConfig:obj unread:unread];
//		*unread += [(MenuItemInfo*)subItem.representedObject unreadCount];
		[item.submenu addItem:subItem];
	}
	return item;
}

- (NSMenuItem*)feedEntryItem:(FeedItem*)item {
	NSMenuItem *mi = [[NSMenuItem alloc] initWithTitle:item.title action:@selector(openFeedURL:) keyEquivalent:@""];
	mi.target = self;
	mi.representedObject = [MenuItemInfo withID:item.objectID unread:(item.unread ? 1 : 0)];
	mi.toolTip = item.subtitle;
	mi.enabled = (item.link.length > 0);
	mi.state = (item.unread ? NSControlStateValueOn : NSControlStateValueOff);
	mi.tag = ScopeLocal;
	return mi;
}


/**
 Append header items to menu accoring to user preferences.
 
 @note If @c menu is @c nil a new menu is created and returned.
 @param menu The menu where the items should be appended.
 @param scope Tag will be concatenated with that scope (Global, Group or Local).
 @return Will return the menu item provided or create a new one if menu was @c nil.
 */
- (NSMenu*)defaultHeaderForMenu:(NSMenu*)menu scope:(MenuItemTag)scope {
	if (!menu) {
		menu = [NSMenu new];
		menu.autoenablesItems = NO;
	}
	// TODO: hide items according to preferences
	[self addTitle:NSLocalizedString(@"Mark all read", nil) selector:@selector(markAllRead:) key:@"" toMenu:menu tag:MarkAllRead | scope];
	[self addTitle:NSLocalizedString(@"Mark all unread", nil) selector:@selector(markAllUnread:) key:@"" toMenu:menu tag:MarkAllUnread | scope];
	[self addTitle:NSLocalizedString(@"Open all unread", nil) selector:@selector(openAllUnread:) key:@"" toMenu:menu tag:OpenAllUnread | scope];
	[menu addItem:[NSMenuItem separatorItem]];
	return menu;
}

- (void)updateMenuHeader:(NSMenu*)menu hasUnread:(BOOL)flag {
//	[menu itemWithTag:MenuItemTag_FeedMarkAllRead].enabled = flag;
//	[menu itemWithTag:MenuItemTag_FeedMarkAllUnread].enabled = !flag;
//	[menu itemWithTag:MenuItemTag_FeedOpenAllUnread].enabled = flag;
}

- (void)addTitle:(NSString*)title selector:(SEL)selector key:(NSString*)key toMenu:(NSMenu*)menu tag:(MenuItemTag)tag {
	NSMenuItem *item = [[NSMenuItem alloc] initWithTitle:title action:selector keyEquivalent:key];
	item.target = self;
	item.tag = tag;
	[menu addItem:item];
}

//- (NSIndexPath*)indexPathForMenu:(NSMenu*)menu {
//	NSMenu *parent = menu.supermenu;
//	if (parent == nil) {
//		return [NSIndexPath new];
//	} else {
//		return [[self indexPathForMenu:parent] indexPathByAddingIndex:(NSUInteger)[parent indexOfItemWithSubmenu:menu]];
//	}
//}


#pragma mark - Menu Actions


- (void)openPreferences {
	if (!self.prefWindow) {
		self.prefWindow = [[Preferences alloc] initWithWindowNibName:@"Preferences"];
		self.prefWindow.window.title = [NSString stringWithFormat:@"%@ %@", NSProcessInfo.processInfo.processName,
										NSLocalizedString(@"Preferences", nil)];
		// one time token to set reference to nil, which will release window
		NSNotificationCenter * __weak center = [NSNotificationCenter defaultCenter];
		id __block token = [center addObserverForName:NSWindowWillCloseNotification object:self.prefWindow.window queue:nil usingBlock:^(NSNotification *note) {
			self.prefWindow = nil;
			[center removeObserver:token];
		}];
	}
	[NSApp activateIgnoringOtherApps:YES];
	[self.prefWindow showWindow:nil];
}


- (void)pauseUpdates:(NSMenuItem*)sender {
	NSLog(@"1pause");
}

- (void)updateAllFeeds:(NSMenuItem*)sender {
	NSLog(@"1update all");
}

- (void)openAllUnread:(NSMenuItem*)sender {
	__block int maxItemCount = INT_MAX;
	NSMutableArray<NSURL*> *urls = [NSMutableArray<NSURL*> array];
	[self siblingsDescendantFeedConfigs:sender block:^BOOL(FeedConfig *parent, FeedItem *item) {
		if (maxItemCount <= 0)
			return NO; // stop further processing
		if (item.unread && item.link.length > 0) {
			[urls addObject:[NSURL URLWithString:item.link]];
			item.unread = NO;
			--maxItemCount;
		}
		return YES;
	}];
	maxItemCount = INT_MAX;
	int total = [sender siblingsDescendantItemInfo:^int(NSMenuItem *item, MenuItemInfo *info, int count) {
		if (maxItemCount <= 0)
			return -1; // stop further processing
		if (info.hasUnread) {
			[item markReadAndUpdateTitle:count];
			--maxItemCount;
			return count;
		}
		return 0;
	} unreadEntriesOnly:YES];
	[self updateAcestors:sender markRead:total];
	[self openURLsWithPreferredBrowser:urls];
}

- (void)markAllRead:(NSMenuItem*)sender {
	[self siblingsDescendantFeedConfigs:sender block:^BOOL(FeedConfig *parent, FeedItem *item) {
		if (item.unread)
			item.unread = NO;
		return YES;
	}];
	int total = [sender siblingsDescendantItemInfo:^int(NSMenuItem *item, MenuItemInfo *info, int count) {
		if (info.hasUnread) {
			[item markReadAndUpdateTitle:count];
			return count;
		}
		return 0;
	} unreadEntriesOnly:YES];
	[self updateAcestors:sender markRead:total];
}

- (void)markAllUnread:(NSMenuItem*)sender {
	[self siblingsDescendantFeedConfigs:sender block:^BOOL(FeedConfig *parent, FeedItem *item) {
		if (item.unread == NO)
			item.unread = YES;
		return YES;
	}];
	int total = [sender siblingsDescendantItemInfo:^int(NSMenuItem *item, MenuItemInfo *info, int count) {
		if (count > info.unreadCount)
			[item markReadAndUpdateTitle:(info.unreadCount - count)];
		return count;
	} unreadEntriesOnly:NO];
	[self updateAcestors:sender markRead:([self getAncestorUnreadCount:sender] - total)];
}

- (void)openFeedURL:(NSMenuItem*)sender {
	MenuItemInfo *info = sender.representedObject;
	if (![info isKindOfClass:[MenuItemInfo class]]) return;
	
	id obj = [StoreCoordinator objectWithID:info.objID];
	NSString *url = nil;
	if ([obj isKindOfClass:[FeedConfig class]]) {
		url = [[(FeedConfig*)obj feed] link];
	} else if ([obj isKindOfClass:[FeedItem class]]) {
		FeedItem *feed = obj;
		url = [feed link];
		if (info.hasUnread) {
			feed.unread = NO;
			[sender markReadAndUpdateTitle:1];
			[self updateAcestors:sender markRead:1];
		}
	}
	if (!url || url.length == 0) return;
	[self openURLsWithPreferredBrowser:@[[NSURL URLWithString:url]]];
}

- (void)openURLsWithPreferredBrowser:(NSArray<NSURL*>*)urls {
	if (urls.count == 0) return;
//	[[NSWorkspace sharedWorkspace] openURLs:urls withAppBundleIdentifier:@"com.apple.Safari" options:NSWorkspaceLaunchDefault additionalEventParamDescriptor:nil launchIdentifiers:nil];
}


#pragma mark - Iterating over items and propagating unread count


- (FeedConfig*)requestFeedConfigForMenuItem:(NSMenuItem*)sender {
	MenuItemInfo *info = sender.representedObject;
	if (![info isKindOfClass:[MenuItemInfo class]])
		return nil;
	id obj = [StoreCoordinator objectWithID:info.objID];
	if (![obj isKindOfClass:[FeedConfig class]])
		return nil;
	return obj;
}

- (void)siblingsDescendantFeedConfigs:(NSMenuItem*)sender block:(FeedConfigRecursiveItemsBlock)block {
	if (sender.parentItem) {
		[[self requestFeedConfigForMenuItem:sender.parentItem] descendantFeedItems:block];
	} else {
		// Sadly we can't just fetch the list of FeedItems since it is not ordered (in case open 10 at a time)
		for (FeedConfig *config in [StoreCoordinator sortedFeedConfigItems]) {
			if ([config descendantFeedItems:block] == NO)
				break;
		}
	}
}

- (void)updateAcestors:(NSMenuItem*)sender markRead:(int)count {
	[sender markAncestorsRead:count];
	self.unreadCountTotal -= count;
	if (self.unreadCountTotal < 0) {
		NSLog(@"Should never happen. Global unread count < 0");
		self.unreadCountTotal = 0;
	}
	[self updateBarIcon];
}

- (int)getAncestorUnreadCount:(NSMenuItem*)sender {
	MenuItemInfo *info = sender.parentItem.representedObject;
	if ([info isKindOfClass:[MenuItemInfo class]])
		return info.unreadCount;
	return self.unreadCountTotal;
}

@end
