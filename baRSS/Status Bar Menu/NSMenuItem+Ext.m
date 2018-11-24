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
 Set title based on preferences either with or without unread count in parenthesis.
 */
- (void)setTitleAndUnreadCount:(FeedConfig*)config {
	if (config.unreadCount > 0 &&
		((config.typ == FEED && [UserPrefs defaultYES:@"feedUnreadCount"]) ||
		 (config.typ == GROUP && [UserPrefs defaultYES:@"groupUnreadCount"])))
	{
		self.title = [NSString stringWithFormat:@"%@ (%d)", config.name, config.unreadCount];
	} else {
		self.title = config.name;
	}
}

/**
 Fully configures a Separator item OR group item OR feed item. (but not @c FeedItem item)
 */
- (void)setFeedConfig:(FeedConfig*)config {
	self.representedObject = config.objectID;
	if (config.typ == SEPARATOR) {
		self.title = @"---SEPARATOR---";
	} else {
		[self setTitleAndUnreadCount:config];
		self.submenu = [self.menu submenuWithIndex:config.sortIndex isFeed:(config.typ == FEED)];
		if (config.typ == FEED) {
			[self configureAsFeed:config];
		} else {
			[self configureAsGroup:config];
		}
	}
}

/**
 Configure menu item to be used as a container for @c FeedItem entries (incl. feed icon).
 */
- (void)configureAsFeed:(FeedConfig*)config {
	self.tag = ScopeFeed;
	self.toolTip = config.feed.subtitle;
	self.enabled = (config.feed.items.count > 0);
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
- (void)configureAsGroup:(FeedConfig*)config {
	self.tag = ScopeGroup;
	self.enabled = (config.children.count > 0);
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
 Populate @c NSMenuItem based on the attributes of a @c FeedItem.
 */
- (void)setFeedItem:(FeedItem*)item {
	self.title = item.title;
	self.tag = ScopeFeed;
	self.enabled = (item.link.length > 0);
	self.state = (item.unread ? NSControlStateValueOn : NSControlStateValueOff);
	self.representedObject = item.objectID;
	//mi.toolTip = item.abstract;
	// TODO: Do regex during save, not during display. Its here for testing purposes ...
	if (item.abstract.length > 0) {
		NSRegularExpression *regex = [NSRegularExpression regularExpressionWithPattern:@"<[^>]*>" options:kNilOptions error:nil];
		self.toolTip = [regex stringByReplacingMatchesInString:item.abstract options:kNilOptions range:NSMakeRange(0, item.abstract.length) withTemplate:@""];
	}
}

#pragma mark - Helper -

/**
 @return @c FeedConfig object if @c representedObject contains a valid @c NSManagedObjectID.
 */
- (FeedConfig*)feedConfig:(NSManagedObjectContext*)moc {
	if (!self.representedObject || ![self.representedObject isKindOfClass:[NSManagedObjectID class]])
		return nil;
	FeedConfig *config = [moc objectWithID:self.representedObject];
	if (![config isKindOfClass:[FeedConfig class]])
		return nil;
	return config;
}

/**
 Perform @c block on every @c FeedConfig in the items menu or any of its submenues.

 @param ordered Whether order matters or not. If all items are processed anyway, pass @c NO for a speedup.
 @param block Set cancel to @c YES to stop enumeration early.
 */
- (void)iterateSorted:(BOOL)ordered inContext:(NSManagedObjectContext*)moc overDescendentFeeds:(void(^)(Feed*,BOOL*))block {
	if (self.parentItem) {
		[[self.parentItem feedConfig:moc] iterateSorted:ordered overDescendantFeeds:block];
	} else {
		for (NSMenuItem *item in self.menu.itemArray) {
			FeedConfig *fc = [item feedConfig:moc];
			if (fc != nil) { // All groups and feeds; Ignore default header
				if (![fc iterateSorted:ordered overDescendantFeeds:block])
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
