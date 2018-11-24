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
#import "FeedConfig+Ext.h"
#import "FeedItem+CoreDataClass.h"
#import <RSXML/RSXML.h>

@implementation Feed (Ext)

+ (FeedItem*)createFeedItemFrom:(RSParsedArticle*)entry inContext:(NSManagedObjectContext*)context {
	FeedItem *b = [[FeedItem alloc] initWithEntity:FeedItem.entity insertIntoManagedObjectContext:context];
	b.guid = entry.guid;
	b.title = entry.title;
	b.abstract = entry.abstract;
	b.body = entry.body;
	b.author = entry.author;
	b.link = entry.link;
	b.published = entry.datePublished;
	return b;
}

+ (Feed*)feedFromRSS:(RSParsedFeed*)obj inContext:(NSManagedObjectContext*)context alreadyRead:(NSArray<NSString*>*)urls unread:(int*)unreadCount {
	Feed *a = [[Feed alloc] initWithEntity:Feed.entity insertIntoManagedObjectContext:context];
	a.title = obj.title;
	a.subtitle = obj.subtitle;
	a.link = obj.link;
	for (RSParsedArticle *article in obj.articles) {
		FeedItem *b = [self createFeedItemFrom:article inContext:context];
		if ([urls containsObject:b.link]) {
			b.unread = NO;
		} else {
			*unreadCount += 1;
		}
		[a addItemsObject:b];
	}
	return a;
}

- (NSArray<NSString*>*)alreadyReadURLs {
	if (!self.items || self.items.count == 0) return nil;
	NSMutableArray<NSString*> *mArr = [NSMutableArray arrayWithCapacity:self.items.count];
	for (FeedItem *f in self.items) {
		if (!f.unread) {
			[mArr addObject:f.link];
		}
	}
	return mArr;
}

- (void)markAllItemsRead {
	[self markAllArticlesRead:YES];
}

- (void)markAllItemsUnread {
	[self markAllArticlesRead:NO];
}

- (void)markAllArticlesRead:(BOOL)readFlag {
	int count = 0;
	for (FeedItem *i in self.items) {
		if (i.unread == readFlag) {
			i.unread = !readFlag;
			++count;
		}
	}
	[self.config markUnread:(readFlag ? -count : +count) ancestorsOnly:NO];
}

@end
