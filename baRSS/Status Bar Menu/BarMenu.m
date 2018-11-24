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
#import "NSMenuItem+Ext.h"
#import "Feed+Ext.h"
#import "Constants.h"


@interface BarMenu()
@property (strong) NSStatusItem *barItem;
@property (strong) Preferences *prefWindow;
@property (assign) int unreadCountTotal;
@property (strong) NSArray<FeedConfig*> *allFeeds;
@property (strong) NSArray<NSManagedObjectID*> *currentOpenMenu;
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
	dispatch_async(dispatch_get_main_queue(), ^{
		self.unreadCountTotal = [StoreCoordinator totalNumberOfUnreadFeeds];
		[self updateBarIcon];
	});
	
	// Register for notifications
	[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(feedUpdated:) name:kNotificationFeedUpdated object:nil];
	[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(networkChanged:) name:kNotificationNetworkStatusChanged object:nil];
	[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(unreadCountChanged:) name:kNotificationTotalUnreadCountChanged object:nil];
	[FeedDownload registerNetworkChangeNotification];
	[FeedDownload performSelectorInBackground:@selector(scheduleNextUpdate:) withObject:[NSNumber numberWithBool:NO]];
	return self;
}

- (void)dealloc {
	[FeedDownload unregisterNetworkChangeNotification];
	[[NSNotificationCenter defaultCenter] removeObserver:self];
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
}


#pragma mark - Notification callback methods -


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
	self.unreadCountTotal += [[notify object] intValue];
	[self updateBarIcon];
}

/**
 Callback method fired when feeds have been updated in the background.
 */
- (void)feedUpdated:(NSNotification*)notify {
	if (self.barItem.menu.numberOfItems > 0) {
		// update items only if menu is already open (e.g., during background update)
		[self.readContext refreshAllObjects]; // because self.allFeeds is the same context
		[self recursiveUpdateMenu:self.barItem.menu withFeed:nil];
	}
}

/**
 Called recursively for all @c FeedConfig children.
 If the projected submenu in @c menu does not exist, all subsequent children are skipped in @c FeedConfig.
 The title and unread count is updated for all menu items. @c FeedItem menus are completely re-generated.

 @param config If @c nil the root object (@c self.allFeeds) is used.
 */
- (void)recursiveUpdateMenu:(NSMenu*)menu withFeed:(FeedConfig*)config {
	if (config.feed.items.count > 0) { // deepest menu level, feed items
		[menu removeAllItems];
		[self insertDefaultHeaderForAllMenus:menu scope:ScopeFeed hasUnread:(config.unreadCount > 0)];
		for (FeedItem *fi in config.feed.items) {
			NSMenuItem *mi = [menu addItemWithTitle:@"" action:@selector(openFeedURL:) keyEquivalent:@""];
			mi.target = self;
			[mi setFeedItem:fi];
		}
	} else {
		BOOL hasUnread = (config ? config.unreadCount > 0 : self.unreadCountTotal > 0);
		NSInteger offset = [menu getFeedConfigOffsetAndUpdateUnread:hasUnread];
		for (FeedConfig *child in (config ? config.children : self.allFeeds)) {
			NSMenuItem *item = [menu itemAtIndex:offset + child.sortIndex];
			[item setTitleAndUnreadCount:child];
			if (item.submenu.numberOfItems > 0)
				[self recursiveUpdateMenu:[item submenu] withFeed:child];
		}
	}
}


#pragma mark - Menu Delegate & Menu Generation -


// Get rid of everything that is not needed when the system bar menu isnt open.
- (void)menuDidClose:(NSMenu*)menu {
	if ([menu isMainMenu]) {
		self.allFeeds = nil;
		[self.readContext reset];
		self.readContext = nil;
		self.barItem.menu = [NSMenu menuWithDelegate:self];
	}
}

// If main menu load inital set of items, then find item based on index path.
- (NSInteger)numberOfItemsInMenu:(NSMenu*)menu {
	if ([menu isMainMenu]) {
		[self.readContext reset]; // will be ignored if nil
		self.readContext = [StoreCoordinator createChildContext];
		self.allFeeds = [StoreCoordinator sortedFeedConfigItemsInContext:self.readContext];
		self.currentOpenMenu = [self.allFeeds valueForKeyPath:@"objectID"];
	} else {
		FeedConfig *conf = [self configAtIndexPathStr:menu.title];
		[self.readContext refreshObject:conf mergeChanges:YES];
		self.currentOpenMenu = [(conf.typ == FEED ? conf.feed.items : [conf sortedChildren]) valueForKeyPath:@"objectID"];
	}
	return (NSInteger)[self.currentOpenMenu count];
}

/**
 Find @c FeedConfig item in array @c self.allFeeds that is already loaded.

 @param indexString Path as string that is stored in @c NSMenu title
 */
- (FeedConfig*)configAtIndexPathStr:(NSString*)indexString {
	NSArray<NSString*> *parts = [indexString componentsSeparatedByString:@"."];
	NSInteger firstIndex = [[parts objectAtIndex:1] integerValue];
	FeedConfig *changing = [self.allFeeds objectAtIndex:(NSUInteger)firstIndex];
	for (NSUInteger i = 2; i < parts.count; i++) {
		NSInteger childIndex = [[parts objectAtIndex:i] integerValue];
		BOOL err = YES;
		for (FeedConfig *c in changing.children) {
			if (c.sortIndex == childIndex) {
				err = NO;
				changing = c;
				break; // Exit early. Should be faster than sorted children method.
			}
		}
		NSAssert(!err, @"ERROR configAtIndex: Shouldn't happen. Something wrong with indexing.");
	}
	return changing;
}

// Lazy populate the system bar menus when needed.
- (BOOL)menu:(NSMenu*)menu updateItem:(NSMenuItem*)item atIndex:(NSInteger)index shouldCancel:(BOOL)shouldCancel {
	NSManagedObjectID *moid = [self.currentOpenMenu objectAtIndex:(NSUInteger)index];
	id obj = [self.readContext objectWithID:moid];
	[self.readContext refreshObject:obj mergeChanges:YES];
	
	if ([obj isKindOfClass:[FeedConfig class]]) {
		[item setFeedConfig:obj];
		if ([(FeedConfig*)obj typ] == FEED) {
			item.target = self;
			item.action = @selector(openFeedURL:);
		}
	} else if ([obj isKindOfClass:[FeedItem class]]) {
		[item setFeedItem:obj];
		item.target = self;
		item.action = @selector(openFeedURL:);
	}
	if (menu.numberOfItems == index + 1) {
		int unreadCount = self.unreadCountTotal; // if parent == nil
		if ([obj isKindOfClass:[FeedItem class]]) {
			unreadCount = [[[(FeedItem*)obj feed] config] unreadCount];
		} else if ([(FeedConfig*)obj parent]) {
			unreadCount = [[(FeedConfig*)obj parent] unreadCount];
		}
		[self finalizeMenu:menu hasUnread:(unreadCount > 0)];
		self.currentOpenMenu = nil;
	}
	return YES;
}

/**
 Add default menu items that are present in each menu as header.

 @param flag If @c NO, 'Open all unread' and 'Mark all read' will be disabled.
 */
- (void)finalizeMenu:(NSMenu*)menu hasUnread:(BOOL)flag {
	BOOL isMainMenu = [menu isMainMenu];
	MenuItemTag scope;
	if (isMainMenu)              scope = ScopeGlobal;
	else if ([menu isFeedMenu])  scope = ScopeFeed;
	else                         scope = ScopeGroup;
	
	[menu replaceSeparatorStringsWithActualSeparator];
	[self insertDefaultHeaderForAllMenus:menu scope:scope hasUnread:flag];
	if (isMainMenu) {
		[self insertMainMenuHeader:menu];
	}
}

/**
 Insert items 'Open all unread', 'Mark all read' and 'Mark all unread' at index 0.

 @param flag If @c NO, 'Open all unread' and 'Mark all read' will be disabled.
 */
- (void)insertDefaultHeaderForAllMenus:(NSMenu*)menu scope:(MenuItemTag)scope hasUnread:(BOOL)flag {
	NSMenuItem *item1 = [self itemTitle:NSLocalizedString(@"Open all unread", nil) selector:@selector(openAllUnread:) tag:TagOpenAllUnread | scope];
	NSMenuItem *item2 = [item1 alternateWithTitle:[NSString stringWithFormat:NSLocalizedString(@"Open a few unread (%d)", nil), 3]];
	NSMenuItem *item3 = [self itemTitle:NSLocalizedString(@"Mark all read", nil) selector:@selector(markAllReadOrUnread:) tag:TagMarkAllRead | scope];
	NSMenuItem *item4 = [self itemTitle:NSLocalizedString(@"Mark all unread", nil) selector:@selector(markAllReadOrUnread:) tag:TagMarkAllUnread | scope];
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
	NSMenuItem *item1 = [self itemTitle:NSLocalizedString(@"Pause Updates", nil) selector:@selector(pauseUpdates:) tag:TagPauseUpdates];
	NSMenuItem *item2 = [self itemTitle:NSLocalizedString(@"Update all feeds", nil) selector:@selector(updateAllFeeds:) tag:TagUpdateFeed];
	if ([UserPrefs defaultYES:@"globalUpdateAll"] == NO)
		item2.hidden = YES;
	if (![FeedDownload isNetworkReachable])
		item2.enabled = NO;
	[menu insertItem:item1 atIndex:0];
	[menu insertItem:item2 atIndex:1];
	[menu insertItem:[NSMenuItem separatorItem] atIndex:2];
	// < feed content >
	[menu addItem:[NSMenuItem separatorItem]];
	NSMenuItem *prefs = [self itemTitle:NSLocalizedString(@"Preferences", nil) selector:@selector(openPreferences) tag:TagPreferences];
	prefs.keyEquivalent = @",";
	[menu addItem:prefs];
	[menu addItemWithTitle:NSLocalizedString(@"Quit", nil) action:@selector(terminate:) keyEquivalent:@"q"];
}

/**
 Helper method to generate a new @c NSMenuItem.
 */
- (NSMenuItem*)itemTitle:(NSString*)title selector:(SEL)selector tag:(MenuItemTag)tag {
	NSMenuItem *item = [[NSMenuItem alloc] initWithTitle:title action:selector keyEquivalent:@""];
	item.target = self;
	item.tag = tag;
	[item applyUserSettingsDisplay];
	return item;
}


#pragma mark - Menu Actions -


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
}

/**
 Called when user clicks on 'Pause Updates' in the main menu (only).
 */
- (void)pauseUpdates:(NSMenuItem*)sender {
	NSLog(@"1pause");
}

/**
 Called when user clicks on 'Update all feeds' in the main menu (only).
 */
- (void)updateAllFeeds:(NSMenuItem*)sender {
	// TODO: Disable 'update all' menu item during update?
	[FeedDownload scheduleNextUpdate:YES];
}

/**
 Called when user clicks on 'Open all unread' or 'Open a few unread ...' on any scope level.
 */
- (void)openAllUnread:(NSMenuItem*)sender {
	NSMutableArray<NSURL*> *urls = [NSMutableArray<NSURL*> array];
	__block int maxItemCount = INT_MAX;
	if (sender.isAlternate)
		maxItemCount = 3; // TODO: read from preferences
	
	NSManagedObjectContext *moc = [StoreCoordinator createChildContext];
	[sender iterateSorted:YES inContext:moc overDescendentFeeds:^(Feed *feed, BOOL *cancel) {
		int itemSum = 0;
		for (FeedItem *i in feed.items) {
			if (itemSum >= maxItemCount) {
				break;
			}
			if (i.unread && i.link.length > 0) {
				[urls addObject:[NSURL URLWithString:i.link]];
				i.unread = NO;
				++itemSum;
			}
		}
		if (itemSum > 0) {
			[feed.config markUnread:-itemSum ancestorsOnly:NO];
			maxItemCount -= itemSum;
		}
		*cancel = (maxItemCount <= 0);
	}];
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
		if (markRead) [feed markAllItemsRead];
		else          [feed markAllItemsUnread];
	}];
	[StoreCoordinator saveContext:moc andParent:YES];
	[moc reset];
}

/**
 Called when user clicks on a single feed item or the feed group.

 @param sender A menu item containing either a @c FeedItem or a @c FeedConfig objectID.
 */
- (void)openFeedURL:(NSMenuItem*)sender {
	NSManagedObjectID *oid = sender.representedObject;
	if (!oid)
		return;
	NSString *url = nil;
	NSManagedObjectContext *moc = [StoreCoordinator createChildContext];
	id obj = [moc objectWithID:oid];
	if ([obj isKindOfClass:[FeedConfig class]]) {
		url = [[(FeedConfig*)obj feed] link];
	} else if ([obj isKindOfClass:[FeedItem class]]) {
		FeedItem *feed = obj;
		url = [feed link];
		if (feed.unread) {
			feed.unread = NO;
			[feed.feed.config markUnread:-1 ancestorsOnly:NO];
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
