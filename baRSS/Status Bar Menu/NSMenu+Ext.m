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

@implementation NSMenu (Ext)

#pragma mark - Generator -

/// @return New main menu with target delegate.
+ (instancetype)menuWithDelegate:(id<NSMenuDelegate>)target {
	NSMenu *menu = [[NSMenu alloc] initWithTitle:@"M"];
	menu.autoenablesItems = NO;
	menu.delegate = target;
	return menu;
}

/// @return New menu with old title and delegate. Index path in title is appended.
- (instancetype)submenuWithIndex:(int)index isFeed:(BOOL)flag {
	NSMenu *menu = [NSMenu menuWithDelegate:self.delegate];
	menu.title = [NSString stringWithFormat:@"%c%@.%d", (flag ? 'F' : 'G'), self.title, index];
	return menu;
}

/// @return New menu with old title and delegate.
- (instancetype)cleanInstanceCopy {
	NSMenu *menu = [NSMenu menuWithDelegate:self.delegate];
	menu.title = self.title;
	return menu;
}


#pragma mark - Properties -


/// @return @c YES if menu is status bar menu.
- (BOOL)isMainMenu {
	return [self.title isEqualToString:@"M"];
}

/// @return @c YES if menu contains feed articles only.
- (BOOL)isFeedMenu {
	return [self.title characterAtIndex:0] == 'F';
}

/// @return Either @c ScopeGlobal, @c ScopeGroup or @c ScopeFeed.
- (MenuItemTag)scope {
	if ([self isFeedMenu]) return ScopeFeed;
	if ([self isMainMenu]) return ScopeGlobal;
	return ScopeGroup;
}

/// @return Index offset of the first Core Data feed item (may be separator), skipping default header and main menu header.
- (NSInteger)feedConfigOffset {
	for (NSInteger i = 0; i < self.numberOfItems; i++) {
		if ([[[self itemAtIndex:i] representedObject] isKindOfClass:[NSManagedObjectID class]])
			return i;
	}
	return 0;
}

/// Perform Core Data fetch request and return unread count for all descendent items.
- (NSInteger)coreDataUnreadCount {
	NSUInteger loc = [self.title rangeOfString:@"."].location;
	NSString *path = nil;
	if (loc != NSNotFound)
		path = [self.title substringFromIndex:loc + 1];
	return [StoreCoordinator unreadCountForIndexPathString:path];
}


#pragma mark - Modify Menu -


/// Loop over default header and enable 'OpenAllUnread' and 'TagMarkAllRead' based on unread count.
- (void)autoEnableMenuHeader:(BOOL)hasUnread {
	for (NSMenuItem *item in self.itemArray) {
		if (item.representedObject)
			return; // default menu has no represented object
		switch (item.tag & TagMaskType) {
			case TagOpenAllUnread: case TagMarkAllRead:
				item.enabled = hasUnread;
			default: break;
		}
		//[item applyUserSettingsDisplay]; // should not change while menu is open
	}
}

/// Loop over menu and replace all separator items (text) with actual separator.
- (void)replaceSeparatorStringsWithActualSeparator {
	for (NSInteger i = 0; i < self.numberOfItems; i++) {
		NSMenuItem *oldItem = [self itemAtIndex:i];
		if ([oldItem.title isEqualToString:kSeparatorItemTitle]) {
			NSMenuItem *newItem = [NSMenuItem separatorItem];
			newItem.representedObject = oldItem.representedObject;
			[self removeItemAtIndex:i];
			[self insertItem:newItem atIndex:i];
		}
	}
}

@end
