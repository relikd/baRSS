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

#import "FeedGroup+Ext.h"
#import "FeedMeta+Ext.h"
#import "Feed+Ext.h"

#import <Cocoa/Cocoa.h>

@implementation FeedGroup (Ext)

/// Create new instance and set @c Feed and @c FeedMeta if group type is @c FEED
+ (instancetype)newGroup:(FeedGroupType)type inContext:(NSManagedObjectContext*)moc {
	FeedGroup *fg = [[FeedGroup alloc] initWithEntity: FeedGroup.entity insertIntoManagedObjectContext:moc];
	fg.type = type;
	if (type == FEED)
		fg.feed = [Feed newFeedAndMetaInContext:moc];
	return fg;
}

- (void)setParent:(FeedGroup *)parent andSortIndex:(int32_t)sortIndex {
	self.parent = parent;
	self.sortIndex = sortIndex;
	if (self.type == FEED)
		[self.feed calculateAndSetIndexPathString];
}

/// Set @c name attribute but only if value differs.
- (void)setNameIfChanged:(NSString*)name {
	if (![self.name isEqualToString: name])
		self.name = name;
}

/// @return Return static @c 16x16px NSImageNameFolder image.
- (NSImage*)groupIconImage16 {
	static NSImage *groupIcon;
	if (!groupIcon) {
		groupIcon = [NSImage imageNamed:NSImageNameFolder];
		groupIcon.size = NSMakeSize(16, 16);
	}
	return groupIcon;
}


#pragma mark - Handle Children And Parents -


/// @return IndexPath as semicolon separated string for sorted children starting with root index.
- (NSString*)indexPathString {
	if (self.parent == nil)
		return [NSString stringWithFormat:@"%d", self.sortIndex];
	return [[self.parent indexPathString] stringByAppendingFormat:@".%d", self.sortIndex];
}

/// @return Children sorted by attribute @c sortIndex (same order as in preferences).
- (NSArray<FeedGroup*>*)sortedChildren {
	if (self.children.count == 0)
		return nil;
	return [self.children sortedArrayUsingDescriptors:@[[NSSortDescriptor sortDescriptorWithKey:@"sortIndex" ascending:YES]]];
}

/// @return @c NSArray of all ancestors: First object is root. Last object is the @c FeedGroup that executed the command.
- (NSMutableArray<FeedGroup*>*)allParents {
	if (self.parent == nil)
		return [NSMutableArray arrayWithObject:self];
	NSMutableArray *arr = [self.parent allParents];
	[arr addObject:self];
	return arr;
}

/**
 Iterate over all descenden feeds.

 @param ordered If @c YES items are executed in the same order they are listed in the menu. Pass @n NO for a speed-up.
 @param block Set @c cancel to @c YES to stop execution of further descendants.
 @return @c NO if execution was stopped with @c cancel @c = @c YES in @c block.
 */
- (BOOL)iterateSorted:(BOOL)ordered overDescendantFeeds:(void(^)(Feed*,BOOL*))block  {
	if (self.feed) {
		BOOL stopEarly = NO;
		block(self.feed, &stopEarly);
		if (stopEarly) return NO;
	} else {
		for (FeedGroup *fg in (ordered ? [self sortedChildren] : self.children)) {
			if (![fg iterateSorted:ordered overDescendantFeeds:block])
				return NO;
		}
	}
	return YES;
}


#pragma mark - Printing -


/// @return Simplified description of the feed object.
- (NSString*)readableDescription {
	switch (self.type) {
		case SEPARATOR: return @"-------------";
		case GROUP: return [NSString stringWithFormat:@"%@", self.name];
		case FEED:
			return [NSString stringWithFormat:@"%@ (%@) - %@", self.name, self.feed.meta.url, self.refreshStr];
	}
}

@end
