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

#import "FeedConfig+Ext.h"
#import "Feed+CoreDataClass.h"

@implementation FeedConfig (Ext)
/// Enum tpye getter see @c FeedConfigType
- (FeedConfigType)typ { return (FeedConfigType)self.type; }
/// Enum type setter see @c FeedConfigType
- (void)setTyp:(FeedConfigType)typ { self.type = typ; }

/**
 Sorted children array based on sort order provided in feed settings.

 @return Sorted array of @c FeedConfig items.
 */
- (NSArray<FeedConfig *> *)sortedChildren {
	if (self.children.count == 0)
		return nil;
	return [self.children sortedArrayUsingDescriptors:@[[NSSortDescriptor sortDescriptorWithKey:@"sortIndex" ascending:YES]]];
}

/**
 Iterate over all descendant @c FeedItems in sub groups
 
 @param block Will yield the current parent config and feed item. Return @c NO to cancel iteration.
 @return Returns @c NO if the iteration was canceled early. Otherwise @c YES.
 */
- (BOOL)descendantFeedItems:(FeedConfigRecursiveItemsBlock)block {
	if (self.children.count > 0) {
		for (FeedConfig *config in self.children) {
			if ([config descendantFeedItems:block] == NO)
				return NO;
		}
	} else if (self.feed.items.count > 0) {
		for (FeedItem* item in self.feed.items) {
			if (block(self, item) == NO)
				return NO;
		}
	}
	return YES;
}

/// @return Formatted string for update interval ( e.g., @c 30m or @c 12h )
- (NSString*)readableRefreshString {
	return [NSString stringWithFormat:@"%d%c", self.refreshNum, [@"smhdw" characterAtIndex:self.refreshUnit % 5]];
}

/// @return Simplified description of the feed object.
- (NSString*)readableDescription {
	switch (self.typ) {
		case SEPARATOR: return @"-------------";
		case GROUP: return [NSString stringWithFormat:@"%@", self.name];
		case FEED:
			return [NSString stringWithFormat:@"%@ (%@) - %@", self.name, self.url, [self readableRefreshString]];
	}
}

@end
