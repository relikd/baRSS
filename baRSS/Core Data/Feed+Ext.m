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

@import RSXML;
#import "Feed+Ext.h"
#import "Constants.h"
#import "UserPrefs.h"
#import "FeedMeta+Ext.h"
#import "FeedGroup+Ext.h"
#import "FeedArticle+Ext.h"
#import "StoreCoordinator.h"
#import "NSURL+Ext.h"

@implementation Feed (Ext)

/// Instantiates new @c Feed and @c FeedMeta entities in context.
+ (instancetype)newFeedAndMetaInContext:(NSManagedObjectContext*)moc {
	Feed *feed = [[Feed alloc] initWithEntity:Feed.entity insertIntoManagedObjectContext:moc];
	feed.meta = [FeedMeta newMetaInContext:moc];
	return feed;
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
	item.title = self.group.anyName;
	item.toolTip = self.subtitle;
	item.enabled = (self.articles.count > 0);
	item.image = self.iconImage16;
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
	
	// Add and remove articles
	NSMutableSet<FeedArticle*> *localSet = [self.articles mutableCopy];
	NSInteger diff = 0;
	diff -= [self deleteArticles:localSet withRemoteSet:obj.articles]; // remove old, outdated articles
	diff += [self insertArticles:localSet withRemoteSet:obj.articles]; // insert new in correct order
	// Get new total article count and post unread-count-change notification
	if (flag && diff != 0) {
		PostNotification(kNotificationTotalUnreadCountChanged, @(diff));
	}
}

/**
 Append new articles and increment their sortIndex. Update unread counter on the way.
 
 @note
 New articles should be in ascending order without any gaps in between.
 If new article is disjunct from the article before, assume a deleted article re-appeared and mark it as read.
 
 @param localSet Use result set @c localSet of method call @c deleteArticles:withRemoteSet:.
 @param remoteSet Readonly copy of @c RSParsedFeed.articles.
 */
- (NSUInteger)insertArticles:(NSMutableSet<FeedArticle*>*)localSet withRemoteSet:(NSArray<RSParsedArticle*>*)remoteSet {
	int32_t currentIndex = [[localSet valueForKeyPath:@"@min.sortIndex"] intValue];
	NSMutableArray<FeedArticle*>* newlyInserted = [NSMutableArray arrayWithCapacity:remoteSet.count];
	
	for (RSParsedArticle *article in [remoteSet reverseObjectEnumerator]) {
		// reverse enumeration ensures correct article order
		FeedArticle *storedArticle = [self findRemoteArticle:article inLocalSet:localSet];
		if (storedArticle) {
			// TODO: stop bullshitting with ghost articles
			[localSet removeObject:storedArticle];
			// If we encounter an already existing item, assume newly inserted are "ghost" items and mark read.
			if (newlyInserted.count > 0) {
				for (FeedArticle *ghostItem in newlyInserted) {
					ghostItem.unread = NO;
				}
				[newlyInserted removeAllObjects];
			}
			// Ensures consecutive block of incrementing numbers on sortIndex
			if (storedArticle.sortIndex != currentIndex) {
				storedArticle.sortIndex = currentIndex;
			}
		} else {
			FeedArticle *newArticle = [FeedArticle newArticle:article inContext:self.managedObjectContext];
			newArticle.sortIndex = currentIndex;
			[self addArticlesObject:newArticle];
			[newlyInserted addObject:newArticle];
		}
		currentIndex += 1;
	}
	return newlyInserted.count; // all ghost items are removed already
}

/**
 Delete all articles from core data, that aren't present anymore.
 
 @param localSet Input a copy of @c self.articles. Output the same set minus deleted articles.
 @param remoteSet Readonly copy of @c RSParsedFeed.articles.
 */
- (NSUInteger)deleteArticles:(NSMutableSet<FeedArticle*>*)localSet withRemoteSet:(NSArray<RSParsedArticle*>*)remoteSet {
	NSUInteger c = 0;
	NSMutableSet<FeedArticle*> *deletingSet = [NSMutableSet setWithCapacity:localSet.count];
	for (FeedArticle *fa in localSet) {
		if (![self findLocalArticle:fa inRemoteSet:remoteSet]) {
			if (fa.unread) ++c;
			// TODO: keep unread articles?
			[self.managedObjectContext deleteObject:fa];
			[deletingSet addObject:fa];
		}
	}
	if (deletingSet.count > 0) {
		[localSet minusSet:deletingSet];
		[self removeArticles:deletingSet];
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
 Iterate over localSet and return the one where @c link and @c guid matches. Or @c nil if no matching article found.
 */
- (FeedArticle*)findRemoteArticle:(RSParsedArticle*)remote inLocalSet:(NSSet<FeedArticle*>*)localSet {
	NSString *searchLink = remote.link;
	NSString *searchGuid = remote.guid;
	BOOL linkIsNil = (searchLink == nil);
	BOOL guidIsNil = (searchGuid == nil);
	for (FeedArticle *art in localSet) {
		if ((linkIsNil && art.link == nil) || (!linkIsNil && [art.link isEqualToString:searchLink])) {
			if ((guidIsNil && art.guid == nil) || (!guidIsNil && [art.guid isEqualToString:searchGuid]))
				return art;
		}
	}
	return nil;
}

/**
 Iterate over remoteSet and return the one where @c link and @c guid matches. Or @c nil if no matching article found.
 */
- (RSParsedArticle*)findLocalArticle:(FeedArticle*)local inRemoteSet:(NSArray<RSParsedArticle*>*)remoteSet {
	NSString *searchLink = local.link;
	NSString *searchGuid = local.guid;
	BOOL linkIsNil = (searchLink == nil);
	BOOL guidIsNil = (searchGuid == nil);
	for (RSParsedArticle *art in remoteSet) {
		if ((linkIsNil && art.link == nil) || (!linkIsNil && [art.link isEqualToString:searchLink])) {
			if ((guidIsNil && art.guid == nil) || (!guidIsNil && [art.guid isEqualToString:searchGuid]))
				return art;
		}
	}
	return nil;
}


#pragma mark - Icon -


/// @return @c 16x16px image. Either from favicon cache or generated default RSS icon.
- (nonnull NSImage*)iconImage16 {
	NSImage *img = nil;
	if (self.articles.count == 0) {
		img = [NSImage imageNamed:NSImageNameCaution];
	} else if (self.hasIcon) {
		img = [[NSImage alloc] initByReferencingURL:[self iconPath]];
	} else {
		img = [NSImage imageNamed:RSSImageDefaultRSSIcon];
	}
	[img setSize:NSMakeSize(16, 16)];
	return img;
}

/// Checks if file at @c iconPath is an actual file
- (BOOL)hasIcon { return [[self iconPath] existsAndIsDir:NO]; }

/// Image file path at e.g., "Application Support/baRSS/favicons/p42". @warning File may not exist!
- (NSURL*)iconPath {
	NSString *pk = self.objectID.URIRepresentation.lastPathComponent;
	return [[NSURL faviconsCacheURL] URLByAppendingPathComponent:pk isDirectory:NO];
}

/// Move favicon from @c $TMPDIR to permanent destination in Application Support.
- (void)setNewIcon:(NSURL*)location {
	if (!location) {
		[[self iconPath] remove];
	} else {
		if (self.objectID.isTemporaryID) {
			[self.managedObjectContext obtainPermanentIDsForObjects:@[self] error:nil];
		}
		[location moveTo:[self iconPath]];
		PostNotification(kNotificationFeedIconUpdated, self.objectID);
	}
}

@end
