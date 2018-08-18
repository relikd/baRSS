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

#import "MenuItemInfo.h"

@interface MenuItemInfo()
/// internal counter used to sum the unread count of all sub items
@property (assign) int unreadCount;
/// internal flag whether unread count is displayed in parenthesis
@property (assign) BOOL countInTitle;
@end

@implementation MenuItemInfo
/// @return Info with unreadCount = 0
+ (instancetype)withID:(NSManagedObjectID*)oid {
	return [MenuItemInfo withID:oid unread:0];
}

+ (instancetype)withID:(NSManagedObjectID*)oid unread:(int)count {
	MenuItemInfo *info = [MenuItemInfo new];
	info.objID = oid;
	info.unreadCount = count;
	return info;
}

/// @return @c YES if (unreadCount > 0)
- (BOOL)hasUnread {
	return self.unreadCount > 0;
}

/// set: unreadCount -= count
- (void)markRead:(int)count {
	if (count > self.unreadCount) {
		NSLog(@"should never happen, trying to set an unread count below zero");
		self.unreadCount = 0;
	} else {
		self.unreadCount -= count;
	}
}

@end



@implementation NSMenuItem (MenuItemInfo)

/** Call represented object and check whether unread count > 0. */
- (BOOL)hasUnread {
	return [self.representedObject unreadCount] > 0;
}

/** Call represented object and retrieve the unread count from info. */
- (int)unreadCount {
	return [self.representedObject unreadCount];
}

/**
 Update internal unread counter and append unread count to title.
 
 @note Count may be negative to mark items as unread.
 @warning Does not check if @c representedObject is set accordingly
 @param count The amount by which the counter is adjusted.
 If negative the items will be marked as unread.
 */
- (void)markReadAndUpdateTitle:(int)count {
	if (count == 0) return; // 0 won't change anything
	MenuItemInfo *info = self.representedObject;
	if (!self.hasSubmenu) {
		[info markRead:count];
		self.state = (info.hasUnread ? NSControlStateValueOn : NSControlStateValueOff);
	} else {
		int countBefore = info.unreadCount;
		[info markRead:count];
		if (info.countInTitle) {
			int digitsBefore = (int)log10f(countBefore) + 1;
			NSInteger index = (NSInteger)self.title.length - digitsBefore - 3; // " (%d)"
			if (index < 0) index = 0;
			self.title = [self.title substringToIndex:(NSUInteger)index]; // remove old count
			info.countInTitle = NO;
		}
		if (info.unreadCount > 0) {
			self.title = [self.title stringByAppendingFormat:@" (%d)", info.unreadCount];
			info.countInTitle = YES;
		}
	}
}

/**
 Recursively propagate unread count to ancestor menu items.
 
 @note Does not update the current item, only the ancestors.
 @param count The amount by which the counter is adjusted.
 If negative the items will be marked as unread.
 */
- (void)markAncestorsRead:(int)count {
	NSMenuItem *parent = self.parentItem;
	while (parent.representedObject) {
		[parent markReadAndUpdateTitle:count];
		parent = parent.parentItem;
	}
}

/**
 Recursively iterate over submenues and children. Count aggregated element edits.

 @warning Block will be called for parent items, too. Consider this when using counters.
 @param block Will be called for each @c NSMenuItem sub-element where @c representedObject is set to a @c MenuItemInfo.
              Return -1 to stop processing early.
 @param flag If set to @c YES, recursive calls will be skipped for submenus that contain soleily read elements.
 @return The number of changed elements in total.
 */
- (int)descendantItemInfo:(MenuItemInfoRecursiveBlock)block unreadEntriesOnly:(BOOL)flag {
	MenuItemInfo *info = self.representedObject;
	if (![info isKindOfClass:[MenuItemInfo class]]) return 0;
	if (flag && !info.hasUnread) return 0;
	if (self.isSeparatorItem) return 0;
	
	int countItems = 1; // deepest entry, FeedItem
	if (self.hasSubmenu) {
		countItems = 0;
		for (NSMenuItem *child in self.submenu.itemArray) {
			int c = [child descendantItemInfo:block unreadEntriesOnly:flag];
			if (c < 0) break;
			countItems += c;
		}
	}
	return block(self, countItems);
}

/**
 Recursively iterate over siblings and all contained children. Count aggregated element edits.
 
 @warning Block will be called for parent items, too. Consider this when using counters.
 @param block Will be called for each @c NSMenuItem sub-element where @c representedObject is set to a @c MenuItemInfo.
              Return -1 to stop processing early.
 @param flag If set to @c YES, recursive calls will be skipped for submenus that contain soleily read elements.
 @return The number of changed elements in total.
 */
- (int)siblingsDescendantItemInfo:(MenuItemInfoRecursiveBlock)block unreadEntriesOnly:(BOOL)flag {
	int markedTotal = 0;
	for (NSMenuItem *sibling in self.menu.itemArray) {
		int marked = [sibling descendantItemInfo:block unreadEntriesOnly:flag];
		if (marked < 0) break;
		markedTotal += marked;
	}
	return markedTotal;
}

@end
