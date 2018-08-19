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
#import "AppHook.h"
#import "BarMenu.h"
#import "ModalSheet.h"
#import "ModalFeedEdit.h"
#import "DrawImage.h"
#import "StoreCoordinator.h"

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
	
	NSManagedObjectContext *childContext = [[NSManagedObjectContext alloc] initWithConcurrencyType:NSMainQueueConcurrencyType];
	[childContext setParentContext:[(AppHook*)NSApp persistentContainer].viewContext];
//	childContext.automaticallyMergesChangesFromParent = YES;
	NSUndoManager *um = [[NSUndoManager alloc] init];
	um.groupsByEvent = NO;
	um.levelsOfUndo = 30;
	childContext.undoManager = um;
	
	self.dataStore.managedObjectContext = childContext;
	self.undoManager = self.dataStore.managedObjectContext.undoManager;
}

- (void)dealloc {
	[self saveAndRebuildMenu];
}

- (void)saveAndRebuildMenu {
	[StoreCoordinator saveContext:self.dataStore.managedObjectContext];
	[StoreCoordinator saveContext:self.dataStore.managedObjectContext.parentContext];
	[[(AppHook*)NSApp barMenu] rebuildMenu]; // updating individual items was way to complicated ...
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
	[self saveAndRebuildMenu];
}

- (IBAction)remove:(id)sender {
	[self.undoManager beginUndoGrouping];
	for (NSIndexPath *path in self.dataStore.selectionIndexPaths)
		[self incrementIndicesBy:-1 forSubsequentNodes:path];
	[self.dataStore remove:sender];
	[self.undoManager endUndoGrouping];
	[self saveAndRebuildMenu];
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

- (void)modalDidUpdateFeedConfig:(FeedConfig*)config {
	[self saveAndRebuildMenu];
}

- (FeedConfig*)insertSortedItemAtSelection {
	NSIndexPath *selectedIndex = [self.dataStore selectionIndexPath];
	NSIndexPath *insertIndex = selectedIndex;
	
	FeedConfig *selected = [[[self.dataStore arrangedObjects] descendantNodeAtIndexPath:selectedIndex] representedObject];
	NSUInteger lastIndex = selected.children.count;
	BOOL groupSelected = (selected.typ == GROUP);
	
	if (!groupSelected) {
		lastIndex = (NSUInteger)selected.sortIndex + 1; // insert after selection
		insertIndex = [insertIndex indexPathByRemovingLastIndex];
		[self incrementIndicesBy:+1 forSubsequentNodes:selectedIndex];
		--selected.sortIndex; // insert after selection
	}
	
	FeedConfig *newItem = [[FeedConfig alloc] initWithEntity:FeedConfig.entity insertIntoManagedObjectContext:self.dataStore.managedObjectContext];
	[self.dataStore insertObject:newItem atArrangedObjectIndexPath:[insertIndex indexPathByAddingIndex:lastIndex]];
	// First insert, then parent, else troubles
	newItem.sortIndex = (int32_t)lastIndex;
	newItem.parent = (groupSelected ? selected : selected.parent);
	return newItem;
}


#pragma mark - Import & Export of Data


- (void)incrementIndicesBy:(int)val forSubsequentNodes:(NSIndexPath*)path {
	NSIndexPath *parentPath = [path indexPathByRemovingLastIndex];
	NSTreeNode *root = [self.dataStore arrangedObjects];
	if (parentPath.length > 0)
		root = [root descendantNodeAtIndexPath:parentPath];
	
	for (NSUInteger i = [path indexAtPosition:path.length - 1]; i < root.childNodes.count; i++) {
		((FeedConfig*)[root.childNodes[i] representedObject]).sortIndex += val;
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
		[self saveAndRebuildMenu];
	} else {
		[self.undoManager disableUndoRegistration];
		[self.undoManager undoNestedGroup];
		[self.undoManager enableUndoRegistration];
	}
	self.currentlyDraggedNodes = nil;
}

- (BOOL)outlineView:(NSOutlineView *)outlineView acceptDrop:(id <NSDraggingInfo>)info item:(id)item childIndex:(NSInteger)index {
	NSArray<NSTreeNode *> *dstChildren = [item childNodes];
	if (!item || !dstChildren)
		dstChildren = [self.dataStore arrangedObjects].childNodes;
	
	BOOL isFolderDrag = (index == -1);
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
	[self.dataStore moveNodes:self.currentlyDraggedNodes toIndexPath:dest];
	
	// set sort indices for dragged items
	for (NSUInteger i = 0; i < self.currentlyDraggedNodes.count; i++) {
		FeedConfig *fc = [self.currentlyDraggedNodes[i] representedObject];
		fc.sortIndex = (int32_t)(updateIndex + i);
	}
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
				defaultRSSIcon = [[[RSSIcon iconWithSize:cellView.imageView.frame.size] autoGradient] image];
			
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
	[self.dataStore rearrangeObjects]; // update ordering
	[self saveAndRebuildMenu];
}

- (void)redo:(id)sender {
	[self.undoManager redo];
	[self.dataStore rearrangeObjects]; // update ordering
	[self saveAndRebuildMenu];
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
