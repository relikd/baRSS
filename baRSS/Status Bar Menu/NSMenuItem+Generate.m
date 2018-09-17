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

#import "NSMenuItem+Generate.h"
#import "NSMenuItem+Info.h"
#import "StoreCoordinator.h"
#import "DrawImage.h"

@implementation NSMenuItem (Feed)
/**
 Generate a new @c NSMenuItem based on the type stored in @c FeedConfig.
 
 @param config @c FeedConfig object that represents a superior feed element.
 @return Return a fully configured Separator item OR group item OR feed item. (but not @c FeedItem item)
 */
+ (NSMenuItem*)feedConfig:(FeedConfig*)config {
	NSMenuItem *item;
	switch (config.typ) {
		case SEPARATOR: item = [NSMenuItem separatorItem]; break;
		case GROUP: item = [self feedConfigItemGroup:config]; break;
		case FEED: item = [self feedConfigItemFeed:config]; break;
	}
	[item setReaderInfo:config.objectID unread:0];
	return item;
}

/**
 Generate a new @c NSMenuItem from a @c FeedConfig feed item.
 
 @param config @c FeedConfig object that represents a superior feed element.
 */
+ (NSMenuItem*)feedConfigItemFeed:(FeedConfig*)config {
	NSMenuItem *item = [[NSMenuItem alloc] initWithTitle:config.name action:nil keyEquivalent:@""];
	item.toolTip = config.feed.subtitle;
	item.enabled = (config.feed.items.count > 0);
	item.tag = ScopeFeed;
	// set icon
	dispatch_async(dispatch_get_main_queue(), ^{
		static NSImage *defaultRSSIcon;
		if (!defaultRSSIcon)
			defaultRSSIcon = [RSSIcon iconWithSize:16];
		item.image = defaultRSSIcon;
	});
	return item;
}

/**
 Generate a new @c NSMenuItem from a @c FeedConfig group item
 
 @param config @c FeedConfig object that represents a group item.
 */
+ (NSMenuItem*)feedConfigItemGroup:(FeedConfig*)config {
	NSMenuItem *item = [[NSMenuItem alloc] initWithTitle:config.name action:nil keyEquivalent:@""];
	item.tag = ScopeGroup;
	// set icon
	dispatch_async(dispatch_get_main_queue(), ^{
		static NSImage *groupIcon;
		if (!groupIcon) {
			groupIcon = [NSImage imageNamed:NSImageNameFolder];
			groupIcon.size = NSMakeSize(16, 16);
		}
		item.image = groupIcon;
	});
	return item;
}

/**
 Generate new @c NSMenuItem based on the attributes of a @c FeedItem.
 */
+ (NSMenuItem*)feedItem:(FeedItem*)item {
	NSMenuItem *mi = [[NSMenuItem alloc] initWithTitle:item.title action:nil keyEquivalent:@""];
	[mi setReaderInfo:item.objectID unread:(item.unread ? 1 : 0)];
	//mi.toolTip = item.abstract;
	// TODO: Do regex during save, not during display. Its here for testing purposes ...
	if (item.abstract.length > 0) {
		NSRegularExpression *regex = [NSRegularExpression regularExpressionWithPattern:@"<[^>]*>" options:kNilOptions error:nil];
		mi.toolTip = [regex stringByReplacingMatchesInString:item.abstract options:kNilOptions range:NSMakeRange(0, item.abstract.length) withTemplate:@""];
	}
	mi.enabled = (item.link.length > 0);
	mi.state = (item.unread ? NSControlStateValueOn : NSControlStateValueOff);
	mi.tag = ScopeFeed;
	return mi;
}

/**
 Create a copy of an existing menu item and set it's option key modifier.
 */
- (NSMenuItem*)alternateWithTitle:(NSString*)title {
	NSMenuItem *alt = [self copy];
	alt.title = title;
	alt.keyEquivalentModifierMask = NSEventModifierFlagOption;
	if (!alt.hidden) // hidden will be ignored if alternate is YES
		alt.alternate = YES;
	return alt;
}

/**
 Set @c action and @c target attributes.
 
 @return Return @c self instance. Intended for method chains.
 */
- (NSMenuItem*)setAction:(SEL)action target:(id)target {
	self.action = action;
	self.target = target;
	return self;
}

@end
