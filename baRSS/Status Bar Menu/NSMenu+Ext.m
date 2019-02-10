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

#import "NSMenu+Ext.h"
#import "StoreCoordinator.h"
#import "UserPrefs.h"
#import "Feed+Ext.h"
#import "FeedGroup+Ext.h"
#import "Constants.h"

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

/// @return @c YES if menu is status bar menu.
- (BOOL)isMainMenu { return (self.supermenu == nil); }

/// @return @c YES if menu contains feed articles only.
- (BOOL)isFeedMenu { return ([self.title characterAtIndex:0] == 'F'); }


#pragma mark - Generator -

/// Create new @c NSMenuItem with empty submenu and append it to the menu. @return Inserted item.
- (NSMenuItem*)insertFeedGroupItem:(FeedGroup*)fg {
	unichar chr = '-';
	NSMenuItem *item = nil;
	switch (fg.type) {
		case GROUP:     item = [fg newMenuItem]; chr = 'G'; break;
		case FEED:      item = [fg.feed newMenuItem]; chr = 'F'; break;
		case SEPARATOR: item = [NSMenuItem separatorItem]; break;
	}
	if (!item.isSeparatorItem) {
		NSString *t = [NSString stringWithFormat:@"%c%@.%d", chr, [self.title substringFromIndex:1], fg.sortIndex];
		item.submenu = [[NSMenu alloc] initWithTitle:t];
	}
	[self addItem:item];
	return item;
}

/// Insert items 'Open all unread', 'Mark all read' and 'Mark all unread'.
- (void)insertDefaultHeader {
	self.autoenablesItems = NO;
	NSMenuItem *itm = [self addItemIfAllowed:TagOpenAllUnread title:NSLocalizedString(@"Open all unread", nil)];
	if (itm) {
		[self addItem:[itm alternateWithTitle:[NSString stringWithFormat:NSLocalizedString(@"Open a few unread (%lu)", nil), [UserPrefs openFewLinksLimit]]]];
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

/// Replace this menu with a clean @c NSMenu. Copy old @c title and @c delegate to new menu. @b Won't work without supermenu!
- (void)cleanup {
	NSMenu *m = [[NSMenu alloc] initWithTitle:self.title];
	m.delegate = self.delegate;
	self.parentItem.submenu = m;
}

/// Loop over default header and enable 'OpenAllUnread' and 'TagMarkAllRead' based on unread count.
- (void)setHeaderHasUnread:(BOOL)hasUnread hasRead:(BOOL)hasRead {
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
- (NSMenuItem*)deepestItemWithPath:(nonnull NSString*)path {
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
	static const char * A[] = {"", "global", "feed", "group"};
	static const char * B[] = {"", "MarkRead", "MarkUnread", "OpenUnread"};
	int idx = (self.isMainMenu ? 1 : (self.isFeedMenu ? 2 : 3));
	return [UserPrefs defaultYES:[NSString stringWithFormat:@"%s%s", A[idx], B[tag & 3]]]; // first 2 bits
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
		if (sender.isAlternate)
			limit = [UserPrefs openFewLinksLimit];
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
	
	NSNumber *countDiff = [NSNumber numberWithUnsignedInteger:list.count];
	if (markRead) countDiff = [NSNumber numberWithInteger: -1 * countDiff.integerValue];
	
	NSMutableArray<NSURL*> *urls = [NSMutableArray arrayWithCapacity:list.count];
	for (FeedArticle *fa in list) {
		fa.unread = !markRead;
		if (openLinks && fa.link.length > 0)
			[urls addObject:[NSURL URLWithString:fa.link]];
	}
	[StoreCoordinator saveContext:moc andParent:YES];
	[moc reset];
	if (openLinks)
		[UserPrefs openURLsWithPreferredBrowser:urls];
	[[NSNotificationCenter defaultCenter] postNotificationName:kNotificationTotalUnreadCountChanged object:countDiff];
}

@end



#pragma mark - NSMenuItem Category

@implementation NSMenuItem (Ext)

/// Create a copy of an existing menu item and set it's option key modifier.
- (instancetype)alternateWithTitle:(NSString*)title {
	NSMenuItem *alt = [self copy];
	alt.title = title;
	alt.keyEquivalentModifierMask = NSEventModifierFlagOption;
	if (!alt.hidden) { // hidden will be ignored if alternate is YES
		alt.hidden = YES; // force hidden to hide if menu is already open (background update)
		alt.alternate = YES;
	}
	return alt;
}

/// Remove & append new unread count to title
- (void)setTitleCount:(NSUInteger)count {
	if (self.tag == TagTitleCountVisible) {
		self.tag = 0; // clear mask
		NSUInteger loc = [self.title rangeOfString:@" (" options:NSLiteralSearch | NSBackwardsSearch].location;
		if (loc != NSNotFound)
			self.title = [self.title substringToIndex:loc];
	}
	if (count > 0 && [UserPrefs defaultYES:(self.submenu.isFeedMenu ? @"feedUnreadCount" : @"groupUnreadCount")]) {
		self.tag = TagTitleCountVisible; // apply new mask
		self.title = [self.title stringByAppendingFormat:@" (%ld)", count];
	}
}

@end
