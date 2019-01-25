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
#import "UserPrefs.h"
#import "NSMenu+Ext.h"
#import "Constants.h"
#import "Feed+Ext.h"
#import "FeedGroup+Ext.h"


@interface BarMenu()
@property (strong) NSStatusItem *barItem;
@property (strong) Preferences *prefWindow;
@property (assign, atomic) NSInteger unreadCountTotal;
@property (assign) BOOL coreDataEmpty;
@property (weak) NSMenu *currentOpenMenu;
@property (strong) NSArray<NSManagedObjectID*> *objectIDsForMenu;
@property (strong) NSManagedObjectContext *readContext;
@end


@implementation BarMenu

- (instancetype)init {
	self = [super init];
	self.barItem = [NSStatusBar.systemStatusBar statusItemWithLength:NSVariableStatusItemLength];
	self.barItem.highlightMode = YES;
	self.barItem.menu = [NSMenu menuWithDelegate:self];
	
	// Unread counter
	self.unreadCountTotal = 0;
	[self updateBarIcon];
	[self asyncReloadUnreadCountAndUpdateBarIcon:nil];
	
	// Register for notifications
	[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(feedUpdated:) name:kNotificationFeedUpdated object:nil];
	[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(feedIconUpdated:) name:kNotificationFeedIconUpdated object:nil];
	[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(networkChanged:) name:kNotificationNetworkStatusChanged object:nil];
	[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(unreadCountChanged:) name:kNotificationTotalUnreadCountChanged object:nil];
	[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(asyncReloadUnreadCountAndUpdateBarIcon:) name:kNotificationTotalUnreadCountReset object:nil];
	return self;
}

- (void)dealloc {
	[[NSNotificationCenter defaultCenter] removeObserver:self];
}

#pragma mark - Update Menu Bar Icon

/**
 If notification has @c object use this object to set unread count directly.
 If @c object is @c nil perform core data fetch on total unread count and update icon.
 */
- (void)asyncReloadUnreadCountAndUpdateBarIcon:(NSNotification*)notify {
	if (notify.object) { // set unread count directly
		self.unreadCountTotal = [[notify object] integerValue];
		[self updateBarIcon];
	} else {
		dispatch_async(dispatch_get_main_queue(), ^{
			self.unreadCountTotal = [StoreCoordinator unreadCountForIndexPathString:nil];
			[self updateBarIcon];
		});
	}
}

/// Update menu bar icon and text according to unread count and user preferences.
- (void)updateBarIcon {
	dispatch_async(dispatch_get_main_queue(), ^{
		if (self.unreadCountTotal > 0 && [UserPrefs defaultYES:@"globalUnreadCount"]) {
			self.barItem.title = [NSString stringWithFormat:@"%ld", self.unreadCountTotal];
		} else {
			self.barItem.title = @"";
		}
		BOOL hasNet = [FeedDownload allowNetworkConnection];
		if (self.unreadCountTotal > 0 && hasNet && [UserPrefs defaultYES:@"tintMenuBarIcon"]) {
			self.barItem.image = [RSSIcon systemBarIcon:16 tint:[NSColor rssOrange] noConnection:!hasNet];
		} else {
			self.barItem.image = [RSSIcon systemBarIcon:16 tint:nil noConnection:!hasNet];
			self.barItem.image.template = YES;
		}
	});
}


#pragma mark - Notification callback methods


/**
 Callback method fired when network conditions change.

 @param notify Notification object contains a @c BOOL value indicating the current status.
 */
- (void)networkChanged:(NSNotification*)notify {
	BOOL available = [[notify object] boolValue];
	[self.barItem.menu itemWithTag:TagUpdateFeed].enabled = available;
	[self updateBarIcon];
}

/**
 Callback method fired when feeds have been updated and the total unread count needs update.

 @param notify Notification object contains the unread count difference to the current count. May be negative.
 */
- (void)unreadCountChanged:(NSNotification*)notify {
	self.unreadCountTotal += [[notify object] integerValue];
	[self updateBarIcon];
}

/// Callback method fired when feeds have been updated in the background.
- (void)feedUpdated:(NSNotification*)notify {
	[self updateFeed:notify.object updateIconOnly:NO];
}

- (void)feedIconUpdated:(NSNotification*)notify {
	[self updateFeed:notify.object updateIconOnly:YES];
}


#pragma mark - Rebuild menu after background feed update


/**
 Use this method to update a single menu item and all ancestors unread count.
 If the menu isn't currently open, nothing will happen.
 
 @param oid @c NSManagedObjectID must be a @c Feed instance object id.
 */
- (void)updateFeed:(NSManagedObjectID*)oid updateIconOnly:(BOOL)flag {
	if (self.barItem.menu.numberOfItems > 0) {
		// update items only if menu is already open (e.g., during background update)
		NSManagedObjectContext *moc = [StoreCoordinator createChildContext];
		Feed *feed = [moc objectWithID:oid];
		if ([feed isKindOfClass:[Feed class]]) {
			NSMenu *menu = [self fixUnreadCountForSubmenus:feed];
			if (!flag) [self rebuiltFeedArticle:feed inMenu:menu]; // deepest menu level, feed items
		}
		[moc reset];
	}
}

/**
 Go through all parent menus and reset the menu title and unread count

 @return @c NSMenu containing @c FeedArticle. Will be @c nil if user hasn't open the menu yet.
 */
- (nullable NSMenu*)fixUnreadCountForSubmenus:(Feed*)feed {
	NSMenu *menu = self.barItem.menu;
	[menu autoEnableMenuHeader:(self.unreadCountTotal > 0)];
	for (FeedGroup *parent in [feed.group allParents]) {
		NSInteger itemIndex = [menu feedDataOffset] + parent.sortIndex;
		NSMenuItem *item = [menu itemAtIndex:itemIndex];
		NSInteger unread = [item setTitleAndUnreadCount:parent];
		menu = item.submenu;
		
		if (parent == feed.group) {
			// Always set icon. Will flip warning icon to default icon if article count changes.
			item.image = [feed iconImage16];
			item.enabled = (feed.articles.count > 0);
			return menu;
		}
		
		if (!menu || menu.numberOfItems == 0)
			return nil;
		if (unread == 0) // if != 0 then 'setTitleAndUnreadCount' was successful (UserPrefs visible)
			unread = [menu coreDataUnreadCount];
		[menu autoEnableMenuHeader:(unread > 0)]; // of submenu but not articles menu (will be rebuild anyway)
	}
	return nil;
}

/**
 Remove all @c NSMenuItem in menu and generate new ones. items from @c feed.items.

 @param feed Corresponding @c Feed to @c NSMenu.
 @param menu Deepest menu level which contains only feed items.
 */
- (void)rebuiltFeedArticle:(Feed*)feed inMenu:(NSMenu*)menu {
	if (!menu || menu.numberOfItems == 0) // not opened yet
		return;
	if (self.currentOpenMenu != menu) {
		// if the menu isn't open, re-create it dynamically instead
		menu.itemArray.firstObject.parentItem.submenu = [menu cleanInstanceCopy];
	} else {
		[menu removeAllItems];
		[self insertDefaultHeaderForAllMenus:menu hasUnread:(feed.unreadCount > 0)];
		for (FeedArticle *fa in [feed sortedArticles]) {
			NSMenuItem *mi = [menu addItemWithTitle:@"" action:@selector(openFeedURL:) keyEquivalent:@""];
			mi.target = self;
			[mi setFeedArticle:fa];
		}
	}
}


#pragma mark - Menu Delegate & Menu Generation


/// @c currentOpenMenu is needed when a background update occurs. In case a feed items menu is open.
- (void)menuWillOpen:(NSMenu *)menu {
	self.currentOpenMenu = menu;
}

/// Get rid of everything that is not needed when the system bar menu is closed.
- (void)menuDidClose:(NSMenu*)menu {
	self.currentOpenMenu = nil;
	if ([menu isMainMenu])
		self.barItem.menu = [NSMenu menuWithDelegate:self];
}

/**
 @note Delegate method not used. Here to prevent weird @c NSMenu behavior.
 Otherwise, Cmd-Q (Quit) and Cmd-, (Preferences) will traverse all submenus.
 Try yourself with @c NSLog() in @c numberOfItemsInMenu: and @c menuDidClose:
 */
- (BOOL)menuHasKeyEquivalent:(NSMenu *)menu forEvent:(NSEvent *)event target:(id  _Nullable __autoreleasing *)target action:(SEL  _Nullable *)action {
	return NO;
}

/// Perform a core data fatch request, store sorted object ids array and return object count.
- (NSInteger)numberOfItemsInMenu:(NSMenu*)menu {
	[self prepareContextAndTemporaryObjectIDs:menu];
	if (_coreDataEmpty) return 1; // only if main menu empty
	return (NSInteger)self.objectIDsForMenu.count;
}

/// Lazy populate system bar menus when needed.
- (BOOL)menu:(NSMenu*)menu updateItem:(NSMenuItem*)item atIndex:(NSInteger)index shouldCancel:(BOOL)shouldCancel {
	if (_coreDataEmpty) {
		item.title = NSLocalizedString(@"~~~ list empty ~~~", nil);
		item.enabled = NO;
		[self finalizeMenu:menu object:nil];
		return YES;
	}
	id obj = [self.readContext objectWithID:[self.objectIDsForMenu objectAtIndex:(NSUInteger)index]];
	if ([obj isKindOfClass:[FeedGroup class]]) {
		[item setFeedGroup:obj];
		if ([(FeedGroup*)obj type] == FEED)
			[item setTarget:self action:@selector(openFeedURL:)];
	} else if ([obj isKindOfClass:[FeedArticle class]]) {
		[item setFeedArticle:obj];
		[item setTarget:self action:@selector(openFeedURL:)];
	}
	
	if (index + 1 == menu.numberOfItems) { // last item of the menu
		[self finalizeMenu:menu object:obj];
		[self resetContextAndTemporaryObjectIDs];
	}
	return YES;
}


#pragma mark - Helper


- (void)prepareContextAndTemporaryObjectIDs:(NSMenu*)menu {
	NSMenuItem *parent = [menu.supermenu itemAtIndex:[menu.supermenu indexOfItemWithSubmenu:menu]];
	self.readContext = [StoreCoordinator createChildContext]; // will be deleted after menu:updateItem:
	self.objectIDsForMenu = [StoreCoordinator sortedObjectIDsForParent:parent.representedObject isFeed:[menu isFeedMenu] inContext:self.readContext];
	_coreDataEmpty = ([menu isMainMenu] && self.objectIDsForMenu.count == 0); // initial state or no feeds in date store
}

- (void)resetContextAndTemporaryObjectIDs {
	self.objectIDsForMenu = nil;
	[self.readContext reset];
	self.readContext = nil;
}

/**
 Add default menu items that are present in each menu as header and disable menu items if necessary
 */
- (void)finalizeMenu:(NSMenu*)menu object:(id)obj {
	NSInteger unreadCount = self.unreadCountTotal; // if parent == nil
	if ([menu isFeedMenu]) {
		unreadCount = ((FeedArticle*)obj).feed.unreadCount;
	} else if (![menu isMainMenu]) {
		unreadCount = [menu coreDataUnreadCount];
	}
	[menu replaceSeparatorStringsWithActualSeparator];
	[self insertDefaultHeaderForAllMenus:menu hasUnread:(unreadCount > 0)];
	if ([menu isMainMenu])
		[self insertMainMenuHeader:menu];
}

/**
 Insert items 'Open all unread', 'Mark all read' and 'Mark all unread' at index 0.

 @param flag If @c NO, 'Open all unread' and 'Mark all read' will be disabled.
 */
- (void)insertDefaultHeaderForAllMenus:(NSMenu*)menu hasUnread:(BOOL)flag {
	MenuItemTag scope = [menu scope];
	NSMenuItem *item1 = [NSMenuItem itemWithTitle:NSLocalizedString(@"Open all unread", nil)
										   action:@selector(openAllUnread:) target:self tag:TagOpenAllUnread | scope];
	NSMenuItem *item2 = [item1 alternateWithTitle:[NSString stringWithFormat:@"%@ (%lu)",
												   NSLocalizedString(@"Open a few unread", nil), [UserPrefs openFewLinksLimit]]];
	NSMenuItem *item3 = [NSMenuItem itemWithTitle:NSLocalizedString(@"Mark all read", nil)
										   action:@selector(markAllReadOrUnread:) target:self tag:TagMarkAllRead | scope];
	NSMenuItem *item4 = [NSMenuItem itemWithTitle:NSLocalizedString(@"Mark all unread", nil)
										   action:@selector(markAllReadOrUnread:) target:self tag:TagMarkAllUnread | scope];
	item1.enabled = flag;
	item2.enabled = flag;
	item3.enabled = flag;
	// TODO: disable item3 if all items are unread?
	[menu insertItem:item1 atIndex:0];
	[menu insertItem:item2 atIndex:1];
	[menu insertItem:item3 atIndex:2];
	[menu insertItem:item4 atIndex:3];
	[menu insertItem:[NSMenuItem separatorItem] atIndex:4];
}

/**
 Insert default menu items for the main menu only. Like 'Pause Updates', 'Update all feeds', 'Preferences' and 'Quit'.
 */
- (void)insertMainMenuHeader:(NSMenu*)menu {
	NSMenuItem *item1 = [NSMenuItem itemWithTitle:@"" action:@selector(pauseUpdates:) target:self tag:TagPauseUpdates];
	NSMenuItem *item2 = [NSMenuItem itemWithTitle:NSLocalizedString(@"Update all feeds", nil)
										   action:@selector(updateAllFeeds:) target:self tag:TagUpdateFeed];
	item1.title = ([FeedDownload isPaused] ?
				   NSLocalizedString(@"Resume Updates", nil) : NSLocalizedString(@"Pause Updates", nil));
	if ([UserPrefs defaultYES:@"globalUpdateAll"] == NO)
		item2.hidden = YES;
	if (![FeedDownload allowNetworkConnection])
		item2.enabled = NO;
	[menu insertItem:item1 atIndex:0];
	[menu insertItem:item2 atIndex:1];
	[menu insertItem:[NSMenuItem separatorItem] atIndex:2];
	// < feed content >
	[menu addItem:[NSMenuItem separatorItem]];
	NSMenuItem *prefs = [NSMenuItem itemWithTitle:NSLocalizedString(@"Preferences", nil)
										   action:@selector(openPreferences) target:self tag:TagPreferences];
	prefs.keyEquivalent = @",";
	[menu addItem:prefs];
	[menu addItemWithTitle:NSLocalizedString(@"Quit", nil) action:@selector(terminate:) keyEquivalent:@"q"];
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

/**
 Callback method after user closes the preferences window.
 */
- (void)preferencesClosed:(id)sender {
	[[NSNotificationCenter defaultCenter] removeObserver:self name:NSWindowWillCloseNotification object:self.prefWindow.window];
	self.prefWindow = nil;
	[FeedDownload scheduleUpdateForUpcomingFeeds];
}

/**
 Called when user clicks on 'Pause Updates' in the main menu (only).
 */
- (void)pauseUpdates:(NSMenuItem*)sender {
	[FeedDownload setPaused:![FeedDownload isPaused]];
	[self updateBarIcon];
}

/**
 Called when user clicks on 'Update all feeds' in the main menu (only).
 */
- (void)updateAllFeeds:(NSMenuItem*)sender {
	[self asyncReloadUnreadCountAndUpdateBarIcon:nil];
	[FeedDownload forceUpdateAllFeeds];
}

/**
 Called when user clicks on 'Open all unread' or 'Open a few unread ...' on any scope level.
 */
- (void)openAllUnread:(NSMenuItem*)sender {
	NSMutableArray<NSURL*> *urls = [NSMutableArray<NSURL*> array];
	__block int maxItemCount = INT_MAX;
	if (sender.isAlternate)
		maxItemCount = (int)[UserPrefs openFewLinksLimit];
	
	NSManagedObjectContext *moc = [StoreCoordinator createChildContext];
	[sender iterateSorted:YES inContext:moc overDescendentFeeds:^(Feed *feed, BOOL *cancel) {
		for (FeedArticle *fa in [feed sortedArticles]) { // TODO: open oldest articles first?
			if (maxItemCount <= 0) break;
			if (fa.unread && fa.link.length > 0) {
				[urls addObject:[NSURL URLWithString:fa.link]];
				fa.unread = NO;
				feed.unreadCount -= 1;
				self.unreadCountTotal -= 1;
				maxItemCount -= 1;
			}
		}
		*cancel = (maxItemCount <= 0);
	}];
	[self updateBarIcon];
	[self openURLsWithPreferredBrowser:urls];
	[StoreCoordinator saveContext:moc andParent:YES];
	[moc reset];
}

/**
 Called when user clicks on 'Mark all read' @b or 'Mark all unread' on any scope level.
 */
- (void)markAllReadOrUnread:(NSMenuItem*)sender {
	BOOL markRead = ((sender.tag & TagMaskType) == TagMarkAllRead);
	NSManagedObjectContext *moc = [StoreCoordinator createChildContext];
	[sender iterateSorted:NO inContext:moc overDescendentFeeds:^(Feed *feed, BOOL *cancel) {
		self.unreadCountTotal += (markRead ? [feed markAllItemsRead] : [feed markAllItemsUnread]);
	}];
	[self updateBarIcon];
	[StoreCoordinator saveContext:moc andParent:YES];
	[moc reset];
}

/**
 Called when user clicks on a single feed item or the feed group.

 @param sender A menu item containing either a @c FeedArticle or a @c FeedGroup objectID.
 */
- (void)openFeedURL:(NSMenuItem*)sender {
	NSManagedObjectID *oid = sender.representedObject;
	if (!oid)
		return;
	NSString *url = nil;
	NSManagedObjectContext *moc = [StoreCoordinator createChildContext];
	id obj = [moc objectWithID:oid];
	if ([obj isKindOfClass:[FeedGroup class]]) {
		url = ((FeedGroup*)obj).feed.link;
	} else if ([obj isKindOfClass:[FeedArticle class]]) {
		FeedArticle *fa = obj;
		url = fa.link;
		if (fa.unread) {
			fa.unread = NO;
			fa.feed.unreadCount -= 1;
			self.unreadCountTotal -= 1;
			[self updateBarIcon];
			[StoreCoordinator saveContext:moc andParent:YES];
		}
	}
	[moc reset];
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

@end
