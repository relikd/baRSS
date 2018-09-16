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

#import "NSMenuItem+Info.h"
#import "UserPrefs.h"
#import "StoreCoordinator.h"

/// User preferences for displaying menu items
typedef NS_ENUM(char, DisplaySetting) {
	/// User preference not available. @c NSMenuItem is not configurable (not a header item)
	INVALID,
	/// User preference to display this item
	ALLOW,
	/// User preference to hide this item
	PROHIBIT
};

@interface ReaderInfo : NSObject
@property (strong) NSManagedObjectID *objID;
/// internal counter used to sum the unread count of all sub items
@property (assign) int unreadCount;
/// internal flag whether unread count is displayed in parenthesis
@property (assign) BOOL countInTitle;
@end

@implementation ReaderInfo
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


// ################################################################
// #
// #  NSMenuItem ReaderInfo Extension
// #
// ################################################################

@implementation NSMenuItem (Info)
/** Call represented object and check whether unread count > 0. */
- (BOOL)hasUnread {
	return [(ReaderInfo*)self.representedObject unreadCount] > 0;
}

/** Call represented object and retrieve the unread count from info. */
- (int)unreadCount {
	return [(ReaderInfo*)self.representedObject unreadCount];
}

/** Return @c YES if @c ReaderInfo is stored in @c representedObject. */
- (BOOL)hasReaderInfo {
	return [self.representedObject isKindOfClass:[ReaderInfo class]];
}

/**
 Save represented core data object in @c ReaderInfo.

 @param oid Represented core data object id.
 @param count Unread count for item.
 */
- (void)setReaderInfo:(NSManagedObjectID*)oid unread:(int)count {
	ReaderInfo *info = [ReaderInfo new];
	info.objID = oid;
	info.unreadCount = count;
	self.representedObject = info;
}

/**
 Return represented core data object. Return @c nil if @c ReaderInfo is missing.
 */
- (id)requestCoreDataObject {
	if (![self hasReaderInfo])
		return nil;
	return [StoreCoordinator objectWithID: [(ReaderInfo*)self.representedObject objID]];
}

/**
 Check user preferences for preferred display style.

 @return As per user settings return @c ALLOW or @c PROHIBIT. Will return @c INVALID for items that aren't configurable.
 */
- (DisplaySetting)allowsDisplay {
	NSString *prefix;
	switch (self.tag & TagMaskScope) {
		case ScopeFeed: prefix = @"feed"; break;
		case ScopeGroup: prefix = @"group"; break;
		case ScopeGlobal: prefix = @"global"; break;
		default: return INVALID; // no scope, not recognized menu item
	}
	NSString *postfix;
	switch (self.tag & TagMaskType) {
		case TagOpenAllUnread: postfix = @"OpenUnread"; break;
		case TagMarkAllRead: postfix = @"MarkRead"; break;
		case TagMarkAllUnread: postfix = @"MarkUnread"; break;
		default: return INVALID; // wrong tag, ignore
	}
	
	if ([UserPrefs defaultYES:[prefix stringByAppendingString:postfix]])
		return ALLOW;
	return PROHIBIT;
}

/**
 Set item @c hidden based on user preferences. Does nothing for items that aren't configurable in settings.
 */
- (void)applyUserSettingsDisplay {
	switch ([self allowsDisplay]) {
		case ALLOW:
			self.hidden = NO;
			if (self.keyEquivalentModifierMask == NSEventModifierFlagOption)
				self.alternate = YES; // restore alternate flag
			break;
		case PROHIBIT:
			if (self.isAlternate)
				self.alternate = NO; // to allow hidden = YES, alternate flag needs to be NO
			self.hidden = YES;
			break;
		case INVALID: break;
	}
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
	ReaderInfo *info = self.representedObject;
	if (!self.hasSubmenu) {
		[info markRead:count];
		self.state = ([self hasUnread] ? NSControlStateValueOn : NSControlStateValueOff);
	} else {
		int countBefore = info.unreadCount;
		[info markRead:count];
		if (info.countInTitle) {
			[self removeUnreadCountFromTitle:countBefore];
			info.countInTitle = NO;
		}
		[self addUnreadCountToTitle];
	}
}

/**
 Update title without changing internal unread count. Save to call multiple times.
 
 @param show Whether to show or hide count
 */
- (void)countInTitle:(BOOL)show {
	ReaderInfo *info = self.representedObject;
	NSLog(@"%@", info);
	return;
	if (!show && info.countInTitle) {
		[self removeUnreadCountFromTitle: info.unreadCount];
		info.countInTitle = NO;
	} else if (show && !info.countInTitle) {
		[self addUnreadCountToTitle];
	}
}

/**
 Update title after unread count has changed
 
 @param countBefore The count before the update
 */
- (void)removeUnreadCountFromTitle:(int)countBefore {
	int digitsBefore = (int)log10f(countBefore) + 1;
	NSInteger index = (NSInteger)self.title.length - digitsBefore - 3; // " (%d)"
	if (index < 0) index = 0;
	self.title = [self.title substringToIndex:(NSUInteger)index]; // remove old count
}

/**
 Append count in parenthesis if thats allowed for the current scope (user settings)
 */
- (void)addUnreadCountToTitle {
	ReaderInfo *info = self.representedObject;
	if (info.unreadCount > 0 &&
		(((self.tag & ScopeGroup) && [UserPrefs defaultYES:@"groupUnreadCount"]) ||
		 ((self.tag & ScopeFeed) && [UserPrefs defaultYES:@"feedUnreadCount"])))
	{
		self.title = [self.title stringByAppendingFormat:@" (%d)", info.unreadCount];
		info.countInTitle = YES;
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
 @param block Will be called for each @c NSMenuItem sub-element where @c representedObject is set to a @c ReaderInfo.
 Return -1 to stop processing early.
 @param flag If set to @c YES, recursive calls will be skipped for submenus that contain soleily read elements.
 @return The number of changed elements in total.
 */
- (int)descendantItemInfo:(ReaderInfoRecursiveBlock)block unreadEntriesOnly:(BOOL)flag {
	if (self.isSeparatorItem) return 0;
	if (![self hasReaderInfo]) return 0;
	if (flag && ![self hasUnread]) return 0;
	
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
 @param block Will be called for each @c NSMenuItem sub-element where @c representedObject is set to a @c ReaderInfo.
 Return -1 to stop processing early.
 @param flag If set to @c YES, recursive calls will be skipped for submenus that contain soleily read elements.
 @return The number of changed elements in total.
 */
- (int)siblingsDescendantItemInfo:(ReaderInfoRecursiveBlock)block unreadEntriesOnly:(BOOL)flag {
	int markedTotal = 0;
	for (NSMenuItem *sibling in self.menu.itemArray) {
		int marked = [sibling descendantItemInfo:block unreadEntriesOnly:flag];
		if (marked < 0) break;
		markedTotal += marked;
	}
	return markedTotal;
}

@end
