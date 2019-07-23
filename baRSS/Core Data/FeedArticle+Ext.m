//
//  The MIT License (MIT)
//  Copyright (c) 2019 Oleg Geier
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

#import "FeedArticle+Ext.h"
#import "Constants.h"
#import "UserPrefs.h"
#import "StoreCoordinator.h"

#import <RSXML/RSParsedArticle.h>

@implementation FeedArticle (Ext)

/// Create new article based on RSXML article input.
+ (instancetype)newArticle:(RSParsedArticle*)entry inContext:(NSManagedObjectContext*)moc {
	FeedArticle *fa = [[FeedArticle alloc] initWithEntity:FeedArticle.entity insertIntoManagedObjectContext:moc];
	fa.unread = YES;
	fa.guid = entry.guid;
	fa.title = entry.title;
	if (entry.abstract.length > 0) { // remove html tags and save plain text to db
		NSRegularExpression *regex = [NSRegularExpression regularExpressionWithPattern:@"<[^>]*>" options:kNilOptions error:nil];
		fa.abstract = [regex stringByReplacingMatchesInString:entry.abstract options:kNilOptions range:NSMakeRange(0, entry.abstract.length) withTemplate:@""];
	}
	fa.body = entry.body;
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
	if ([UserPrefs defaultNO:@"feedShortNames"]) {
		NSUInteger limit = [UserPrefs shortArticleNamesLimit];
		if (title.length > limit)
			title = [NSString stringWithFormat:@"%@…", [title substringToIndex:limit-1]];
	}
	return title;
}

/// @return Fully initialized @c NSMenuItem with @c title, @c tooltip, @c tickmark, and @c action.
- (NSMenuItem*)newMenuItem {
	NSMenuItem *item = [NSMenuItem new];
	item.title = [self shortArticleName];
	item.enabled = (self.link.length > 0);
	item.state = (self.unread && [UserPrefs defaultYES:@"feedTickMark"] ? NSControlStateValueOn : NSControlStateValueOff);
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
		success = [UserPrefs openURLsWithPreferredBrowser:@[[NSURL URLWithString:url]]];
	if (flipUnread || (success && fa.unread)) {
		fa.unread = !fa.unread;
		[StoreCoordinator saveContext:moc andParent:YES];
		NSNumber *num = (fa.unread ? @+1 : @-1);
		[[NSNotificationCenter defaultCenter] postNotificationName:kNotificationTotalUnreadCountChanged object:num];
	}
	[moc reset];
}

@end
