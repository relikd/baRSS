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

@interface NewsController ()
@property (weak) IBOutlet NSMenuItem *pauseItem;
@property (weak) IBOutlet NSMenuItem *updateAllItem;
@property (weak) IBOutlet NSMenuItem *openUnreadItem;
@property (weak) IBOutlet NSManagedObjectContext *managedObjectContext;
@end

@implementation NewsController

- (void)viewDidLoad {
    [super viewDidLoad];
    // Do view setup here.
}
- (IBAction)pauseUpdates:(NSMenuItem *)sender {
	NSLog(@"pause");
	NSLog(@"%@", self.managedObjectContext);
}
- (IBAction)updateAllFeeds:(NSMenuItem *)sender {
	NSLog(@"update all");
}
- (IBAction)openAllUnread:(NSMenuItem *)sender {
	NSLog(@"all unread");
}
- (IBAction)addFeed:(NSButton *)sender {
	NSLog(@"add feed");
	NSLog(@"%@", self.managedObjectContext);
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
