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
#import "Constants.h"
#import "UserPrefs.h"
#import "NSMenu+Ext.h"
#import "BarStatusItem.h"
#import "MapUnreadTotal.h"
#import "StoreCoordinator.h"
#import "Feed+Ext.h"
#import "FeedArticle+Ext.h"


@interface BarMenu()
@property (weak) BarStatusItem *statusItem;
@property (strong) MapUnreadTotal *unreadMap;
@end


@implementation BarMenu

- (instancetype)initWithStatusItem:(BarStatusItem*)statusItem {
	self = [super init];
	self.statusItem = statusItem;
	// TODO: move unread counts to status item and keep in sync when changing feeds in preferences
	self.unreadMap = [[MapUnreadTotal alloc] initWithCoreData: [StoreCoordinator countAggregatedUnread]];
	// Register for notifications
	[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(feedUpdated:) name:kNotificationFeedUpdated object:nil];
	[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(feedIconUpdated:) name:kNotificationFeedIconUpdated object:nil];
	return self;
}

- (void)dealloc {
	[[NSNotificationCenter defaultCenter] removeObserver:self];
}


#pragma mark - Generate Menu Items

/**
 @note Delegate method not used. Here to prevent weird @c NSMenu behavior.
 Otherwise, Cmd-Q (Quit) and Cmd-, (Preferences) will traverse all submenus.
 Try yourself with @c NSLog() in @c numberOfItemsInMenu: and @c menuDidClose:
 */
- (BOOL)menuHasKeyEquivalent:(NSMenu *)menu forEvent:(NSEvent *)event target:(id  _Nullable __autoreleasing *)target action:(SEL  _Nullable *)action {
	return NO;
}

/// Populate menu with items.
- (void)menuNeedsUpdate:(NSMenu*)menu {
	NSManagedObjectContext *moc = [StoreCoordinator createChildContext];
	if (menu.isFeedMenu) {
		Feed *feed = [StoreCoordinator feedWithIndexPath:menu.titleIndexPath inContext:moc];
		[self setArticles:[feed sortedArticles] forMenu:menu];
	} else {
		NSArray<FeedGroup*> *groups = [StoreCoordinator sortedFeedGroupsWithParent:menu.parentItem.representedObject inContext:moc];
		if (groups.count == 0) {
			[menu addItemWithTitle:NSLocalizedString(@"~~~ no entries ~~~", nil) action:nil keyEquivalent:@""].enabled = NO;
		} else {
			[self setFeedGroups:groups forMenu:menu];
		}
	}
	[moc reset];
}

/// Get rid of everything that is not needed.
- (void)menuDidClose:(NSMenu*)menu {
	[menu cleanup];
}

/// Generate items for @c FeedGroup menu.
- (void)setFeedGroups:(NSArray<FeedGroup*>*)sortedList forMenu:(NSMenu*)menu {
	[menu insertDefaultHeader];
	for (FeedGroup *fg in sortedList) {
		[menu insertFeedGroupItem:fg].submenu.delegate = self;
	}
	UnreadTotal *uct = self.unreadMap[menu.titleIndexPath];
	[menu setHeaderHasUnread:(uct.unread > 0) hasRead:(uct.unread < uct.total)];
	// set unread counts
	for (NSMenuItem *item in menu.itemArray) {
		if (item.hasSubmenu)
			[item setTitleCount:self.unreadMap[item.submenu.titleIndexPath].unread];
	}
}

/// Generate items for @c FeedArticles menu.
- (void)setArticles:(NSArray<FeedArticle*>*)sortedList forMenu:(NSMenu*)menu {
	[menu insertDefaultHeader];
	NSUInteger mc = 0;
	if ([UserPrefs defaultNO:@"feedLimitArticles"]) {
		mc = [UserPrefs articlesInMenuLimit];
	}
	for (FeedArticle *fa in sortedList) {
		[menu addItem:[fa newMenuItem]];
		if (--mc == 0) // if mc==0 then unsigned int will underflow and turn into INT_MAX
			break;
	}
	UnreadTotal *uct = self.unreadMap[menu.titleIndexPath];
	[menu setHeaderHasUnread:(uct.unread > 0) hasRead:(uct.unread < uct.total)];
}


#pragma mark - Background Update / Rebuild Menu

/**
 Fetch @c Feed from core data and find deepest visible @c NSMenuItem.
 @warning @c item and @c feed will often mismatch.
 */
- (void)updateFeedMenuItem:(NSManagedObjectID*)oid withBlock:(void(^)(Feed *feed, NSMenuItem *item))block {
	NSManagedObjectContext *moc = [StoreCoordinator createChildContext];
	Feed *feed = [moc objectWithID:oid];
	if (![feed isKindOfClass:[Feed class]]) {
		[moc reset];
		return;
	}
	NSMenuItem *item = [self.statusItem.mainMenu deepestItemWithPath:feed.indexPath];
	if (!item) {
		[moc reset];
		return;
	}
	block(feed, item);
	[moc reset];
}

/// Callback method fired when feed has been updated in the background.
- (void)feedUpdated:(NSNotification*)notify {
	[self updateFeedMenuItem:notify.object withBlock:^(Feed *feed, NSMenuItem *item) {
		// 1. update in-memory unread count
		UnreadTotal *updated = [UnreadTotal new];
		updated.total = feed.articles.count;
		for (FeedArticle *fa in feed.articles) {
			if (fa.unread) updated.unread += 1;
		}
		[self.unreadMap updateAllCounts:updated forPath:feed.indexPath];
		// 2. rebuild articles menu if it is open
		if (item.submenu.isFeedMenu) { // menu item is visible
			item.enabled = (feed.articles.count > 0);
			if (item.submenu.numberOfItems > 0) { // replace articles menu
				[item.submenu removeAllItems];
				[self setArticles:[feed sortedArticles] forMenu:item.submenu];
			}
		}
		// 3. set unread count & enabled header for all parents
		NSArray<UnreadTotal*> *itms = [self.unreadMap itemsForPath:item.submenu.titleIndexPath create:NO];
		for (UnreadTotal *uct in itms.reverseObjectEnumerator) {
			[item.submenu setHeaderHasUnread:(uct.unread > 0) hasRead:(uct.unread < uct.total)];
			[item setTitleCount:uct.unread];
			item = item.parentItem;
		}
	}];
}

/// Callback method fired when feed icon has changed.
- (void)feedIconUpdated:(NSNotification*)notify {
	[self updateFeedMenuItem:notify.object withBlock:^(Feed *feed, NSMenuItem *item) {
		if (item.submenu.isFeedMenu)
			item.image = [feed iconImage16];
	}];
}

@end
