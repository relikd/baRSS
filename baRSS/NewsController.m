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

#import "NewsController.h"
#import "PyHandler.h"
#import "DBv1+CoreDataModel.h"

@interface NewsController ()
@end

@implementation NewsController

- (IBAction)pauseUpdates:(NSMenuItem *)sender {
	NSLog(@"pause");
}

- (IBAction)updateAllFeeds:(NSMenuItem *)sender {
	NSLog(@"update all");
	NSDictionary * obj = [PyHandler getFeed:@"https://feeds.feedburner.com/simpledesktops" withEtag:nil andModified:nil];
	NSLog(@"obj = %@", obj);
	// TODO: check status code
	/*
	Feed *a = [[Feed alloc] initWithEntity:Feed.entity insertIntoManagedObjectContext:self.managedObjectContext];
	a.title = obj[@"feed"][@"title"];
	a.subtitle = obj[@"feed"][@"subtitle"];
	a.author = obj[@"feed"][@"author"];
	a.link = obj[@"feed"][@"link"];
	a.published = obj[@"feed"][@"published"];
	a.icon = obj[@"feed"][@"icon"];
	a.etag = obj[@"header"][@"etag"];
	a.date = obj[@"header"][@"date"];
	a.modified = obj[@"header"][@"modified"];
	for (NSDictionary *entry in obj[@"entries"]) {
		FeedItem *b = [[FeedItem alloc] initWithEntity:FeedItem.entity insertIntoManagedObjectContext:self.managedObjectContext];
		b.title = entry[@"title"];
		b.subtitle = entry[@"subtitle"];
		b.author = entry[@"author"];
		b.link = entry[@"link"];
		b.published = entry[@"published"];
		b.summary = entry[@"summary"];
		for (NSString *tag in entry[@"tags"]) {
			FeedTag *c = [[FeedTag alloc] initWithEntity:FeedTag.entity insertIntoManagedObjectContext:self.managedObjectContext];
			c.name = tag;
			[b addTagsObject:c];
		}
		[a addItemsObject:b];
	}*/
}

- (IBAction)openAllUnread:(NSMenuItem *)sender {
	NSLog(@"all unread");
}

@end
