#import "NSMenu+Ext.h"
#import "StoreCoordinator.h"
#import "UserPrefs.h"
#import "Feed+Ext.h"
#import "FeedGroup+Ext.h"
#import "Constants.h"
#import "MapUnreadTotal.h"
#import "NotifyEndpoint.h"

typedef NS_ENUM(NSInteger, MenuItemTag) {
	/// Used in @c allowDisplayOfHeaderItem: to identify and enable items
	TagMarkAllRead = 1,
	TagMarkAllUnread = 2,
	TagOpenAllUnread = 3,
	/// Delimiter item between default header and core data items
	TagHeaderDelimiter = 8,
	/// Indicator whether unread count is currently shown in menu item title or not
	TagTitleCountVisible = 16,
};


@implementation NSMenu (Ext)

#pragma mark - Properties -

/// @return Dot separated list of @c sortIndex of each @c FeedGroup parent. Empty string if main menu.
- (NSString*)titleIndexPath {
	if (self.title.length <= 2) return @"";
	return [self.title substringFromIndex:2];
}

/// @return The menu item in the super menu. Or @c nil if there is no super menu.
- (NSMenuItem*)parentItem {
	if (!self.supermenu) return nil;
	//return self.itemArray.firstObject.parentItem;  // wont work without items
	//return self.supermenu.highlightedItem;  // is highlight guaranteed?
	return [self.supermenu itemAtIndex:[self.supermenu indexOfItemWithSubmenu:self]];
}

/// @return @c YES if menu contains feed articles only.
- (BOOL)isFeedMenu { return ([self.title characterAtIndex:0] == 'F'); }


#pragma mark - Generator -

/// Create new @c NSMenuItem with empty submenu and append it to the menu. @return Inserted item.
- (nullable NSMenuItem*)insertFeedGroupItem:(FeedGroup*)fg withUnread:(MapUnreadTotal*)unreadMap showHidden:(BOOL)showHidden {
	unichar chr = '-';
	NSMenuItem *item = nil;
	switch (fg.type) {
		case GROUP:     item = [fg newMenuItem]; chr = 'G'; break;
		case FEED:      item = [fg.feed newMenuItem]; chr = 'F'; break;
		case SEPARATOR: item = [NSMenuItem separatorItem]; break;
	}
	if (!item.isSeparatorItem) {
		NSString *t = [NSString stringWithFormat:@"%c%@.%d", chr, [self.title substringFromIndex:1], fg.sortIndex];
		NSUInteger unread = unreadMap[[t substringFromIndex:2]].unread;
		
		// Check user preferences to show only unread entries
		if (unread == 0 && !showHidden
			&& ((fg.type == GROUP && UserPrefsBool(Pref_groupUnreadOnly))
				|| (fg.type == FEED && UserPrefsBool(Pref_feedUnreadOnly)))) {
			item.hidden = YES;
		}
		
		item.submenu = [[NSMenu alloc] initWithTitle:t];
		[item setTitleCount:unread];
	}
	[self addItem:item];
	return item;
}

/// Insert items 'Open all unread', 'Mark all read' and 'Mark all unread'.
- (void)insertDefaultHeader {
	self.autoenablesItems = NO;
	NSMenuItem *itm = [self addItemIfAllowed:TagOpenAllUnread title:NSLocalizedString(@"Open all unread", nil)];
	if (itm) {
		NSInteger limit = UserPrefsInt(Pref_openFewLinksLimit);
		if (limit > 0) {
			NSString *altTitle = [NSString stringWithFormat:NSLocalizedString(@"Open a few unread (%ld)", nil), limit];
			[self addItem:[itm alternateWithTitle:altTitle]];
		}
	}
	[self addItemIfAllowed:TagMarkAllRead title:NSLocalizedString(@"Mark all read", nil)];
	[self addItemIfAllowed:TagMarkAllUnread title:NSLocalizedString(@"Mark all unread", nil)];
	if (self.numberOfItems > 0) {
		// in case someone has disabled all header items. Else, during articles menu rebuild it will stay on top.
		NSMenuItem *sep = [NSMenuItem separatorItem];
		sep.tag = TagHeaderDelimiter;
		[self addItem:sep];
	}
}


#pragma mark - Update Menu


/// Loop over default header and enable 'OpenAllUnread' and 'TagMarkAllRead' based on unread count.
- (void)setHeaderHasUnread:(UnreadTotal*)count {
	BOOL hasUnread = count.unread > 0;
	BOOL hasRead = count.unread < count.total;
	NSInteger i = [self indexOfItemWithTag:TagHeaderDelimiter] - 1;
	for (; i >= 0; i--) {
		NSMenuItem *item = [self itemAtIndex:i];
		switch (item.tag) {
			case TagOpenAllUnread: // incl. alternate item
			case TagMarkAllRead:
				item.enabled = hasUnread; break;
			case TagMarkAllUnread:
				item.enabled = hasRead; break;
		}
	}
}

/**
 Iterate over all menu items in @c self.itemArray and find the item where @c submenu.title matches
 the first @c sortIndex in @c path. Recursively repeat the process for the items of this submenu and so on.

 @param path Dot separated list of @c sortIndex. E.g., @c Feed.indexPath.
 @return Either @c NSMenuItem that exactly matches @c path or one of the parent @c NSMenuItem if a submenu isn't open.
 */
- (nullable NSMenuItem*)deepestItemWithPath:(nonnull NSString*)path {
	NSUInteger loc = [path rangeOfString:@"."].location;
	BOOL isLast = (loc == NSNotFound);
	NSString *indexStr = (isLast ? path : [path substringToIndex:loc]);
	for (NSMenuItem *item in self.itemArray) {
		if (item.hasSubmenu && [item.submenu.title hasSuffix:indexStr]) {
			if (!isLast && item.submenu.numberOfItems > 0)
				return [item.submenu deepestItemWithPath:[path substringFromIndex:loc+1]];
			return item;
		}
	}
	return nil;
}


#pragma mark - Helper

/// Check user preferences for preferred display style.
- (BOOL)allowDisplayOfHeaderItem:(MenuItemTag)tag {
	static NSString* const mr[] = {Pref_globalMarkRead,   Pref_groupMarkRead,   Pref_feedMarkRead};
	static NSString* const mu[] = {Pref_globalMarkUnread, Pref_groupMarkUnread, Pref_feedMarkUnread};
	static NSString* const ou[] = {Pref_globalOpenUnread, Pref_groupOpenUnread, Pref_feedOpenUnread};
	int i = (self.supermenu == nil ? 0 : (self.isFeedMenu ? 2 : 1));
	switch (tag) {
		case TagMarkAllRead:   return UserPrefsBool(mr[i]);
		case TagMarkAllUnread: return UserPrefsBool(mu[i]);
		case TagOpenAllUnread: return UserPrefsBool(ou[i]);
		default: return NO;
	}
}

/// Check user preferences if item should be displayed in menu. If so, add it to the menu and set callback to @c self.
- (NSMenuItem*)addItemIfAllowed:(MenuItemTag)tag title:(NSString*)title {
	if ([self allowDisplayOfHeaderItem:tag]) {
		NSMenuItem *item = [[NSMenuItem alloc] initWithTitle:title action:@selector(headerMenuItemCallback:) keyEquivalent:@""];
		item.target = [self class];
		item.tag = tag;
		item.representedObject = self.title;
		[self addItem:item];
		return item;
	}
	return nil;
}

/// Prepare @c userInfo dictionary and send @c NSNotification. Callback for every default header menu item.
+ (void)headerMenuItemCallback:(NSMenuItem*)sender {
	BOOL openLinks = NO;
	NSUInteger limit = 0;
	if (sender.tag == TagOpenAllUnread) {
		if (sender.isAlternate) // if reaches this far, limit is guaranteed to be >0
			limit = UserPrefsUInt(Pref_openFewLinksLimit);
		openLinks = YES;
	} else if (sender.tag != TagMarkAllRead && sender.tag != TagMarkAllUnread) {
		return; // other menu item clicked. abort and return.
	}
	BOOL markRead = (sender.tag != TagMarkAllUnread);
	BOOL isFeedMenu = NO;
	NSString *path = sender.representedObject;
	if (path.length > 2) {
		isFeedMenu = ([path characterAtIndex:0] == 'F');
		path = [path substringFromIndex:2];
	} else { // main menu
		path = nil;
	}
	NSManagedObjectContext *moc = [StoreCoordinator createChildContext];
	NSArray<FeedArticle*> *list = [StoreCoordinator articlesAtPath:path isFeed:isFeedMenu sorted:openLinks unread:markRead inContext:moc limit:limit];
	[NotifyEndpoint dismiss:
	 [StoreCoordinator updateArticles:list markRead:markRead andOpen:openLinks inContext:moc]];
}

@end



#pragma mark - NSMenuItem Category

@implementation NSMenuItem (Ext)

/// Create a copy of an existing menu item and set it's option key modifier.
- (instancetype)alternateWithTitle:(NSString*)title {
	NSMenuItem *alt = [self copy];
	alt.title = title;
	alt.keyEquivalentModifierMask = NSEventModifierFlagOption;
	alt.alternate = YES;
	return alt;
}

/// Remove & append new unread count to title
- (void)setTitleCount:(NSUInteger)count {
	if (self.tag == TagTitleCountVisible) {
		self.tag = 0; // clear mask
		self.state = NSControlStateValueOff;
		NSUInteger loc = [self.title rangeOfString:@" (" options:NSLiteralSearch | NSBackwardsSearch].location;
		if (loc != NSNotFound)
			self.title = [self.title substringToIndex:loc];
	}
	BOOL isFeed = self.submenu.isFeedMenu;
	if (count > 0 && UserPrefsBool(isFeed ? Pref_feedUnreadCount : Pref_groupUnreadCount)) {
		self.tag = TagTitleCountVisible; // apply new mask
		self.title = [self.title stringByAppendingFormat:@" (%ld)", count];
		self.onStateImage = [NSImage imageNamed:RSSImageMenuItemUnread];
		if (UserPrefsBool(isFeed ? Pref_feedUnreadIndicator : Pref_groupUnreadIndicator))
			self.state = NSControlStateValueOn;
	}
}

@end
