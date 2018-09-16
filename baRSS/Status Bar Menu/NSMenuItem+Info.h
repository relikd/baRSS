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

#import <Cocoa/Cocoa.h>

/// @c NSMenuItem options that are assigned to the @c tag attribute.
typedef NS_OPTIONS(NSInteger, MenuItemTag) {
	/// Item visible at the very first menu level
	ScopeGlobal = 2,
	/// Item visible at each grouping, e.g., multiple feeds in one group
	ScopeGroup = 4,
	/// Item visible at the deepest menu level (@c FeedItem elements and header)
	ScopeFeed = 8,
	///
	TagPreferences = (1 << 4),
	TagPauseUpdates = (2 << 4),
	TagUpdateFeed = (3 << 4),
	TagMarkAllRead = (4 << 4),
	TagMarkAllUnread = (5 << 4),
	TagOpenAllUnread = (6 << 4),
	
	TagMaskScope = 0xF,
	TagMaskType = 0xFFF0,
};


@interface NSMenuItem (Info)
/**
 Iteration block for descendants of @c NSMenuItem.
 
 @param count The number of sub-elements contained in that @c NSMenuItem. 1 for @c FeedItems at the deepest layer.
 Otherwise the number of (updated) descendants.
 @return Return how many elements are updated in this block execution. If none were changed return @c 0.
 If execution should be stopped early, return @c -1.
 */
typedef int (^ReaderInfoRecursiveBlock) (NSMenuItem *item, int count);

- (BOOL)hasUnread;
- (int)unreadCount;
- (BOOL)hasReaderInfo;
- (void)setReaderInfo:(NSManagedObjectID*)oid unread:(int)count;
- (id)requestCoreDataObject;
- (void)applyUserSettingsDisplay;
- (void)markReadAndUpdateTitle:(int)count;
- (void)countInTitle:(BOOL)show;
- (void)markAncestorsRead:(int)count;
- (int)siblingsDescendantItemInfo:(ReaderInfoRecursiveBlock)block unreadEntriesOnly:(BOOL)flag;
@end
