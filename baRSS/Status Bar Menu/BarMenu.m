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
#import "FeedDownload.h"
#import "DrawImage.h"
#import "Preferences.h"
#import "NSMenuItem+Info.h"
#import "NSMenuItem+Generate.h"
#import "UserPrefs.h"


@interface BarMenu()
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
	[self rebuildMenu];
	[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(networkChange:) name:@"baRSS-notification-network-status-change" object:nil];
	[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(feedUpdated:) name:@"baRSS-notification-feed-updated" object:nil];
	[FeedDownload registerNetworkChangeNotification];
	[FeedDownload performSelectorInBackground:@selector(scheduleNextUpdate:) withObject:[NSNumber numberWithBool:NO]];
	return self;
}

- (void)dealloc {
	[FeedDownload unregisterNetworkChangeNotification];
	[[NSNotificationCenter defaultCenter] removeObserver:self];
}

- (void)networkChange:(NSNotification*)notify {
	BOOL available = [[notify object] boolValue];
	[self.barItem.menu itemWithTag:TagUpdateFeed].enabled = available;
	[self updateBarIcon];
	// TODO: Disable 'update all' menu item?
}

- (void)feedUpdated:(NSNotification*)notify {
	FeedConfig *config = notify.object;
	NSLog(@"%@", config.indexPath);
	[self rebuildMenu];
}

- (void)rebuildMenu {
	self.barItem.menu = [self generateMainMenu];
	[self updateBarIcon];
}

- (void)donothing {
	dispatch_async(dispatch_get_main_queue(), ^{
		[self.mm itemAtIndex:4].title = [NSString stringWithFormat:@"%@", [NSDate date]];
	});
	sleep(1);
	[self performSelectorInBackground:@selector(donothing) withObject:nil];
}
// TODO: remove debugging stuff
- (void)printUnreadRecurisve:(NSMenu*)menu str:(NSString*)prefix {
	for (NSMenuItem *item in menu.itemArray) {
		if (![item hasReaderInfo]) continue;
		id obj = [item requestCoreDataObject];
		if ([obj isKindOfClass:[FeedItem class]] && ([obj unread] > 0 || item.unreadCount > 0))
			NSLog(@"%@ %@ (%d == %d)", prefix, item.title, item.unreadCount, [obj unread]);
		else if ([item hasUnread])
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
	// TODO: Option: icon choice
	// TODO: Show paused icon if no internet connection
	dispatch_async(dispatch_get_main_queue(), ^{
		if (self.unreadCountTotal > 0 && [UserPrefs defaultYES:@"globalUnreadCount"]) {
			self.barItem.title = [NSString stringWithFormat:@"%d", self.unreadCountTotal];
		} else {
			self.barItem.title = @"";
		}
		// BOOL hasNet = [FeedDownload isNetworkReachable];
		if (self.unreadCountTotal > 0 && [UserPrefs defaultYES:@"tintMenuBarIcon"]) {
			self.barItem.image = [RSSIcon templateIcon:16 tint:[NSColor rssOrange]];
		} else {
			self.barItem.image = [RSSIcon templateIcon:16 tint:nil];
			self.barItem.image.template = YES;
		}
	});
//	NSLog(@"==> %d", self.unreadCountTotal);
//	[self printUnreadRecurisve:self.barItem.menu str:@""];
}


#pragma mark - Menu Generator


/**
 Builds main menu with items on the very first menu level. Including Preferences, Quit, etc.
 */
- (NSMenu*)generateMainMenu {
	NSMenu *menu = [NSMenu new];
	menu.autoenablesItems = NO;
	[self addTitle:NSLocalizedString(@"Pause Updates", nil) selector:@selector(pauseUpdates:) toMenu:menu tag:TagPauseUpdates];
	NSMenuItem *updateAll = [self addTitle:NSLocalizedString(@"Update all feeds", nil) selector:@selector(updateAllFeeds:) toMenu:menu tag:TagUpdateFeed];
	if ([UserPrefs defaultYES:@"globalUpdateAll"] == NO)
		updateAll.hidden = YES;
	
	[menu addItem:[NSMenuItem separatorItem]];
	[self defaultHeaderForMenu:menu scope:ScopeGlobal];
	
	self.unreadCountTotal = 0;
	@autoreleasepool {
		for (FeedConfig *fc in [StoreCoordinator sortedFeedConfigItems]) {
			[menu addItem:[self generateMenuItem:fc unread:&_unreadCountTotal]];
		}
	}
	[self updateMenuHeaderEnabled:menu hasUnread:(self.unreadCountTotal > 0)];
	
	[menu addItem:[NSMenuItem separatorItem]];
	
	NSMenuItem *prefs = [self addTitle:NSLocalizedString(@"Preferences", nil) selector:@selector(openPreferences) toMenu:menu tag:TagPreferences];
	prefs.keyEquivalent = @",";
	[menu addItemWithTitle:NSLocalizedString(@"Quit", nil) action:@selector(terminate:) keyEquivalent:@"q"];
	return menu;
}

/**
 Generate menu item with all its sub-menus. @c FeedConfig type is evaluated automatically.

 @param unread Pointer to an unread count. Will be incremented while traversing through sub-menus.
 */
- (NSMenuItem*)generateMenuItem:(FeedConfig*)config unread:(int*)unread {
	NSMenuItem *item = [NSMenuItem feedConfig:config];
	int count = 0;
	if (item.tag == ScopeFeed) {
		count += [self setSubmenuForFeedScope:item config:config];
	} else if (item.tag == ScopeGroup) {
		[self setSubmenuForGroupScope:item config:config unread:&count];
	} else { // Separator item
		return item;
	}
	*unread += count;
	[item markReadAndUpdateTitle:-count];
	[self updateMenuHeaderEnabled:item.submenu hasUnread:(count > 0)];
	return item;
}

/**
 Set subitems for a @c FeedConfig group item. Namely various @c FeedConfig and @c FeedItem items.

 @param item The item where the menu will be appended.
 @param config A @c FeedConfig group item.
 @param unread Pointer to an unread count. Will be incremented while traversing through sub-menus.
 */
- (void)setSubmenuForGroupScope:(NSMenuItem*)item config:(FeedConfig*)config unread:(int*)unread {
	item.submenu = [self defaultHeaderForMenu:nil scope:ScopeGroup];
	for (FeedConfig *obj in config.sortedChildren) {
		[item.submenu addItem: [self generateMenuItem:obj unread:unread]];
	}
}

/**
 Set subitems for a @c FeedConfig feed item. Namely its @c FeedItem items.

 @param item The item where the menu will be appended.
 @param config For which item the menu should be generated. Attribute @c feed should be populated.
 @return Unread count for feed.
 */
- (int)setSubmenuForFeedScope:(NSMenuItem*)item config:(FeedConfig*)config {
	item.submenu = [self defaultHeaderForMenu:nil scope:ScopeFeed];
	int count = 0;
	for (FeedItem *obj in config.feed.items) {
		if (obj.unread) ++count;
		[item.submenu addItem:[[NSMenuItem feedItem:obj] setAction:@selector(openFeedURL:) target:self]];
	}
	[item setAction:@selector(openFeedURL:) target:self];
	return count;
}

/**
 Helper function to insert a menu item with @c target @c = @c self
 */
- (NSMenuItem*)addTitle:(NSString*)title selector:(SEL)selector toMenu:(NSMenu*)menu tag:(MenuItemTag)tag {
	NSMenuItem *item = [[NSMenuItem alloc] initWithTitle:title action:selector keyEquivalent:@""];
	item.target = self;
	item.tag = tag;
	[item applyUserSettingsDisplay];
	[menu addItem:item];
	return item;
}


#pragma mark - Default Menu Header Items


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
	
	NSMenuItem *item = [self addTitle:NSLocalizedString(@"Open all unread", nil) selector:@selector(openAllUnread:) toMenu:menu tag:TagOpenAllUnread | scope];
	[menu addItem:[item alternateWithTitle:[NSString stringWithFormat:NSLocalizedString(@"Open a few unread (%d)", nil), 3]]];
	[self addTitle:NSLocalizedString(@"Mark all read", nil) selector:@selector(markAllRead:) toMenu:menu tag:TagMarkAllRead | scope];
	[self addTitle:NSLocalizedString(@"Mark all unread", nil) selector:@selector(markAllUnread:) toMenu:menu tag:TagMarkAllUnread | scope];
	
	[menu addItem:[NSMenuItem separatorItem]];
	return menu;
}

- (void)setItemUpdateAllHidden:(BOOL)hidden {
	[self.barItem.menu itemWithTag:TagUpdateFeed].hidden = hidden;
}

- (void)updateMenuHeaders:(BOOL)recursive {
	[self updateMenuHeaderHidden:self.barItem.menu recursive:recursive];
}

- (void)updateMenuHeaderHidden:(NSMenu*)menu recursive:(BOOL)flag {
	for (NSMenuItem *item in menu.itemArray) {
		[item applyUserSettingsDisplay];
		if (flag && item.hasSubmenu) {
			[self updateMenuHeaderHidden:item.submenu recursive:YES];
		}
	}
}

- (void)updateMenuHeaderEnabled:(NSMenu*)menu hasUnread:(BOOL)flag {
	int stopAfter = 4; // 3 (+1 alternate)
	for (NSMenuItem *item in menu.itemArray) {
		switch (item.tag & TagMaskType) {
			case TagMarkAllRead:   item.enabled = flag; break;
			case TagMarkAllUnread: item.enabled = !flag; break;
			case TagOpenAllUnread: item.enabled = flag; break;
			default: continue; // wrong tag, ignore
		}
		--stopAfter;
		if (stopAfter < 0)
			break; // break early after all header items have been processed
	}
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
		[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(preferencesClosed:) name:NSWindowWillCloseNotification object:self.prefWindow.window];
	}
	[NSApp activateIgnoringOtherApps:YES];
	[self.prefWindow showWindow:nil];
}

- (void)preferencesClosed:(id)sender {
	[[NSNotificationCenter defaultCenter] removeObserver:self name:NSWindowWillCloseNotification object:self.prefWindow.window];
	self.prefWindow = nil;
}


- (void)pauseUpdates:(NSMenuItem*)sender {
	NSLog(@"1pause");
}

- (void)updateAllFeeds:(NSMenuItem*)sender {
	// TODO: Disable 'update all' menu item during update?
	[FeedDownload scheduleNextUpdate:YES];
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
		if (item.tag & ScopeFeed) {
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
	if (!sender.hasReaderInfo)
		return;
	NSString *url = nil;
	id obj = [sender requestCoreDataObject];
	if ([obj isKindOfClass:[FeedConfig class]]) {
		url = [[(FeedConfig*)obj feed] link];
	} else if ([obj isKindOfClass:[FeedItem class]]) {
		FeedItem *feed = obj;
		url = [feed link];
		if ([sender hasUnread]) {
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
	if (urls.count == 0) return;
	[[NSWorkspace sharedWorkspace] openURLs:urls withAppBundleIdentifier:[UserPrefs getHttpApplication] options:NSWorkspaceLaunchDefault additionalEventParamDescriptor:nil launchIdentifiers:nil];
}


#pragma mark - Iterating over items and propagating unread count


/**
 Iterate over all feed items from siblings and contained children.

 @param sender @c NSMenuItem that was clicked during the action (e.g., "open all unread")
 @param block Iterate over all FeedItems on the deepest layer.
 */
- (void)siblingsDescendantFeedConfigs:(NSMenuItem*)sender block:(FeedConfigRecursiveItemsBlock)block {
	if (sender.parentItem) {
		FeedConfig *obj = [sender.parentItem requestCoreDataObject];
		if ([obj isKindOfClass:[FeedConfig class]]) // important: this could be a FeedItem
			[obj descendantFeedItems:block];
	} else {
		// Sadly we can't just fetch the list of FeedItems since it is not ordered (in case open 10 at a time)
		@autoreleasepool {
			for (FeedConfig *config in [StoreCoordinator sortedFeedConfigItems]) {
				if ([config descendantFeedItems:block] == NO)
					break;
			}
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
	if ([sender.parentItem hasReaderInfo])
		return [sender.parentItem unreadCount];
	return self.unreadCountTotal;
}

@end
