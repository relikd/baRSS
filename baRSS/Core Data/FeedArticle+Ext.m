@import RSXML2.RSParsedArticle;
#import "FeedArticle+Ext.h"
#import "Constants.h"
#import "UserPrefs.h"
#import "StoreCoordinator.h"
#import "NSString+Ext.h"

@implementation FeedArticle (Ext)

/// Create new article based on RSXML article input.
+ (instancetype)newArticle:(RSParsedArticle*)entry inContext:(NSManagedObjectContext*)moc {
	FeedArticle *fa = [[FeedArticle alloc] initWithEntity:FeedArticle.entity insertIntoManagedObjectContext:moc];
	fa.unread = YES;
	fa.guid = entry.guid;
	fa.title = entry.title;
	if (entry.abstract.length > 0)
		fa.abstract = [entry.abstract htmlToPlainText];
	if (entry.body.length > 0)
		fa.body = [entry.body htmlToPlainText];
	fa.author = entry.author;
	fa.link = entry.link;
	fa.published = entry.datePublished;
	if (!fa.link)      fa.link = entry.guid;  // may be wrong, but better than returning nothing.
	if (!fa.published) fa.published = entry.dateModified;
	return fa;
}

- (void)updateArticleIfChanged:(RSParsedArticle*)entry {
	[self setGuidIfChanged:entry.guid];
	[self setTitleIfChanged:entry.title];
	[self setAuthorIfChanged:entry.author];
	[self setAbstractIfChanged:(entry.abstract.length > 0) ? [entry.abstract htmlToPlainText] : nil];
	[self setBodyIfChanged:(entry.body.length > 0) ? [entry.body htmlToPlainText] : nil];
	[self setLinkIfChanged:(entry.link.length > 0) ? entry.link : entry.guid];
	[self setPublishedIfChanged:entry.datePublished ? entry.datePublished : entry.dateModified];
}

/// @return Full or truncated article title, based on user preference in settings.
- (NSString*)shortArticleName {
	NSString *title = self.title;
	if (!title) return @"";
	// TODO: It should be enough to get user prefs once per menu build
	if (UserPrefsBool(Pref_feedTruncateTitle)) {
		NSUInteger limit = UserPrefsUInt(Pref_shortArticleNamesLimit);
		if (title.length > limit)
			title = [[title substringToIndex:limit] stringByAppendingString:@"…"];
	}
	return title;
}

/// @return Fully initialized @c NSMenuItem with @c title, @c tooltip, @c unread-indicator, and @c action.
- (NSMenuItem*)newMenuItem {
	NSMenuItem *item = [NSMenuItem new];
	item.title = [self shortArticleName];
	item.enabled = (self.link.length > 0);
	item.state = (self.unread && UserPrefsBool(Pref_feedUnreadIndicator) ? NSControlStateValueOn : NSControlStateValueOff);
	item.onStateImage = [NSImage imageNamed:RSSImageMenuItemUnread];
	item.accessibilityLabel = (self.unread ? NSLocalizedString(@"article: unread", @"accessibility label, feed menu item") : NSLocalizedString(@"article: read", @"accessibility label, feed menu item"));
	item.toolTip = (self.abstract ? self.abstract : self.body); // fall back to body (html)
	item.representedObject = self.objectID;
	item.target = [self class];
	item.action = @selector(didClickOnMenuItem:);
	return item;
}

/// Callback method for @c NSMenuItem. Will open url associated with @c FeedArticle and mark it read.
+ (void)didClickOnMenuItem:(NSMenuItem*)sender {
	BOOL flipUnread = (([NSEvent modifierFlags] & NSEventModifierFlagOption) != 0);
	NSManagedObjectContext *moc = [StoreCoordinator createChildContext];
	FeedArticle *fa = [moc objectWithID:sender.representedObject];
	NSString *url = fa.link;
	BOOL success = NO;
	if (url && url.length > 0 && !flipUnread) // flipUnread == change unread state
		success = UserPrefsOpenURL(url);
	if (flipUnread || (success && fa.unread)) {
		fa.unread = !fa.unread;
		[StoreCoordinator saveContext:moc andParent:YES];
		NSNumber *num = (fa.unread ? @+1 : @-1);
		PostNotification(kNotificationTotalUnreadCountChanged, num);
	}
	[moc reset];
}


#pragma mark - Setter -


/// Set @c guid attribute but only if value differs.
- (void)setGuidIfChanged:(nullable NSString*)guid {
	if (guid.length == 0) {
		if (self.guid.length > 0)
			self.guid = nil; // nullify empty strings
	} else if (![self.guid isEqualToString: guid]) {
		self.guid = guid;
	}
}

/// Set @c link attribute but only if value differs.
- (void)setLinkIfChanged:(nullable NSString*)link {
	if (link.length == 0) {
		if (self.link.length > 0)
			self.link = nil; // nullify empty strings
	} else if (![self.link isEqualToString: link]) {
		self.link = link;
	}
}

/// Set @c title attribute but only if value differs.
- (void)setTitleIfChanged:(nullable NSString*)title {
	if (title.length == 0) {
		if (self.title.length > 0)
			self.title = nil; // nullify empty strings
	} else if (![self.title isEqualToString: title]) {
		self.title = title;
	}
}

/// Set @c abstract attribute but only if value differs.
- (void)setAbstractIfChanged:(nullable NSString*)abstract {
	if (abstract.length == 0) {
		if (self.abstract.length > 0)
			self.abstract = nil; // nullify empty strings
	} else if (![self.abstract isEqualToString: abstract]) {
		self.abstract = abstract;
	}
}

/// Set @c body attribute but only if value differs.
- (void)setBodyIfChanged:(nullable NSString*)body {
	if (body.length == 0) {
		if (self.body.length > 0)
			self.body = nil; // nullify empty strings
	} else if (![self.body isEqualToString: body]) {
		self.body = body;
	}
}

/// Set @c author attribute but only if value differs.
- (void)setAuthorIfChanged:(nullable NSString*)author {
	if (author.length == 0) {
		if (self.author.length > 0)
			self.author = nil; // nullify empty strings
	} else if (![self.author isEqualToString: author]) {
		self.author = author;
	}
}

/// Set @c published attribute but only if value differs.
- (void)setPublishedIfChanged:(nullable NSDate*)published {
	if (!published) {
		if (self.published)
			self.published = nil; // nullify empty date
	} else if (![self.published isEqualToDate: published]) {
		self.published = published;
	}
}

@end
