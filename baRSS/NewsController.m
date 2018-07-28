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
#import "AppDelegate.h"
#import "DBv1+CoreDataModel.h"

@interface NewsController ()
@property (weak) IBOutlet NSMenuItem *pauseItem;
@property (weak) IBOutlet NSMenuItem *updateAllItem;
@property (weak) IBOutlet NSMenuItem *openUnreadItem;
@property (retain) NSManagedObjectContext *managedContext;
@end

@implementation NewsController

- (void)awakeFromNib {
    [super awakeFromNib];
	self.managedContext = [((AppDelegate*)[NSApp delegate]) persistentContainer].viewContext;
}

- (IBAction)pauseUpdates:(NSMenuItem *)sender {
	NSLog(@"pause");
	NSLog(@"%@", self.managedContext);
}
- (IBAction)updateAllFeeds:(NSMenuItem *)sender {
	NSLog(@"update all");
	NSDictionary * obj = [PyHandler getFeed:@"https://feeds.feedburner.com/simpledesktops" withEtag:nil andModified:nil];
	NSLog(@"obj = %@", obj);
	// TODO: check status code
	/*
	Feed *a = [[Feed alloc] initWithEntity:Feed.entity insertIntoManagedObjectContext:self.managedContext];
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
		FeedItem *b = [[FeedItem alloc] initWithEntity:FeedItem.entity insertIntoManagedObjectContext:self.managedContext];
		b.title = entry[@"title"];
		b.subtitle = entry[@"subtitle"];
		b.author = entry[@"author"];
		b.link = entry[@"link"];
		b.published = entry[@"published"];
		b.summary = entry[@"summary"];
		for (NSString *tag in entry[@"tags"]) {
			FeedTag *c = [[FeedTag alloc] initWithEntity:FeedTag.entity insertIntoManagedObjectContext:self.managedContext];
			c.name = tag;
			[b addTagsObject:c];
		}
		[a addItemsObject:b];
	}*/
}
- (IBAction)openAllUnread:(NSMenuItem *)sender {
	NSLog(@"all unread");
}
- (IBAction)addFeed:(NSButton *)sender {
	NSLog(@"add feed");
	NSLog(@"%@", self.managedContext);
}
- (IBAction)removeFeed:(NSButton *)sender {
	NSLog(@"del feed");
}
- (IBAction)addGroup:(NSButton *)sender {
	NSLog(@"add group");
}
- (IBAction)addSeparator:(NSButton *)sender {
	NSLog(@"add separator");
}


- (NSInteger)outlineView:(NSOutlineView *)outlineView numberOfChildrenOfItem:(id)item {
	return 1;
}

- (BOOL)outlineView:(NSOutlineView *)outlineView isItemExpandable:(id)item {
	return NO;
}

- (id)outlineView:(NSOutlineView *)outlineView objectValueForTableColumn:(NSTableColumn *)tableColumn byItem:(id)item {
	return @"du";
}

- (id)outlineView:(NSOutlineView *)outlineView child:(NSInteger)index ofItem:(id)item {
	return @"hi";
}

@end
