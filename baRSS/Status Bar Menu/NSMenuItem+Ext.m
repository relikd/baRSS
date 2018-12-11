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

#import "NSMenuItem+Ext.h"
#import "NSMenu+Ext.h"
#import "StoreCoordinator.h"
#import "DrawImage.h"
#import "UserPrefs.h"
#import "FeedGroup+Ext.h"

/// User preferences for displaying menu items
typedef NS_ENUM(char, DisplaySetting) {
	/// User preference not available. @c NSMenuItem is not configurable (not a header item)
	INVALID,
	/// User preference to display this item
	ALLOW,
	/// User preference to hide this item
	PROHIBIT
};


@implementation NSMenuItem (Feed)

#pragma mark - General helper methods -

/**
 Helper method to generate a new @c NSMenuItem.
 */
+ (NSMenuItem*)itemWithTitle:(NSString*)title action:(SEL)selector target:(id)target tag:(MenuItemTag)tag {
	NSMenuItem *item = [[NSMenuItem alloc] initWithTitle:title action:selector keyEquivalent:@""];
	item.target = target;
	item.tag = tag;
	[item applyUserSettingsDisplay];
	return item;
}

/**
 Create a copy of an existing menu item and set it's option key modifier.
 */
- (NSMenuItem*)alternateWithTitle:(NSString*)title {
	NSMenuItem *alt = [self copy];
	alt.title = title;
	alt.keyEquivalentModifierMask = NSEventModifierFlagOption;
	if (!alt.hidden) { // hidden will be ignored if alternate is YES
		alt.hidden = YES; // force hidden to hide if menu is already open (background update)
		alt.alternate = YES;
	}
	return alt;
}

/**
 Convenient method to set @c target and @c action simultaneously.
 */
- (void)setTarget:(id)target action:(SEL)selector {
	self.target = target;
	self.action = selector;
}


#pragma mark - Set properties based on Core Data object -


/**
 Set title based on preferences either with or without unread count in parenthesis.
 
 @return Number of unread items. (@b warning: May return @c 0 if visibility is disabled in @c UserPrefs)
 */
- (NSInteger)setTitleAndUnreadCount:(FeedGroup*)fg {
	NSInteger uCount = 0;
	if (fg.typ == FEED && [UserPrefs defaultYES:@"feedUnreadCount"]) {
		uCount = fg.feed.unreadCount;
	} else if (fg.typ == GROUP && [UserPrefs defaultYES:@"groupUnreadCount"]) {
		uCount = [self.submenu coreDataUnreadCount];
	}
	self.title = (uCount > 0 ? [NSString stringWithFormat:@"%@ (%ld)", fg.name, uCount] : fg.name);
	return uCount;
}

/**
 Fully configures a Separator item OR group item OR feed item. (but not @c FeedArticle item)
 */
- (void)setFeedGroup:(FeedGroup*)fg {
	self.representedObject = fg.objectID;
	if (fg.typ == SEPARATOR) {
		self.title = kSeparatorItemTitle;
	} else {
		self.submenu = [self.menu submenuWithIndex:fg.sortIndex isFeed:(fg.typ == FEED)];
		[self setTitleAndUnreadCount:fg]; // after submenu is set
		if (fg.typ == FEED) {
			[self configureAsFeed:fg];
		} else {
			[self configureAsGroup:fg];
		}
	}
}

/**
 Configure menu item to be used as a container for @c FeedArticle entries (incl. feed icon).
 */
- (void)configureAsFeed:(FeedGroup*)fg {
	self.tag = ScopeFeed;
	self.toolTip = fg.feed.subtitle;
	self.enabled = (fg.feed.articles.count > 0);
	// set icon
	dispatch_async(dispatch_get_main_queue(), ^{
		static NSImage *defaultRSSIcon;
		if (!defaultRSSIcon)
			defaultRSSIcon = [RSSIcon iconWithSize:16];
		self.image = defaultRSSIcon;
	});
}

/**
 Configure menu item to be used as a container for multiple feeds.
 */
- (void)configureAsGroup:(FeedGroup*)fg {
	self.tag = ScopeGroup;
	self.enabled = (fg.children.count > 0);
	// set icon
	dispatch_async(dispatch_get_main_queue(), ^{
		static NSImage *groupIcon;
		if (!groupIcon) {
			groupIcon = [NSImage imageNamed:NSImageNameFolder];
			groupIcon.size = NSMakeSize(16, 16);
		}
		self.image = groupIcon;
	});
}

/**
 Populate @c NSMenuItem based on the attributes of a @c FeedArticle.
 */
- (void)setFeedArticle:(FeedArticle*)fa {
	self.title = fa.title;
	// TODO: It should be enough to get user prefs once per menu build
	if ([UserPrefs defaultNO:@"feedShortNames"]) {
		NSUInteger limit = [UserPrefs shortArticleNamesLimit];
		if (self.title.length > limit)
			self.title = [NSString stringWithFormat:@"%@…", [self.title substringToIndex:limit-1]];
	}
	self.tag = ScopeFeed;
	self.enabled = (fa.link.length > 0);
	self.state = (fa.unread && [UserPrefs defaultYES:@"feedTickMark"] ? NSControlStateValueOn : NSControlStateValueOff);
	self.representedObject = fa.objectID;
	//mi.toolTip = item.abstract;
	// TODO: Do regex during save, not during display. Its here for testing purposes ...
	if (fa.abstract.length > 0) {
		NSRegularExpression *regex = [NSRegularExpression regularExpressionWithPattern:@"<[^>]*>" options:kNilOptions error:nil];
		self.toolTip = [regex stringByReplacingMatchesInString:fa.abstract options:kNilOptions range:NSMakeRange(0, fa.abstract.length) withTemplate:@""];
	}
}

#pragma mark - Helper -

/**
 @return @c FeedGroup object if @c representedObject contains a valid @c NSManagedObjectID.
 */
- (FeedGroup*)requestGroup:(NSManagedObjectContext*)moc {
	if (!self.representedObject || ![self.representedObject isKindOfClass:[NSManagedObjectID class]])
		return nil;
	FeedGroup *fg = [moc objectWithID:self.representedObject];
	if (![fg isKindOfClass:[FeedGroup class]])
		return nil;
	return fg;
}

/**
 Perform @c block on every @c FeedGroup in the items menu or any of its submenues.

 @param ordered Whether order matters or not. If all items are processed anyway, pass @c NO for a speedup.
 @param block Set cancel to @c YES to stop enumeration early.
 */
- (void)iterateSorted:(BOOL)ordered inContext:(NSManagedObjectContext*)moc overDescendentFeeds:(void(^)(Feed*,BOOL*))block {
	if (self.parentItem) {
		[[self.parentItem requestGroup:moc] iterateSorted:ordered overDescendantFeeds:block];
	} else {
		for (NSMenuItem *item in self.menu.itemArray) {
			FeedGroup *fg = [item requestGroup:moc];
			if (fg != nil) { // All groups and feeds; Ignore default header
				if (![fg iterateSorted:ordered overDescendantFeeds:block])
					return;
			}
		}
	}
}

/**
 Check user preferences for preferred display style.
 
 @return As per user settings return @c ALLOW or @c PROHIBIT. Will return @c INVALID for items that aren't configurable.
 */
- (DisplaySetting)allowsDisplay {
	NSString *prefix;
	switch (self.tag & TagMaskScope) {
		case ScopeFeed: prefix = @"feed"; break;
		case ScopeGroup: prefix = @"group"; break;
		case ScopeGlobal: prefix = @"global"; break;
		default: return INVALID; // no scope, not recognized menu item
	}
	NSString *postfix;
	switch (self.tag & TagMaskType) {
		case TagOpenAllUnread: postfix = @"OpenUnread"; break;
		case TagMarkAllRead: postfix = @"MarkRead"; break;
		case TagMarkAllUnread: postfix = @"MarkUnread"; break;
		default: return INVALID; // wrong tag, ignore
	}
	
	if ([UserPrefs defaultYES:[prefix stringByAppendingString:postfix]])
		return ALLOW;
	return PROHIBIT;
}

/**
 Set item @c hidden based on user preferences. Does nothing for items that aren't configurable in settings.
 */
- (void)applyUserSettingsDisplay {
	switch ([self allowsDisplay]) {
		case ALLOW:
			self.hidden = NO;
			if (self.keyEquivalentModifierMask == NSEventModifierFlagOption)
				self.alternate = YES; // restore alternate flag
			break;
		case PROHIBIT:
			if (self.isAlternate)
				self.alternate = NO; // to allow hidden = YES, alternate flag needs to be NO
			self.hidden = YES;
			break;
		case INVALID: break;
	}
}

@end
