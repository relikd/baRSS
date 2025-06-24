@import RSXML2;
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
	// Tooltip disabled (feed-group only) because it causes issues on macOS Ventura.
	// Menu opens invisibly (OrderNSWindow: unsupported window ordering op -1)
	// steps to reproduce:
	//  1. hover over a feed-group menu item until tooltip pops up
	//  2. hover over another feed with tooltip
	//  3. go back to previous feed.
//	item.toolTip = self.subtitle;
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
		UserPrefsOpenURL(url);
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
 Append new articles and increment @c sortIndex and unread count.
 New articles are in ascending order without any gaps in between.
 
 @param localSet Use result set of @c deleteArticles:withRemoteSet:
 */
- (NSUInteger)insertArticles:(NSMutableSet<FeedArticle*>*)localSet withRemoteSet:(NSArray<RSParsedArticle*>*)remoteSet {
	int32_t currentIndex = [[localSet valueForKeyPath:@"@min.sortIndex"] intValue];
	NSUInteger c = 0;
	for (RSParsedArticle *article in [remoteSet reverseObjectEnumerator]) {
		// Reverse enumeration ensures correct article order
		FeedArticle *stored = [self findRemoteArticle:article inLocalSet:localSet];
		if (stored) {
			[localSet removeObject:stored];
			if (stored.sortIndex != currentIndex)
				stored.sortIndex = currentIndex; // Ensures block of ascending indices
			// replace local values with remote changes (if any)
			[stored updateArticleIfChanged:article];
		} else {
			FeedArticle *newArticle = [FeedArticle newArticle:article inContext:self.managedObjectContext];
			newArticle.sortIndex = currentIndex;
			[self addArticlesObject:newArticle];
			c += 1;
		}
		currentIndex += 1;
	}
	return c;
}

/**
 Delete all articles from core data, that aren't present anymore.
 
 @param localSet Input a copy of @c self.articles . Output same set minus deleted articles.
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
- (nullable NSArray<FeedArticle*>*)sortedArticles {
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
	for (FeedArticle *art in localSet) {
		// assuming if a guid is set, it will always be unique
		if (searchGuid != nil) {
			if ([art.guid isEqualToString:searchGuid])
				return art;
		} else if (searchLink != nil) {
			if ([art.link isEqualToString:searchLink])
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
	for (RSParsedArticle *art in remoteSet) {
		// assuming if a guid is set, it will always be unique
		if (searchGuid != nil) {
			if ([art.guid isEqualToString:searchGuid])
				return art;
		} else if (searchLink != nil) {
			if ([art.link isEqualToString:searchLink])
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
		NSData* data = [[NSData alloc] initWithContentsOfURL:[self iconPath]];
		img = [[NSImage alloc] initWithData:data];
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
	return [[NSURL faviconsCacheURL] file:self.objectID.URIRepresentation.lastPathComponent ext:nil];
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
