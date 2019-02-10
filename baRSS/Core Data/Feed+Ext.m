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
#import "Constants.h"
#import "UserPrefs.h"
#import "DrawImage.h"
#import "FeedMeta+Ext.h"
#import "FeedGroup+Ext.h"
#import "FeedArticle+Ext.h"
#import "StoreCoordinator.h"

#import <RSXML/RSXML.h>

@implementation Feed (Ext)

/// Instantiates new @c Feed and @c FeedMeta entities in context.
+ (instancetype)newFeedAndMetaInContext:(NSManagedObjectContext*)moc {
	Feed *feed = [[Feed alloc] initWithEntity:Feed.entity insertIntoManagedObjectContext:moc];
	feed.meta = [[FeedMeta alloc] initWithEntity:FeedMeta.entity insertIntoManagedObjectContext:moc];
	return feed;
}

/// Instantiates new @c FeedGroup with @c FEED type, set the update interval to @c 30min and @c sortIndex to last root index.
+ (instancetype)appendToRootWithDefaultIntervalInContext:(NSManagedObjectContext*)moc {
	NSUInteger lastIndex = [StoreCoordinator countRootItemsInContext:moc];
	FeedGroup *fg = [FeedGroup newGroup:FEED inContext:moc];
	[fg setParent:nil andSortIndex:(int32_t)lastIndex];
	[fg.feed.meta setRefreshAndSchedule:kDefaultFeedRefreshInterval];
	return fg.feed;
}

/// Call @c indexPathString on @c .group and update @c .indexPath if current value is different.
- (void)calculateAndSetIndexPathString {
	NSString *pthStr = [self.group indexPathString];
	if (![self.indexPath isEqualToString:pthStr])
		self.indexPath = pthStr;
}

/// @return Fully initialized @c NSMenuItem with @c title, @c tooltip, @c image, and @c action.
- (NSMenuItem*)newMenuItem {
	NSMenuItem *item = [NSMenuItem new];
	item.title = self.group.nameOrError;
	item.toolTip = self.subtitle;
	item.enabled = (self.articles.count > 0);
	item.image = [self iconImage16];
	item.representedObject = self.indexPath;
	item.target = [self class];
	item.action = @selector(didClickOnMenuItem:);
	return item;
}

/// Callback method for @c NSMenuItem. Will open url associated with @c Feed.
+ (void)didClickOnMenuItem:(NSMenuItem*)sender {
	NSString *url = [StoreCoordinator urlForFeedWithIndexPath:sender.representedObject];
	if (url && url.length > 0)
		[UserPrefs openURLsWithPreferredBrowser:@[[NSURL URLWithString:url]]];
}


#pragma mark - Update Feed Items -


/**
 Replace feed title, subtitle and link (if changed). Also adds new articles and removes old ones.
 */
- (void)updateWithRSS:(RSParsedFeed*)obj postUnreadCountChange:(BOOL)flag {
	if (![self.title isEqualToString:obj.title])       self.title = obj.title;
	if (![self.subtitle isEqualToString:obj.subtitle]) self.subtitle = obj.subtitle;
	if (![self.link isEqualToString:obj.link])         self.link = obj.link;
	
	if (self.group.name.length == 0) // in case a blank group was initialized
		self.group.name = obj.title;
	
	// Add and remove articles
	NSMutableSet<NSString*> *urls = [[self.articles valueForKeyPath:@"link"] mutableCopy];
	NSInteger diff = [self addMissingArticles:obj updateLinks:urls]; // will remove links in 'urls' that should be kept
	diff -= [self deleteArticlesWithLink:urls]; // remove old, outdated articles
	// Get new total article count and post unread-count-change notification
	if (flag && diff != 0) {
		[[NSNotificationCenter defaultCenter] postNotificationName:kNotificationTotalUnreadCountChanged object:@(diff)];
	}
}

/**
 Append new articles and increment their sortIndex. Update unread counter on the way.
 
 @note
 New articles should be in ascending order without any gaps in between.
 If new article is disjunct from the article before, assume a deleted article re-appeared and mark it as read.
 
 @param urls Input will be used to identify new articles. Output will contain URLs that aren't present in the feed anymore.
 */
- (NSInteger)addMissingArticles:(RSParsedFeed*)obj updateLinks:(NSMutableSet<NSString*>*)urls {
	NSInteger newOnes = 0;
	int32_t currentIndex = [[self.articles valueForKeyPath:@"@min.sortIndex"] intValue];
	FeedArticle *lastInserted = nil;
	BOOL hasGapBetweenNewArticles = NO;
	
	for (RSParsedArticle *article in [obj.articles reverseObjectEnumerator]) {
		// reverse enumeration ensures correct article order
		if ([urls containsObject:article.link]) {
			[urls removeObject:article.link];
			FeedArticle *storedArticle = [self findArticleWithLink:article.link]; // TODO: use two synced arrays?
			if (storedArticle && storedArticle.sortIndex != currentIndex) {
				storedArticle.sortIndex = currentIndex;
			}
			hasGapBetweenNewArticles = YES;
		} else {
			newOnes += 1;
			if (hasGapBetweenNewArticles && lastInserted) { // gap with at least one article inbetween
				lastInserted.unread = NO;
				newOnes -= 1;
			}
			hasGapBetweenNewArticles = NO;
			lastInserted = [FeedArticle newArticle:article inContext:self.managedObjectContext];
			lastInserted.sortIndex = currentIndex;
			[self addArticlesObject:lastInserted];
		}
		currentIndex += 1;
	}
	if (hasGapBetweenNewArticles && lastInserted) {
		lastInserted.unread = NO;
		newOnes -= 1;
	}
	return newOnes;
}

/**
 Delete all items where @c link matches one of the URLs in the @c NSSet.
 */
- (NSUInteger)deleteArticlesWithLink:(NSMutableSet<NSString*>*)urls {
	if (!urls || urls.count == 0)
		return 0;
	NSUInteger c = 0;
	for (FeedArticle *fa in self.articles) {
		if ([urls containsObject:fa.link]) {
			[urls removeObject:fa.link];
			if (fa.unread) ++c;
			// TODO: keep unread articles?
			[self.managedObjectContext deleteObject:fa];
			if (urls.count == 0)
				break;
		}
	}
	NSSet<FeedArticle*> *delArticles = [self.managedObjectContext deletedObjects];
	if (delArticles.count > 0) {
		[self removeArticles:delArticles];
	}
	return c;
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
 Iterate over all Articles and return the one where @c .link matches. Or @c nil if no matching article found.
 */
- (FeedArticle*)findArticleWithLink:(NSString*)url {
	for (FeedArticle *a in self.articles) {
		if ([a.link isEqualToString:url])
			return a;
	}
	return nil;
}


#pragma mark - Icon -


/**
 @return Return @c 16x16px image. Either from core data storage or generated default RSS icon.
 */
- (NSImage*)iconImage16 {
	NSData *imgData = self.icon.icon;
	if (imgData)
	{
		NSImage *img = [[NSImage alloc] initWithData:imgData];
		[img setSize:NSMakeSize(16, 16)];
		return img;
	}
	else if (self.articles.count == 0)
	{
		static NSImage *warningIcon;
		if (!warningIcon) {
			warningIcon = [NSImage imageNamed:NSImageNameCaution];
			[warningIcon setSize:NSMakeSize(16, 16)];
		}
		return warningIcon;
	}
	else
	{
		static NSImage *defaultRSSIcon; // TODO: setup imageNamed: for default rss icon
		if (!defaultRSSIcon)
			defaultRSSIcon = [RSSIcon iconWithSize:16];
		return defaultRSSIcon;
	}
}

/**
 Set favicon icon or delete relationship if @c img is not a valid image.
 
 @return @c YES if icon was updated (core data did change).
*/
- (BOOL)setIconImage:(NSImage*)img {
	if (img && [img isValid]) {
		if (!self.icon)
			self.icon = [[FeedIcon alloc] initWithEntity:FeedIcon.entity insertIntoManagedObjectContext:self.managedObjectContext];
		self.icon.icon = [img TIFFRepresentation];
		return YES;
	} else if (self.icon) {
		[self.managedObjectContext deleteObject:self.icon];
		self.icon = nil;
		return YES;
	}
	return NO;
}

@end
