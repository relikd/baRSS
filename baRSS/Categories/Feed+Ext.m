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

#import "Feed+Ext.h"
#import "FeedConfig+Ext.h"
#import "FeedItem+CoreDataClass.h"
#import <RSXML/RSXML.h>

@implementation Feed (Ext)

/**
 Replace feed title, subtitle and link (if changed). Also adds new articles and removes old ones.
 */
- (void)updateWithRSS:(RSParsedFeed*)obj {
	if (![self.title isEqualToString:obj.title])       self.title = obj.title;
	if (![self.subtitle isEqualToString:obj.subtitle]) self.subtitle = obj.subtitle;
	if (![self.link isEqualToString:obj.link])         self.link = obj.link;
	
	NSMutableSet<NSString*> *urls = [[self.items valueForKeyPath:@"link"] mutableCopy];
	if ([self addMissingArticles:obj updateLinks:urls]) // will remove links in 'urls' that should be kept
		[self deleteArticlesWithLink:urls]; // remove old, outdated articles
}

/**
 Append new articles and increment their sortIndex. Update article counter and unread counter on the way.

 @param urls Input will be used to identify new articles. Output will contain URLs that aren't present in the feed anymore.
 @return @c YES if new items were added, @c NO otherwise.
 */
- (BOOL)addMissingArticles:(RSParsedFeed*)obj updateLinks:(NSMutableSet<NSString*>*)urls {
	int latestID = [[self.items valueForKeyPath:@"@max.sortIndex"] intValue];
	__block int newOnes = 0;
	[obj.articles enumerateObjectsWithOptions:NSEnumerationReverse usingBlock:^(RSParsedArticle * _Nonnull article, BOOL * _Nonnull stop) {
		// reverse enumeration ensures correct article order
		if ([urls containsObject:article.link]) {
			[urls removeObject:article.link];
		} else {
			newOnes += 1;
			[self insertArticle:article atIndex:latestID + newOnes];
		}
	}];
	if (newOnes == 0) return NO;
	self.articleCount += newOnes;
	self.unreadCount += newOnes; // new articles are by definition unread
	return YES;
}

/**
 Create article based on input and insert into core data storage.
 */
- (void)insertArticle:(RSParsedArticle*)entry atIndex:(int)idx {
	FeedItem *b = [[FeedItem alloc] initWithEntity:FeedItem.entity insertIntoManagedObjectContext:self.managedObjectContext];
	b.sortIndex = (int32_t)idx;
	b.unread = YES;
	b.guid = entry.guid;
	b.title = entry.title;
	b.abstract = entry.abstract;
	b.body = entry.body;
	b.author = entry.author;
	b.link = entry.link;
	b.published = entry.datePublished;
	[self addItemsObject:b];
}

/**
 Delete all items where @c link matches one of the URLs in the @c NSSet.
 */
- (void)deleteArticlesWithLink:(NSMutableSet<NSString*>*)urls {
	if (!urls || urls.count == 0)
		return;
	
	self.articleCount -= (int32_t)urls.count;
	for (FeedItem *item in self.items) {
		if ([urls containsObject:item.link]) {
			[urls removeObject:item.link];
			if (item.unread)
				self.unreadCount -= 1;
			// TODO: keep unread articles?
			[item.managedObjectContext deleteObject:item];
			if (urls.count == 0)
				break;
		}
	}
}

/**
 @return Articles sorted by attribute @c sortIndex with descending order (newest items first).
 */
- (NSArray<FeedItem*>*)sortedArticles {
	if (self.items.count == 0)
		return nil;
	return [self.items sortedArrayUsingDescriptors:@[[NSSortDescriptor sortDescriptorWithKey:@"sortIndex" ascending:NO]]];
}

/**
 For all articles set @c unread @c = @c NO

 @return Change in unread count. (0 or negative number)
 */
- (int)markAllItemsRead {
	return [self markAllArticlesRead:YES];
}

/**
 For all articles set @c unread @c = @c YES

 @return Change in unread count. (0 or positive number)
 */
- (int)markAllItemsUnread {
	return [self markAllArticlesRead:NO];
}

/**
 Mark all articles read or unread and update @c unreadCount

 @param readFlag @c YES: mark items read; @c NO: mark items unread
 */
- (int)markAllArticlesRead:(BOOL)readFlag {
	for (FeedItem *i in self.items) {
		if (i.unread == readFlag)
			i.unread = !readFlag;
	}
	int32_t oldCount = self.unreadCount;
	int32_t newCount = (readFlag ? 0 : self.articleCount);
	if (self.unreadCount != newCount)
		self.unreadCount = newCount;
	return newCount - oldCount;
}

@end
