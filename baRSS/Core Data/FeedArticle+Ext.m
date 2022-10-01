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

@end
