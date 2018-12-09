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
#import "FeedMeta+Ext.h"
#import "FeedGroup+Ext.h"
#import "FeedArticle+CoreDataClass.h"
#import "Constants.h"

#import <RSXML/RSXML.h>

@implementation Feed (Ext)

/// Instantiates new @c Feed and @c FeedMeta entities in context.
+ (instancetype)newFeedAndMetaInContext:(NSManagedObjectContext*)moc {
	Feed *feed = [[Feed alloc] initWithEntity:Feed.entity insertIntoManagedObjectContext:moc];
	feed.meta = [[FeedMeta alloc] initWithEntity:FeedMeta.entity insertIntoManagedObjectContext:moc];
	return feed;
}

/// Call @c indexPathString on @c .group and update @c .indexPath if current value is different.
- (void)calculateAndSetIndexPathString {
	NSString *pthStr = [self.group indexPathString];
	if (![self.indexPath isEqualToString:pthStr])
		self.indexPath = pthStr;
}

#pragma mark - Update Feed Items -

/**
 Replace feed title, subtitle and link (if changed). Also adds new articles and removes old ones.
 */
- (void)updateWithRSS:(RSParsedFeed*)obj postUnreadCountChange:(BOOL)flag {
	if (![self.title isEqualToString:obj.title])       self.title = obj.title;
	if (![self.subtitle isEqualToString:obj.subtitle]) self.subtitle = obj.subtitle;
	if (![self.link isEqualToString:obj.link])         self.link = obj.link;
	
	int32_t unreadBefore = self.unreadCount;
	NSMutableSet<NSString*> *urls = [[self.articles valueForKeyPath:@"link"] mutableCopy];
	[self addMissingArticles:obj updateLinks:urls]; // will remove links in 'urls' that should be kept
	if (urls.count > 0)
		[self deleteArticlesWithLink:urls]; // remove old, outdated articles
	if (flag) {
		NSNumber *cDiff = [NSNumber numberWithInteger:self.unreadCount - unreadBefore];
		[[NSNotificationCenter defaultCenter] postNotificationName:kNotificationTotalUnreadCountChanged object:cDiff];
	}
}

/**
 Append new articles and increment their sortIndex. Update article counter and unread counter on the way.

 @param urls Input will be used to identify new articles. Output will contain URLs that aren't present in the feed anymore.
 @return @c YES if new items were added, @c NO otherwise.
 */
- (BOOL)addMissingArticles:(RSParsedFeed*)obj updateLinks:(NSMutableSet<NSString*>*)urls {
	int latestID = [[self.articles valueForKeyPath:@"@max.sortIndex"] intValue];
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
	FeedArticle *fa = [[FeedArticle alloc] initWithEntity:FeedArticle.entity insertIntoManagedObjectContext:self.managedObjectContext];
	fa.sortIndex = (int32_t)idx;
	fa.unread = YES;
	fa.guid = entry.guid;
	fa.title = entry.title;
	fa.abstract = entry.abstract;
	fa.body = entry.body;
	fa.author = entry.author;
	fa.link = entry.link;
	fa.published = entry.datePublished;
	[self addArticlesObject:fa];
}

/**
 Delete all items where @c link matches one of the URLs in the @c NSSet.
 */
- (void)deleteArticlesWithLink:(NSMutableSet<NSString*>*)urls {
	if (!urls || urls.count == 0)
		return;
	self.articleCount -= (int32_t)urls.count;
	for (FeedArticle *fa in self.articles) {
		if ([urls containsObject:fa.link]) {
			[urls removeObject:fa.link];
			if (fa.unread)
				self.unreadCount -= 1;
			// TODO: keep unread articles?
			[fa.managedObjectContext deleteObject:fa];
			if (urls.count == 0)
				break;
		}
	}
}

#pragma mark - Article Properties -

/**
 @return Articles sorted by attribute @c sortIndex with descending order (newest items first).
 */
- (NSArray<FeedArticle*>*)sortedArticles {
	if (self.articles.count == 0)
		return nil;
	return [self.articles sortedArrayUsingDescriptors:@[[NSSortDescriptor sortDescriptorWithKey:@"sortIndex" ascending:NO]]];
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
	for (FeedArticle *fa in self.articles) {
		if (fa.unread == readFlag)
			fa.unread = !readFlag;
	}
	int32_t oldCount = self.unreadCount;
	int32_t newCount = (readFlag ? 0 : self.articleCount);
	if (self.unreadCount != newCount)
		self.unreadCount = newCount;
	return newCount - oldCount;
}

@end
