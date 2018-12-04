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

#import "SettingsFeeds.h"
#import "BarMenu.h"
#import "ModalSheet.h"
#import "ModalFeedEdit.h"
#import "DrawImage.h"
#import "StoreCoordinator.h"
#import "Constants.h"

@interface SettingsFeeds () <ModalEditDelegate>
@property (weak) IBOutlet NSOutlineView *outlineView;
@property (weak) IBOutlet NSTreeController *dataStore;

@property (strong) NSViewController<ModalFeedConfigEdit> *modalController;
@property (strong) NSArray<NSTreeNode*> *currentlyDraggedNodes;
@property (strong) NSUndoManager *undoManager;
@end

@implementation SettingsFeeds

// Declare a string constant for the drag type - to be used when writing and retrieving pasteboard data...
static NSString *dragNodeType = @"baRSS-feed-drag";

- (void)viewDidLoad {
    [super viewDidLoad];
	[self.outlineView registerForDraggedTypes:[NSArray arrayWithObject:dragNodeType]];
	[self.dataStore setSortDescriptors:[NSArray arrayWithObject:[NSSortDescriptor sortDescriptorWithKey:@"sortIndex" ascending:YES]]];
	
	self.undoManager = [[NSUndoManager alloc] init];
	self.undoManager.groupsByEvent = NO;
	self.undoManager.levelsOfUndo = 30;
	
	self.dataStore.managedObjectContext = [StoreCoordinator createChildContext];
	self.dataStore.managedObjectContext.undoManager = self.undoManager;
}

- (void)saveChanges {
	[StoreCoordinator saveContext:self.dataStore.managedObjectContext andParent:YES];
}

- (IBAction)addFeed:(id)sender {
	[self showModalForFeedConfig:nil isGroupEdit:NO];
}

- (IBAction)addGroup:(id)sender {
	[self showModalForFeedConfig:nil isGroupEdit:YES];
}

- (IBAction)addSeparator:(id)sender {
	[self.undoManager beginUndoGrouping];
	FeedConfig *sp = [self insertSortedItemAtSelection];
	sp.name = @"---";
	sp.typ = SEPARATOR;
	[self.undoManager endUndoGrouping];
	[self saveChanges];
}

- (IBAction)remove:(id)sender {
	[self.undoManager beginUndoGrouping];
	NSArray<NSTreeNode*> *parentNodes = [self.dataStore.selectedNodes valueForKeyPath:@"parentNode"];
	[self.dataStore remove:sender];
	for (NSTreeNode *parent in parentNodes) {
		[self restoreOrderingAndIndexPathStr:parent];
	}
	[self.undoManager endUndoGrouping];
	[self saveChanges];
	[[NSNotificationCenter defaultCenter] postNotificationName:kNotificationTotalUnreadCountReset object:nil];
}

- (IBAction)doubleClickOutlineView:(NSOutlineView*)sender {
	if (sender.clickedRow == -1)
		return; // ignore clicks on column headers and where no row was selected
	
	FeedConfig *fc = [(NSTreeNode*)[sender itemAtRow:sender.clickedRow] representedObject];
	[self showModalForFeedConfig:fc isGroupEdit:YES]; // yes will be overwritten anyway
}


#pragma mark - Insert & Edit Feed Items


- (void)openModalForSelection {
	[self showModalForFeedConfig:self.dataStore.selectedObjects.firstObject isGroupEdit:YES]; // yes will be overwritten anyway
}

- (void)showModalForFeedConfig:(FeedConfig*)obj isGroupEdit:(BOOL)group {
	BOOL existingItem = [obj isKindOfClass:[FeedConfig class]];
	if (existingItem) {
		if (obj.typ == SEPARATOR) return;
		group = (obj.typ == GROUP);
	}
	self.modalController = (group ? [ModalGroupEdit new] : [ModalFeedEdit new]);
	self.modalController.representedObject = obj;
	self.modalController.delegate = self;
	
	[self.view.window beginSheet:[ModalSheet modalWithView:self.modalController.view] completionHandler:^(NSModalResponse returnCode) {
		if (returnCode == NSModalResponseOK) {
			if (!existingItem) { // create new item
				[self.undoManager beginUndoGrouping];
				FeedConfig *item = [self insertSortedItemAtSelection];
				item.typ = (group ? GROUP : FEED);
				self.modalController.representedObject = item;
			}
			[self.modalController updateRepresentedObject];
			if (!existingItem)
				[self.undoManager endUndoGrouping];
		}
		self.modalController = nil;
	}];
}

/// Called after an item was modified. May be called twice if download was still in progress.
- (void)modalDidUpdateFeedConfig:(FeedConfig*)config {
	[self saveChanges];
	[[NSNotificationCenter defaultCenter] postNotificationName:kNotificationTotalUnreadCountReset object:nil];
}


#pragma mark - Helper -

/// Insert @c FeedConfig item either after current selection or inside selected folder (if expanded)
- (FeedConfig*)insertSortedItemAtSelection {
	FeedConfig *newItem = [[FeedConfig alloc] initWithEntity:FeedConfig.entity insertIntoManagedObjectContext:self.dataStore.managedObjectContext];
	NSTreeNode *selection = [[self.dataStore selectedNodes] firstObject];
	NSIndexPath *pth = nil;
	
	if (!selection) { // append to root
		pth = [NSIndexPath indexPathWithIndex:[self.dataStore arrangedObjects].childNodes.count]; // or 0 to append at front
	} else if ([self.outlineView isItemExpanded:selection]) { // append to group (if open)
		pth = [selection.indexPath indexPathByAddingIndex:0]; // or 'selection.childNodes.count' to append at end
	} else { // append before / after selected item
		pth = selection.indexPath;
		// remove the two lines below to insert infront of selection (instead of after selection)
		NSUInteger lastIdx = [pth indexAtPosition:pth.length - 1];
		pth = [[pth indexPathByRemovingLastIndex] indexPathByAddingIndex:lastIdx + 1];
	}
	[self.dataStore insertObject:newItem atArrangedObjectIndexPath:pth];

	if (pth.length > 2) { // some subfolder; not root folder (has parent!)
		NSTreeNode *parentNode = [[self.dataStore arrangedObjects] descendantNodeAtIndexPath:pth].parentNode;
		newItem.parent = parentNode.representedObject;
		[self restoreOrderingAndIndexPathStr:parentNode];
	} else {
		[self restoreOrderingAndIndexPathStr:[self.dataStore arrangedObjects]]; // .parent = nil
	}
	return newItem;
}

/// Loop over all descendants and update @c sortIndex @c (FeedConfig) as well as all @c indexPath @c (Feed)
- (void)restoreOrderingAndIndexPathStr:(NSTreeNode*)parent {
	NSArray<NSTreeNode*> *children = parent.childNodes;
	for (NSUInteger i = 0; i < children.count; i++) {
		NSTreeNode *n = [children objectAtIndex:i];
		FeedConfig *fc = n.representedObject;
		// Re-calculate sort index for all affected parents
		if (fc.sortIndex != (int32_t)i)
			fc.sortIndex = (int32_t)i;
		// Re-calculate index path for all contained feed items
		[fc iterateSorted:NO overDescendantFeeds:^(Feed *feed, BOOL *cancel) {
			NSString *pthStr = [feed.config indexPathString];
			if (![feed.indexPath isEqualToString:pthStr])
				feed.indexPath = pthStr;
		}];
	}
}


#pragma mark - Dragging Support, Data Source Delegate


- (BOOL)outlineView:(NSOutlineView *)outlineView writeItems:(NSArray *)items toPasteboard:(NSPasteboard *)pboard {
	[self.undoManager beginUndoGrouping];
	[pboard declareTypes:[NSArray arrayWithObject:dragNodeType] owner:self];
	[pboard setString:@"dragging" forType:dragNodeType];
	self.currentlyDraggedNodes = items;
	return YES;
}

- (void)outlineView:(NSOutlineView *)outlineView draggingSession:(NSDraggingSession *)session endedAtPoint:(NSPoint)screenPoint operation:(NSDragOperation)operation {
	[self.undoManager endUndoGrouping];
	if (self.dataStore.managedObjectContext.hasChanges) {
		[self saveChanges];
	} else {
		[self.undoManager disableUndoRegistration];
		[self.undoManager undoNestedGroup];
		[self.undoManager enableUndoRegistration];
	}
	self.currentlyDraggedNodes = nil;
}

- (BOOL)outlineView:(NSOutlineView *)outlineView acceptDrop:(id <NSDraggingInfo>)info item:(id)item childIndex:(NSInteger)index {
	NSTreeNode *destParent = (item != nil ? item : [self.dataStore arrangedObjects]);
	NSUInteger idx = (NSUInteger)index;
	if (index == -1) // drag items on folder or root drop
		idx = destParent.childNodes.count;
	NSIndexPath *dest = [destParent indexPath];
	
	NSArray<NSTreeNode*> *previousParents = [self.currentlyDraggedNodes valueForKeyPath:@"parentNode"];
	[self.dataStore moveNodes:self.currentlyDraggedNodes toIndexPath:[dest indexPathByAddingIndex:idx]];
	
	for (NSTreeNode *node in previousParents) {
		[self restoreOrderingAndIndexPathStr:node];
	}
	[self restoreOrderingAndIndexPathStr:destParent];
	
	return YES;
}

- (NSDragOperation)outlineView:(NSOutlineView *)outlineView validateDrop:(id <NSDraggingInfo>)info proposedItem:(id)item proposedChildIndex:(NSInteger)index {
	FeedConfig *fc = [(NSTreeNode*)item representedObject];
	if (index == -1 && fc.typ != GROUP) { // if drag is on specific item and that item isnt a group
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


#pragma mark - Data Source Delegate


- (NSView *)outlineView:(NSOutlineView *)outlineView viewForTableColumn:(NSTableColumn *)tableColumn item:(id)item {
	FeedConfig *f = [(NSTreeNode*)item representedObject];
	BOOL isFeed = (f.typ == FEED);
	BOOL isSeperator = (f.typ == SEPARATOR);
	BOOL isRefreshColumn = [tableColumn.identifier isEqualToString:@"RefreshColumn"];
	
	NSString *cellIdent = (isRefreshColumn ? @"cellRefresh" : (isSeperator ? @"cellSeparator" : @"cellFeed"));
	// owner is nil to prohibit repeated awakeFromNib calls
	NSTableCellView *cellView = [self.outlineView makeViewWithIdentifier:cellIdent owner:nil];
	
	if (isRefreshColumn) {
		cellView.textField.stringValue = (!isFeed ? @"" : [f readableRefreshString]);
	} else if (isSeperator) {
		return cellView; // the refresh cell is already skipped with the above if condition
	} else {
		cellView.textField.objectValue = f.name;
		if (f.typ == GROUP) {
			cellView.imageView.image = [NSImage imageNamed:NSImageNameFolder];
		} else {
			// TODO: load icon
			static NSImage *defaultRSSIcon;
			if (!defaultRSSIcon)
				defaultRSSIcon = [RSSIcon iconWithSize:cellView.imageView.frame.size.height];
			
			cellView.imageView.image = defaultRSSIcon;
		}
	}
	if (isFeed) // also for refresh column
		cellView.textField.textColor = (f.refreshNum == 0 ? [NSColor disabledControlTextColor] : [NSColor controlTextColor]);
	return cellView;
}


#pragma mark - Keyboard Commands: undo, redo, copy, enter


- (BOOL)respondsToSelector:(SEL)aSelector {
	if (aSelector == @selector(undo:)) return [self.undoManager canUndo];
	if (aSelector == @selector(redo:)) return [self.undoManager canRedo];
	if (aSelector == @selector(copy:) || aSelector == @selector(enterPressed:)) {
		BOOL outlineHasFocus = [[self.view.window firstResponder] isKindOfClass:[NSOutlineView class]];
		BOOL hasSelection = (self.dataStore.selectedNodes.count > 0);
		if (!outlineHasFocus || !hasSelection)
			return NO;
		if (aSelector == @selector(copy:))
			return YES;
		// can edit only if selection is not a separator
		return (((FeedConfig*)self.dataStore.selectedNodes.firstObject.representedObject).typ != SEPARATOR);
	}
	return [super respondsToSelector:aSelector];
}

- (void)undo:(id)sender {
	[self.undoManager undo];
	[self saveChanges];
	[[NSNotificationCenter defaultCenter] postNotificationName:kNotificationTotalUnreadCountReset object:nil];
	[self.dataStore rearrangeObjects]; // update ordering
}

- (void)redo:(id)sender {
	[self.undoManager redo];
	[self saveChanges];
	[[NSNotificationCenter defaultCenter] postNotificationName:kNotificationTotalUnreadCountReset object:nil];
	[self.dataStore rearrangeObjects]; // update ordering
}

- (void)enterPressed:(id)sender {
	[self openModalForSelection];
}

- (void)copy:(id)sender {
	NSMutableString *str = [[NSMutableString alloc] init];
	NSUInteger count = self.dataStore.selectedNodes.count;
	NSMutableArray<NSTreeNode*> *groups = [NSMutableArray arrayWithCapacity:count];
	
	// filter out nodes that are already present in some selected parent node
	for (NSTreeNode *node in self.dataStore.selectedNodes) {
		BOOL skipItem = NO;
		for (NSTreeNode *stored in groups) {
			NSIndexPath *p = node.indexPath;
			while (p.length > stored.indexPath.length)
				p = [p indexPathByRemovingLastIndex];
			if ([p isEqualTo:stored.indexPath]) {
				skipItem = YES;
				break;
			}
		}
		if (!skipItem) {
			[self traverseChildren:node appendString:str prefix:@""];
			if (node.childNodes.count > 0)
				[groups addObject:node];
		}
	}
	[[NSPasteboard generalPasteboard] clearContents];
	[[NSPasteboard generalPasteboard] setString:str forType:NSPasteboardTypeString];
	NSLog(@"%@", str);
}

/**
 Go through all children recursively and prepend the string with spaces as nesting
 @param obj Root Node or parent Node
 @param str An initialized @c NSMutableString to append to
 @param prefix Should be @c @@"" for the first call
 */
- (void)traverseChildren:(NSTreeNode*)obj appendString:(NSMutableString*)str prefix:(NSString*)prefix {
	[str appendFormat:@"%@%@\n", prefix, [obj.representedObject readableDescription]];
	prefix = [prefix stringByAppendingString:@"  "];
	for (NSTreeNode *child in obj.childNodes) {
		[self traverseChildren:child appendString:str prefix:prefix];
	}
}

@end
