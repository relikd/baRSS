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
#import "Preferences.h"
#import "DBv1+CoreDataModel.h"
#import "ModalSheet.h"
#import "DrawImage.h"

@interface NewsController ()
@property (weak) IBOutlet Preferences *preferencesWindow;
@property (weak) IBOutlet ModalFeedEdit *viewModalEditFeed;
@property (weak) IBOutlet ModalGroupEdit *viewModalEditGroup;
@property (weak) IBOutlet NSOutlineView *outlineView;

@property (strong) NSArray<NSTreeNode*> *currentlyDraggedNodes;
@end

@implementation NewsController

// Declare a string constant for the drag type - to be used when writing and retrieving pasteboard data...
static NSString *dragNodeType = @"baRSS-feed-drag";

- (void)awakeFromNib {
    [super awakeFromNib];
	// Set the outline view to accept the custom drag type AbstractTreeNodeType...
	[self.outlineView registerForDraggedTypes:[NSArray arrayWithObject:dragNodeType]];
	[self setSortDescriptors:[NSArray arrayWithObject:[NSSortDescriptor sortDescriptorWithKey:@"sortIndex" ascending:YES]]];
}

- (NSView *)outlineView:(NSOutlineView *)outlineView viewForTableColumn:(NSTableColumn *)tableColumn item:(id)item {
	FeedConfig *f = [(NSTreeNode*)item representedObject];
	bool isFeed = (f.type == 1);
	bool isSeperator = (f.type == 2);
	bool isRefreshColumn = [tableColumn.identifier isEqualToString:@"RefreshColumn"];
	
	NSString *cellIdent = (isRefreshColumn ? @"cellRefresh" : (isSeperator ? @"cellSeparator" : @"cellFeed"));
	// owner is nil to prohibit repeated awakeFromNib calls
	NSTableCellView *cellView = [self.outlineView makeViewWithIdentifier:cellIdent owner:nil];
	
	if (isRefreshColumn) {
		cellView.textField.stringValue = (!isFeed ? @"" : [ModalFeedEdit stringForRefreshNum:f.refreshNum unit:f.refreshUnit]);
	} else if (isSeperator) {
		return cellView; // the refresh cell is already skipped with the above if condition
	} else {
		cellView.textField.objectValue = f.name;
		if (f.type == 0) {
			cellView.imageView.image = [NSImage imageNamed:NSImageNameFolder];
		} else {
			// TODO: load icon
			static NSImage *defaultRSSIcon;
			if (!defaultRSSIcon)
				defaultRSSIcon = [[[RSSIcon iconWithSize:cellView.imageView.frame.size] autoGradient] image];
			
			cellView.imageView.image = defaultRSSIcon;
		}
	}
	if (isFeed) // also for refresh column
		cellView.textField.textColor = (f.refreshNum == 0 ? [NSColor disabledControlTextColor] : [NSColor controlTextColor]);
	return cellView;
}

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

#pragma mark - Insert & Edit Feed Items

- (IBAction)addFeed:(id)sender {
	[self showModalForFeedConfig:nil isGroupEdit:NO];
}

- (IBAction)addGroup:(id)sender {
	[self showModalForFeedConfig:nil isGroupEdit:YES];
}

- (IBAction)addSeparator:(id)sender {
	[self.managedObjectContext.undoManager beginUndoGrouping];
	FeedConfig *sp = [self insertSortedItemAtSelection];
	sp.name = @"---";
	sp.type = 2;
	[self.managedObjectContext.undoManager endUndoGrouping];
}

- (void)remove:(id)sender {
	[self.managedObjectContext.undoManager beginUndoGrouping];
	for (NSIndexPath *path in self.selectionIndexPaths)
		[self incrementIndicesBy:-1 forSubsequentNodes:path];
	[super remove:sender];
	[self.managedObjectContext.undoManager endUndoGrouping];
}

- (IBAction)doubleClickOutlineView:(NSOutlineView*)sender {
	if (sender.clickedRow == -1)
		return; // ignore clicks on column headers and where no row was selected
	
	FeedConfig *fc = [(NSTreeNode*)[sender itemAtRow:sender.clickedRow] representedObject];
	[self showModalForFeedConfig:fc isGroupEdit:YES]; // yes will be overwritten anyway
}

- (void)openModalForSelection {
	[self showModalForFeedConfig:self.selectedObjects.firstObject isGroupEdit:YES]; // yes will be overwritten anyway
}

- (void)showModalForFeedConfig:(FeedConfig*)obj isGroupEdit:(bool)group {
	bool existingItem = [obj isKindOfClass:[FeedConfig class]];
	if (existingItem) {
		if (obj.type == 2) return; // Separator
		group = (obj.type == 0);
		if (group) [self.viewModalEditGroup setGroupName:obj.name];
		else       [self.viewModalEditFeed setURL:obj.url name:obj.name refreshNum:obj.refreshNum unit:obj.refreshUnit];
	} else {
		if (group) [self.viewModalEditGroup setDefaultValues];
		else       [self.viewModalEditFeed setDefaultValues];
	}
	NSView *content = (group ? self.viewModalEditGroup : self.viewModalEditFeed);
	[self.preferencesWindow presentModal:content completion:^(NSModalResponse returnCode) {
		if (returnCode == NSModalResponseOK) {
			[self.managedObjectContext.undoManager beginUndoGrouping];
			FeedConfig *item = obj;
			if (!existingItem) { // create new item
				item = [self insertSortedItemAtSelection];
				item.type = (group ? 0 : 1);
			}
			
			if (group) {
				item.name = self.viewModalEditGroup.title.stringValue;
			} else {
				item.name = self.viewModalEditFeed.title.stringValue;
				item.url = self.viewModalEditFeed.url.stringValue;
				item.refreshNum = self.viewModalEditFeed.refreshNum.intValue;
				item.refreshUnit = (int16_t)self.viewModalEditFeed.refreshUnit.indexOfSelectedItem;
			}
			[self.managedObjectContext.undoManager endUndoGrouping];
			[self rearrangeObjects];
		}
	}];
}

- (FeedConfig*)insertSortedItemAtSelection {
	NSIndexPath *selectedIndex = [self selectionIndexPath];
	NSIndexPath *insertIndex = selectedIndex;
	
	FeedConfig *selected = [[[self arrangedObjects] descendantNodeAtIndexPath:selectedIndex] representedObject];
	NSUInteger lastIndex = selected.children.count;
	bool groupSelected = (selected.type == 0);
	
	if (!groupSelected) {
		lastIndex = (NSUInteger)selected.sortIndex + 1; // insert after selection
		insertIndex = [insertIndex indexPathByRemovingLastIndex];
		[self incrementIndicesBy:+1 forSubsequentNodes:selectedIndex];
		--selected.sortIndex; // insert after selection
	}
	
	FeedConfig *newItem = [[FeedConfig alloc] initWithEntity:FeedConfig.entity insertIntoManagedObjectContext:self.managedObjectContext];
	[self insertObject:newItem atArrangedObjectIndexPath:[insertIndex indexPathByAddingIndex:lastIndex]];
	// First insert, then parent, else troubles
	newItem.sortIndex = (int32_t)lastIndex;
	newItem.parent = (groupSelected ? selected : selected.parent);
	return newItem;
}

#pragma mark - Import & Export of Data

- (NSString*)copyDescriptionOfSelectedItems {
	NSMutableString *str = [[NSMutableString alloc] init];
	for (FeedConfig *item in self.selectedObjects) {
		[self traverseChildren:item appendString:str indentation:0];
	}
	[[NSPasteboard generalPasteboard] clearContents];
	[[NSPasteboard generalPasteboard] setString:str forType:NSPasteboardTypeString];
	NSLog(@"%@", str);
	return str;
}

- (void)traverseChildren:(FeedConfig*)obj appendString:(NSMutableString*)str indentation:(int)indent {
	for (int i = indent; i > 0; i--) {
		[str appendString:@"  "];
	}
	switch (obj.type) {
		case 0: [str appendFormat:@"%@:\n", obj.name]; break; // Group
		case 2: [str appendString:@"-------------\n"]; break; // Separator
		default: [str appendFormat:@"%@ (%@) - %@\n", obj.name, obj.url, [ModalFeedEdit stringForRefreshNum:obj.refreshNum unit:obj.refreshUnit]];
	}
	for (FeedConfig *child in obj.children) {
		[self traverseChildren:child appendString:str indentation:indent + 1];
	}
}

- (void)incrementIndicesBy:(int)val forSubsequentNodes:(NSIndexPath*)path {
	NSIndexPath *parentPath = [path indexPathByRemovingLastIndex];
	NSTreeNode *root = [self arrangedObjects];
	if (parentPath.length > 0)
		root = [root descendantNodeAtIndexPath:parentPath];
	
	for (NSUInteger i = [path indexAtPosition:path.length - 1]; i < root.childNodes.count; i++) {
		((FeedConfig*)[root.childNodes[i] representedObject]).sortIndex += val;
	}
}

#pragma mark - Dragging Support, Data Source Delegate

- (BOOL)outlineView:(NSOutlineView *)outlineView writeItems:(NSArray *)items toPasteboard:(NSPasteboard *)pboard {
	[self.managedObjectContext.undoManager beginUndoGrouping];
	[pboard declareTypes:[NSArray arrayWithObject:dragNodeType] owner:self];
	[pboard setString:@"dragging" forType:dragNodeType];
	self.currentlyDraggedNodes = items;
	return YES;
}

- (void)outlineView:(NSOutlineView *)outlineView draggingSession:(NSDraggingSession *)session endedAtPoint:(NSPoint)screenPoint operation:(NSDragOperation)operation {
	self.currentlyDraggedNodes = nil;
	[self.managedObjectContext.undoManager endUndoGrouping];
	if ([self.managedObjectContext hasChanges]) {
		NSError *err;
		[self.managedObjectContext save:&err];
		if (err) NSLog(@"Error: %@", err);
	}
}

- (BOOL)outlineView:(NSOutlineView *)outlineView acceptDrop:(id <NSDraggingInfo>)info item:(id)item childIndex:(NSInteger)index {
	NSArray<NSTreeNode *> *dstChildren = [item childNodes];
	if (!item || !dstChildren)
		dstChildren = [self arrangedObjects].childNodes;
	
	bool isFolderDrag = (index == -1);
	NSUInteger insertIndex = (isFolderDrag ? dstChildren.count : (NSUInteger)index);
	// index where the items will be moved to, but not final since items above can vanish
	NSIndexPath *dest = [item indexPath];
	if (!dest) dest = [NSIndexPath indexPathWithIndex:insertIndex];
	else       dest = [dest indexPathByAddingIndex:insertIndex];
	
	// decrement index for every item that is dragged from the same location (above the destination)
	NSUInteger updateIndex = insertIndex;
	for (NSTreeNode *node in self.currentlyDraggedNodes) {
		NSIndexPath *nodesPath = [node indexPath];
		if ([[nodesPath indexPathByRemovingLastIndex] isEqualTo:[dest indexPathByRemovingLastIndex]] &&
			insertIndex > [nodesPath indexAtPosition:nodesPath.length - 1])
		{
			--updateIndex;
		}
	}
	
	// decrement sort indices at source
	for (NSTreeNode *node in self.currentlyDraggedNodes)
		[self incrementIndicesBy:-1 forSubsequentNodes:[node indexPath]];
	// increment sort indices at destination
	if (!isFolderDrag)
		[self incrementIndicesBy:(int)self.currentlyDraggedNodes.count forSubsequentNodes:dest];
	
	// move items
	[self moveNodes:self.currentlyDraggedNodes toIndexPath:dest];
	
	// set sort indices for dragged items
	for (NSUInteger i = 0; i < self.currentlyDraggedNodes.count; i++) {
		FeedConfig *fc = [self.currentlyDraggedNodes[i] representedObject];
		fc.sortIndex = (int32_t)(updateIndex + i);
	}
	return YES;
}

- (NSDragOperation)outlineView:(NSOutlineView *)outlineView validateDrop:(id <NSDraggingInfo>)info proposedItem:(id)item proposedChildIndex:(NSInteger)index {
	FeedConfig *fc = [(NSTreeNode*)item representedObject];
	if (index == -1 && fc.type != 0) { // if drag is on specific item and that item isnt a group
		return NSDragOperationNone;
	}
	
	NSTreeNode *parent = item;
	while (parent != nil) {
		for (NSTreeNode *node in self.currentlyDraggedNodes) {
			if (parent == node)
				return NSDragOperationNone; // cannot move items into a child of its own
		}
		parent = [parent parentNode];
	}
	return NSDragOperationGeneric;
}

@end
