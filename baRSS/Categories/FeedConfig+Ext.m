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

#import "FeedConfig+Ext.h"
#import "Feed+Ext.h"
#import "FeedMeta+CoreDataClass.h"
#import "Constants.h"

@implementation FeedConfig (Ext)
/// Enum tpye getter see @c FeedConfigType
- (FeedConfigType)typ { return (FeedConfigType)self.type; }
/// Enum type setter see @c FeedConfigType
- (void)setTyp:(FeedConfigType)typ { self.type = typ; }


#pragma mark - Handle Children And Parents -


/// @return IndexPath as semicolon separated string for sorted children starting with root index.
- (NSString*)indexPathString {
	if (self.parent == nil)
		return [NSString stringWithFormat:@"%d", self.sortIndex];
	return [[self.parent indexPathString] stringByAppendingFormat:@".%d", self.sortIndex];
}

/// @return Children sorted by attribute @c sortIndex (same order as in preferences).
- (NSArray<FeedConfig*>*)sortedChildren {
	if (self.children.count == 0)
		return nil;
	return [self.children sortedArrayUsingDescriptors:@[[NSSortDescriptor sortDescriptorWithKey:@"sortIndex" ascending:YES]]];
}

/// @return @c NSArray of all ancestors: First object is root. Last object is the @c FeedConfig that executed the command.
- (NSMutableArray<FeedConfig*>*)allParents {
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
		for (FeedConfig *fc in (ordered ? [self sortedChildren] : self.children)) {
			if (![fc iterateSorted:ordered overDescendantFeeds:block])
				return NO;
		}
	}
	return YES;
}


#pragma mark - Update Feed And Meta -


/// Delete any existing feed object and parse new one. Read state will be copied.
- (void)updateRSSFeed:(RSParsedFeed*)obj {
	if (!self.feed) {
		self.feed = [[Feed alloc] initWithEntity:Feed.entity insertIntoManagedObjectContext:self.managedObjectContext];
		self.feed.indexPath = [self indexPathString];
	}
	int32_t unreadBefore = self.feed.unreadCount;
	[self.feed updateWithRSS:obj];
	NSNumber *cDiff = [NSNumber numberWithInteger:self.feed.unreadCount - unreadBefore];
	[[NSNotificationCenter defaultCenter] postNotificationName:kNotificationTotalUnreadCountChanged object:cDiff];
}

/// Update FeedMeta or create new one if needed.
- (void)setEtag:(NSString*)etag modified:(NSString*)modified {
	if (!self.meta) {
		self.meta = [[FeedMeta alloc] initWithEntity:FeedMeta.entity insertIntoManagedObjectContext:self.managedObjectContext];
	}
	if (![self.meta.httpEtag isEqualToString:etag])         self.meta.httpEtag = etag;
	if (![self.meta.httpModified isEqualToString:modified]) self.meta.httpModified = modified;
}

/// Calculate date from @c refreshNum and @c refreshUnit and set as next scheduled feed update.
- (void)calculateAndSetScheduled {
	self.scheduled = [[NSDate date] dateByAddingTimeInterval:[self timeInterval]];
}

/// @return Time interval respecting the selected unit. E.g., returns @c 180 for @c '3m'
- (NSTimeInterval)timeInterval {
	static const int unit[] = {1, 60, 3600, 86400, 604800}; // smhdw
	return self.refreshNum * unit[self.refreshUnit % 5];
}


#pragma mark - Printing -


/// @return Formatted string for update interval ( e.g., @c 30m or @c 12h )
- (NSString*)readableRefreshString {
	return [NSString stringWithFormat:@"%d%c", self.refreshNum, [@"smhdw" characterAtIndex:self.refreshUnit % 5]];
}

/// @return Simplified description of the feed object.
- (NSString*)readableDescription {
	switch (self.typ) {
		case SEPARATOR: return @"-------------";
		case GROUP: return [NSString stringWithFormat:@"%@", self.name];
		case FEED:
			return [NSString stringWithFormat:@"%@ (%@) - %@", self.name, self.url, [self readableRefreshString]];
	}
}

@end
