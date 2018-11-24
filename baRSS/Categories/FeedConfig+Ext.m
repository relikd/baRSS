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

/**
 Sorted children array based on sort order provided in feed settings.

 @return Sorted array of @c FeedConfig items.
 */
- (NSArray<FeedConfig*>*)sortedChildren {
	if (self.children.count == 0)
		return nil;
	return [self.children sortedArrayUsingDescriptors:@[[NSSortDescriptor sortDescriptorWithKey:@"sortIndex" ascending:YES]]];
}

/// IndexPath for sorted children starting with root index.
- (NSIndexPath*)indexPath {
	if (self.parent == nil)
		return [NSIndexPath indexPathWithIndex:(NSUInteger)self.sortIndex];
	return [[self.parent indexPath] indexPathByAddingIndex:(NSUInteger)self.sortIndex];
}

/**
 Change unread counter for all parents recursively. Result will never be negative.

 @param count If negative, mark items read.
 */
- (void)markUnread:(int)count ancestorsOnly:(BOOL)flag {
	FeedConfig *par = (flag ? self.parent : self);
	while (par) {
		[self.managedObjectContext refreshObject:par mergeChanges:YES];
		par.unreadCount += count;
		NSAssert(par.unreadCount >= 0, @"ERROR ancestorsMarkUnread: Count should never be negative.");
		par = par.parent;
	}
	[[NSNotificationCenter defaultCenter] postNotificationName:kNotificationTotalUnreadCountChanged
														object:[NSNumber numberWithInt:count]];
}

/// @return Time interval respecting the selected unit. E.g., returns @c 180 for @c '3m'
- (NSTimeInterval)timeInterval {
	static const int unit[] = {1, 60, 3600, 86400, 604800}; // smhdw
	return self.refreshNum * unit[self.refreshUnit % 5];
}

/// Calculate date from @c refreshNum and @c refreshUnit and set as next scheduled feed update.
- (void)calculateAndSetScheduled {
	self.scheduled = [[NSDate date] dateByAddingTimeInterval:[self timeInterval]];
}

/// Update FeedMeta or create new one if needed.
- (void)setEtag:(NSString*)etag modified:(NSString*)modified {
	// TODO: move to separate function and add icon download
	if (!self.meta) {
		self.meta = [[FeedMeta alloc] initWithEntity:FeedMeta.entity insertIntoManagedObjectContext:self.managedObjectContext];
	}
	self.meta.httpEtag = etag;
	self.meta.httpModified = modified;
}

/// Delete any existing feed object and parse new one. Read state will be copied.
- (void)updateRSSFeed:(RSParsedFeed*)obj {
	NSArray<NSString*> *readURLs = [self.feed alreadyReadURLs];
	int unreadBefore = self.unreadCount;
	int unreadAfter = 0;
	if (self.feed)
		[self.managedObjectContext deleteObject:(NSManagedObject*)self.feed];
	if (obj) {
		// TODO: update and dont re-create each time
		self.feed = [Feed feedFromRSS:obj inContext:self.managedObjectContext alreadyRead:readURLs unread:&unreadAfter];
	}
	[self markUnread:(unreadAfter - unreadBefore) ancestorsOnly:NO];
}

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
