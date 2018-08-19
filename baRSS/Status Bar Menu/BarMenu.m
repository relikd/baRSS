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
/// @c NSMenuItem options that are assigned to the @c tag attribute.
typedef NS_OPTIONS(NSInteger, MenuItemTag) {
	/// Item visible at the very first menu level
	ScopeGlobal = 1,
	/// Item visible at each grouping, e.g., multiple feeds in one group
	ScopeGroup = 2,
	/// Item visible at the deepest menu level (@c FeedItem elements and header)
	ScopeLocal = 4,
	/// @c NSMenuItem is an alternative
	ScopeAlternative = 8,
	///
	TagPreferences = (1 << 4),
	TagPauseUpdates = (2 << 4),
	TagUpdateFeed = (3 << 4),
	TagMarkAllRead = (4 << 4),
	TagMarkAllUnread = (5 << 4),
	TagOpenAllUnread = (6 << 4),
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
	self.barItem.highlightMode = YES;
	self.barItem.menu = [self generateMainMenu];
//	[self donothing];
	return self;
}

- (void)rebuildMenu {
	self.barItem.menu = [self generateMainMenu];
}

- (void)donothing {
	dispatch_async(dispatch_get_main_queue(), ^{
		[self.mm itemAtIndex:4].title = [NSString stringWithFormat:@"%@", [NSDate date]];
	});
	sleep(1);
	[self performSelectorInBackground:@selector(donothing) withObject:nil];
}

- (void)printUnreadRecurisve:(NSMenu*)menu str:(NSString*)prefix {
	for (NSMenuItem *item in menu.itemArray) {
		if (!item.hasUnread) continue;
		MenuItemInfo *info = item.representedObject;
		id obj = [StoreCoordinator objectWithID:info.objID];
		if ([obj isKindOfClass:[FeedItem class]])
			NSLog(@"%@ %@ (%d == %d)", prefix, item.title, item.unreadCount, [obj unread]);
		else
			NSLog(@"%@ %@ (%d)", prefix, item.title, item.unreadCount);
		if (item.hasSubmenu) {
			[self printUnreadRecurisve:item.submenu str:[NSString stringWithFormat:@"  %@", prefix]];
		}
	}
}

/**
 Update menu bar icon and text according to unread count and user preferences.
 */
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
	NSLog(@"==> %d", self.unreadCountTotal);
	[self printUnreadRecurisve:self.barItem.menu str:@""];
}


#pragma mark - Menu Generator


/**
 Builds main menu with items on the very first menu level. Including Preferences, Quit, etc.
 */
- (NSMenu*)generateMainMenu {
	NSMenu *menu = [NSMenu new];
	menu.autoenablesItems = NO;
	[self addTitle:NSLocalizedString(@"Pause Updates", nil) selector:@selector(pauseUpdates:) toMenu:menu tag:TagPauseUpdates];
	[self addTitle:NSLocalizedString(@"Update all feeds", nil) selector:@selector(updateAllFeeds:) toMenu:menu tag:TagUpdateFeed];
	[menu addItem:[NSMenuItem separatorItem]];
	[self defaultHeaderForMenu:menu scope:ScopeGlobal];
	
	self.unreadCountTotal = 0;
	for (FeedConfig *fc in [StoreCoordinator sortedFeedConfigItems]) {
		[menu addItem:[self menuItemForFeedConfig:fc unread:&_unreadCountTotal]];
	}
	[self updateBarIcon];
	
	[menu addItem:[NSMenuItem separatorItem]];
	[self addTitle:NSLocalizedString(@"Preferences", nil) selector:@selector(openPreferences) toMenu:menu tag:TagPreferences];
	menu.itemArray.lastObject.keyEquivalent = @",";
	[menu addItemWithTitle:NSLocalizedString(@"Quit", nil) action:@selector(terminate:) keyEquivalent:@"q"];
	return menu;
}

/**
 Create and return a new @c NSMenuItem from the objects attributes.

 @param config @c FeedConfig object that represents a superior feed element.
 @param unread Pointer to an int that will be incremented for each unread item.
 @return Return a fully configured Separator item OR group item OR feed item. (but not @c FeedItem item)
 */
- (NSMenuItem*)menuItemForFeedConfig:(FeedConfig*)config unread:(int*)unread {
	NSMenuItem *item;
	if (config.typ == SEPARATOR) {
		item = [NSMenuItem separatorItem];
		item.representedObject = [MenuItemInfo withID:config.objectID];
		return item;
	}
	int count = 0;
	if (config.typ == FEED) {
		item = [self feedItem:config unread:&count];
	} else if (config.typ == GROUP) {
		item = [self groupItem:config unread:&count];
	}
	*unread += count;
	item.representedObject = [MenuItemInfo withID:config.objectID];
	[item markReadAndUpdateTitle:-count];
	[self updateMenuHeader:item.submenu hasUnread:(count > 0)];
	return item;
}

/**
 Create and return a new @c NSMenuItem from the objects attributes.
 
 @param config @c FeedConfig object that represents a superior feed element.
 @param unread Pointer to an int that will be incremented for each unread item.
 */
- (NSMenuItem*)feedItem:(FeedConfig*)config unread:(int*)unread {
	static NSImage *defaultRSSIcon;
	if (!defaultRSSIcon)
		defaultRSSIcon = [[[RSSIcon iconWithSize:NSMakeSize(16, 16)] autoGradient] image];
	
	NSMenuItem *item = [[NSMenuItem alloc] initWithTitle:config.name action:@selector(openFeedURL:) keyEquivalent:@""];
	item.target = self;
	item.submenu = [self defaultHeaderForMenu:nil scope:ScopeLocal];
	for (FeedItem *obj in config.feed.items) {
		if (obj.unread) ++(*unread);
		[item.submenu addItem:[self feedEntryItem:obj]];
	}
	item.toolTip = config.feed.subtitle;
	item.enabled = (config.feed.items.count > 0);
	item.image = defaultRSSIcon;
	return item;
}

/**
 Create and return a new @c NSMenuItem from the objects attributes.
 
 @param config @c FeedConfig object that represents a group item.
 @param unread Pointer to an int that will be incremented for each unread item.
 */
- (NSMenuItem*)groupItem:(FeedConfig*)config unread:(int*)unread {
	static NSImage *groupIcon;
	if (!groupIcon) {
		groupIcon = [NSImage imageNamed:NSImageNameFolder];
		groupIcon.size = NSMakeSize(16, 16);
	}
	NSMenuItem *item = [[NSMenuItem alloc] initWithTitle:config.name action:nil keyEquivalent:@""];
	item.image = groupIcon;
	item.submenu = [self defaultHeaderForMenu:nil scope:ScopeGroup];
	for (FeedConfig *obj in config.sortedChildren) {
		[item.submenu addItem: [self menuItemForFeedConfig:obj unread:unread]];
	}
	return item;
}

/**
 Create and return a new @c NSMenuItem from @c FeedItem attributes.
 */
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
	[self addTitle:NSLocalizedString(@"Mark all read", nil) selector:@selector(markAllRead:) toMenu:menu tag:TagMarkAllRead | scope];
	[self addTitle:NSLocalizedString(@"Mark all unread", nil) selector:@selector(markAllUnread:) toMenu:menu tag:TagMarkAllUnread | scope];
	[self addTitle:NSLocalizedString(@"Open all unread", nil) selector:@selector(openAllUnread:) toMenu:menu tag:TagOpenAllUnread | scope];
	
	NSString *alternateTitle = [NSString stringWithFormat:NSLocalizedString(@"Open a few unread (%d)", nil), 3];
	[self addTitle:alternateTitle selector:@selector(openAllUnread:) toMenu:menu tag:TagOpenAllUnread | scope | ScopeAlternative];
	menu.itemArray.lastObject.alternate = YES;
	menu.itemArray.lastObject.keyEquivalentModifierMask = NSEventModifierFlagOption;
	
	[menu addItem:[NSMenuItem separatorItem]];
	return menu;
}

- (void)updateMenuHeader:(NSMenu*)menu hasUnread:(BOOL)flag {
//	[menu itemWithTag:MenuItemTag_FeedMarkAllRead].enabled = flag;
//	[menu itemWithTag:MenuItemTag_FeedMarkAllUnread].enabled = !flag;
//	[menu itemWithTag:MenuItemTag_FeedOpenAllUnread].enabled = flag;
}

/**
 Helper function to insert a menu item with @c target @c = @c self
 */
- (void)addTitle:(NSString*)title selector:(SEL)selector toMenu:(NSMenu*)menu tag:(MenuItemTag)tag {
	NSMenuItem *item = [[NSMenuItem alloc] initWithTitle:title action:selector keyEquivalent:@""];
	item.target = self;
	item.tag = tag;
	[menu addItem:item];
}


#pragma mark - Menu Actions


/**
 Called whenever the user activates the preferences (either through menu click or hotkey)
 */
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

/**
 Combined selector for menu action.
 
 @note @c sender.tag includes @c ScopeLocal, @c ScopeGroup @b or @c ScopeGlobal.
 @param sender @c NSMenuItem that was clicked during the action (e.g., "open all unread")
 */
- (void)openAllUnread:(NSMenuItem*)sender {
	int maxItemCount = INT_MAX;
	if (sender.isAlternate)
		maxItemCount = 3; // TODO: read from preferences
	
	__block int stopAfter = maxItemCount;
	NSMutableArray<NSURL*> *urls = [NSMutableArray<NSURL*> array];
	[self siblingsDescendantFeedConfigs:sender block:^BOOL(FeedConfig *parent, FeedItem *item) {
		if (stopAfter <= 0)
			return NO; // stop further processing
		if (item.unread && item.link.length > 0) {
			[urls addObject:[NSURL URLWithString:item.link]];
			item.unread = NO;
			--stopAfter;
		}
		return YES;
	}];
	stopAfter = maxItemCount;
	int total = [sender siblingsDescendantItemInfo:^int(NSMenuItem *item, int count) {
		if (item.tag & ScopeLocal) {
			if (stopAfter <= 0) return -1;
			--stopAfter;
		}
		[item markReadAndUpdateTitle:count];
		return count;
	} unreadEntriesOnly:YES];
	[self updateAcestors:sender markRead:total];
	[self openURLsWithPreferredBrowser:urls];
}

/**
 Combined selector for menu action.
 
 @note @c sender.tag includes @c ScopeLocal, @c ScopeGroup @b or @c ScopeGlobal.
 @param sender @c NSMenuItem that was clicked during the action (e.g., "mark all read")
 */
- (void)markAllRead:(NSMenuItem*)sender {
	[self siblingsDescendantFeedConfigs:sender block:^BOOL(FeedConfig *parent, FeedItem *item) {
		if (item.unread)
			item.unread = NO;
		return YES;
	}];
	int total = [sender siblingsDescendantItemInfo:^int(NSMenuItem *item, int count) {
		[item markReadAndUpdateTitle:count];
		return count;
	} unreadEntriesOnly:YES];
	[self updateAcestors:sender markRead:total];
}

/**
 Combined selector for menu action.
 
 @note @c sender.tag includes @c ScopeLocal, @c ScopeGroup @b or @c ScopeGlobal.
 @param sender @c NSMenuItem that was clicked during the action (e.g., "mark all unread")
 */
- (void)markAllUnread:(NSMenuItem*)sender {
	[self siblingsDescendantFeedConfigs:sender block:^BOOL(FeedConfig *parent, FeedItem *item) {
		if (item.unread == NO)
			item.unread = YES;
		return YES;
	}];
	int total = [sender siblingsDescendantItemInfo:^int(NSMenuItem *item, int count) {
		if (count > item.unreadCount)
			[item markReadAndUpdateTitle:(item.unreadCount - count)];
		return count;
	} unreadEntriesOnly:NO];
	[self updateAcestors:sender markRead:([self getAncestorUnreadCount:sender] - total)];
}

/**
 Called when user clicks on a single feed item or the superior feed.

 @param sender A menu item containing either a @c FeedItem or a @c FeedConfig.
 */
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
		if (sender.hasUnread) {
			feed.unread = NO;
			[sender markReadAndUpdateTitle:1];
			[self updateAcestors:sender markRead:1];
		}
	}
	if (!url || url.length == 0) return;
	[self openURLsWithPreferredBrowser:@[[NSURL URLWithString:url]]];
}

/**
 Open web links in default browser or a browser the user selected in the preferences.

 @param urls A list of @c NSURL objects that will be opened immediatelly in bulk.
 */
- (void)openURLsWithPreferredBrowser:(NSArray<NSURL*>*)urls {
	// TODO: lookup preferred browser in user preferences
	if (urls.count == 0) return;
//	[[NSWorkspace sharedWorkspace] openURLs:urls withAppBundleIdentifier:@"com.apple.Safari" options:NSWorkspaceLaunchDefault additionalEventParamDescriptor:nil launchIdentifiers:nil];
}


#pragma mark - Iterating over items and propagating unread count


/**
 Perform a fetch request to the Core Data storage to retrieve the feed item associated with the @c representedObject.

 @param sender The @c NSMenuItem that contains the Core Data reference.
 @return Returns @c nil if the menu item has no @c representedObject or the contained class doesn't match.
 */
- (FeedConfig*)requestFeedConfigForMenuItem:(NSMenuItem*)sender {
	MenuItemInfo *info = sender.representedObject;
	if (![info isKindOfClass:[MenuItemInfo class]])
		return nil;
	id obj = [StoreCoordinator objectWithID:info.objID];
	if (![obj isKindOfClass:[FeedConfig class]])
		return nil;
	return obj;
}

/**
 Iterate over all feed items from siblings and contained children.

 @param sender @c NSMenuItem that was clicked during the action (e.g., "open all unread")
 @param block Iterate over all FeedItems on the deepest layer.
 */
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

/**
 Recursively update all parent's unread count and total unread count.

 @param sender Current menu item, parent will be called recursively on this element.
 @param count The amount by which the unread count is adjusted. If negative, items will be marked as unread.
 */
- (void)updateAcestors:(NSMenuItem*)sender markRead:(int)count {
	[sender markAncestorsRead:count];
	self.unreadCountTotal -= count;
	if (self.unreadCountTotal < 0) {
		NSLog(@"Should never happen. Global unread count < 0");
		self.unreadCountTotal = 0;
	}
	[self updateBarIcon];
}

/**
 Get unread count from the parent menu item. If there is none, get the total unread count

 @param sender Current menu item, parent will be called on this element.
 @return Unread count for parent element (total count if parent is @c nil)
 */
- (int)getAncestorUnreadCount:(NSMenuItem*)sender {
	if ([sender.parentItem.representedObject isKindOfClass:[MenuItemInfo class]])
		return sender.parentItem.unreadCount;
	return self.unreadCountTotal;
}

@end
