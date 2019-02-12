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
#import "Constants.h"
#import "StoreCoordinator.h"
#import "ModalFeedEdit.h"
#import "Feed+Ext.h"
#import "FeedGroup+Ext.h"
#import "OpmlExport.h"
#import "FeedDownload.h"

@interface SettingsFeeds ()
@property (weak) IBOutlet NSOutlineView *outlineView;
@property (weak) IBOutlet NSTreeController *dataStore;
@property (weak) IBOutlet NSProgressIndicator *spinner;
@property (weak) IBOutlet NSTextField *spinnerLabel;

@property (strong) NSArray<NSTreeNode*> *currentlyDraggedNodes;
@property (strong) NSUndoManager *undoManager;

@property (strong) NSTimer *timerStatusInfo;
@property (strong) NSDateComponentsFormatter *intervalFormatter;
@end

@implementation SettingsFeeds

// TODO: drag-n-drop feeds to opml file?
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
	
	// Register for notifications
	[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(feedUpdated:) name:kNotificationFeedUpdated object:nil];
	[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(feedUpdated:) name:kNotificationFeedIconUpdated object:nil];
	[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(updateInProgress:) name:kNotificationBackgroundUpdateInProgress object:nil];
}

- (void)dealloc {
	[[NSNotificationCenter defaultCenter] removeObserver:self];
}


#pragma mark - Activity Spinner & Status Info


/// Initialize status info timer
- (void)viewWillAppear {
	self.intervalFormatter = [[NSDateComponentsFormatter alloc] init];
	self.intervalFormatter.unitsStyle = NSDateComponentsFormatterUnitsStyleShort; // e.g., '30 min'
	self.intervalFormatter.maximumUnitCount = 1;
	self.timerStatusInfo = [NSTimer timerWithTimeInterval:NSTimeIntervalSince1970 target:self selector:@selector(keepTimerRunning) userInfo:nil repeats:YES];
	[[NSRunLoop mainRunLoop] addTimer:self.timerStatusInfo forMode:NSRunLoopCommonModes];
	// start spinner if update is in progress when preferences open
	[self activateSpinner:([FeedDownload isUpdating] ? -1 : 0)];
}

/// Timer cleanup
- (void)viewWillDisappear {
	// in viewWillDisappear otherwise dealloc will not be called
	[self.timerStatusInfo invalidate];
	self.timerStatusInfo = nil;
	self.intervalFormatter = nil;
}

/// Callback method to update status info. Will be called more often when interval is getting shorter.
- (void)keepTimerRunning {
	NSDate *date = [FeedDownload dateScheduled];
	if (date) {
		double nextFire = fabs(date.timeIntervalSinceNow);
		if (nextFire > 1e9) { // distance future, over 31 years
			self.spinnerLabel.stringValue = @"";
			return;
		}
		if (nextFire > 60) { // update 1/min
			nextFire = fmod(nextFire, 60); // next update will align with minute
		} else {
			nextFire = 1; // update 1/sec
		}
		NSString *str = [self.intervalFormatter stringFromTimeInterval: date.timeIntervalSinceNow];
		self.spinnerLabel.stringValue = [NSString stringWithFormat:NSLocalizedString(@"Next update in %@", nil), str];
		[self.timerStatusInfo setFireDate:[NSDate dateWithTimeIntervalSinceNow: nextFire]];
	}
}

/// Start ( @c c @c > @c 0 ) or stop ( @c c @c = @c 0 ) activity spinner. Also, sets status info.
- (void)activateSpinner:(NSInteger)c {
	if (c == 0) {
		[self.spinner stopAnimation:nil];
		self.spinnerLabel.stringValue = @"";
		[self.timerStatusInfo fire];
	} else {
		[self.timerStatusInfo setFireDate:[NSDate distantFuture]];
		[self.spinner startAnimation:nil];
		if (c == 1) { // exactly one feed
			self.spinnerLabel.stringValue = NSLocalizedString(@"Updating 1 feed …", nil);
		} else if (c < 0) { // unknown number of feeds
			self.spinnerLabel.stringValue = NSLocalizedString(@"Updating feeds …", nil);
		} else {
			self.spinnerLabel.stringValue = [NSString stringWithFormat:NSLocalizedString(@"Updating %lu feeds …", nil), c];
		}
	}
}


#pragma mark - Notification callback methods


/// Callback method fired when feed (or icon) has been updated in the background.
- (void)feedUpdated:(NSNotification*)notify {
	NSManagedObjectID *oid = notify.object;
	NSManagedObjectContext *moc = self.dataStore.managedObjectContext;
	Feed *feed = [moc objectRegisteredForID:oid];
	if (feed) {
		if (self.undoManager.groupingLevel == 0) // don't mess around if user is editing something
			[moc refreshObject:feed mergeChanges:YES];
		[self.dataStore rearrangeObjects];
	}
}

/// Callback method fired when background feed update begins and ends.
- (void)updateInProgress:(NSNotification*)notify {
	[self activateSpinner:[notify.object integerValue]];
}


#pragma mark - Persist state


/**
 Refresh current context from parent context and start new undo grouping.
 @note Should be balanced with @c endCoreDataChangeUndoChanges:
 */
- (void)beginCoreDataChange {
	// Does seem to create problems with undo stack if refreshing from parent context
	//[self.dataStore.managedObjectContext refreshAllObjects];
	[self.undoManager beginUndoGrouping];
}

/**
 End undo grouping and save changes to persistent store. Or undo group if no changes occured.
 @note Should be balanced with @c beginCoreDataChange

 @param flag If @c YES force @c NSUndoManager to undo the changes immediatelly.
 @return Returns @c YES if context was saved.
 */
- (BOOL)endCoreDataChangeShouldUndo:(BOOL)flag {
	[self.undoManager endUndoGrouping];
	if (!flag && self.dataStore.managedObjectContext.hasChanges) {
		[StoreCoordinator saveContext:self.dataStore.managedObjectContext andParent:YES];
		[FeedDownload scheduleUpdateForUpcomingFeeds];
		[self.timerStatusInfo fire];
		return YES;
	}
	[self.undoManager disableUndoRegistration];
	[self.undoManager undoNestedGroup];
	[self.undoManager enableUndoRegistration];
	return NO;
}

/**
 After the user did undo or redo we can't ensure integrity without doing some additional work.
 */
- (void)saveWithUnpredictableChange {
	// dont use unless you merge changes from main
//	NSManagedObjectContext *moc = self.dataStore.managedObjectContext;
//	NSPredicate *pred = [NSPredicate predicateWithFormat:@"class == %@", [FeedArticle class]];
//	NSInteger del = [[[moc.deletedObjects filteredSetUsingPredicate:pred] valueForKeyPath:@"@sum.unread"] integerValue];
//	NSInteger ins = [[[moc.insertedObjects filteredSetUsingPredicate:pred] valueForKeyPath:@"@sum.unread"] integerValue];
//	NSLog(@"%ld, %ld", del, ins);
	[StoreCoordinator saveContext:self.dataStore.managedObjectContext andParent:YES];
	[[NSNotificationCenter defaultCenter] postNotificationName:kNotificationTotalUnreadCountReset object:nil];
	[self.dataStore rearrangeObjects]; // update ordering
}


#pragma mark - UI Button Interaction


/// Add feed button.
- (IBAction)addFeed:(id)sender {
	[self showModalForFeedGroup:nil isGroupEdit:NO];
}

/// Add group button.
- (IBAction)addGroup:(id)sender {
	[self showModalForFeedGroup:nil isGroupEdit:YES];
}

/// Add separator button.
- (IBAction)addSeparator:(id)sender {
	[self beginCoreDataChange];
	[self insertFeedGroupAtSelection:SEPARATOR].name = @"---";
	[self endCoreDataChangeShouldUndo:NO];
}

/// Remove feed button. User has selected one or more item in outline view.
- (IBAction)remove:(id)sender {
	[self beginCoreDataChange];
	NSArray<NSTreeNode*> *parentNodes = [self.dataStore.selectedNodes valueForKeyPath:@"parentNode"];
	[self.dataStore remove:sender];
	for (NSTreeNode *parent in parentNodes) {
		[self restoreOrderingAndIndexPathStr:parent];
	}
	[self endCoreDataChangeShouldUndo:NO];
	[[NSNotificationCenter defaultCenter] postNotificationName:kNotificationTotalUnreadCountReset object:nil];
}

/// Open user selected item for editing.
- (IBAction)doubleClickOutlineView:(NSOutlineView*)sender {
	if (sender.clickedRow == -1)
		return; // ignore clicks on column headers and where no row was selected
	FeedGroup *fg = [(NSTreeNode*)[sender itemAtRow:sender.clickedRow] representedObject];
	[self showModalForFeedGroup:fg isGroupEdit:YES]; // yes will be overwritten anyway
}

/// Share menu button. Currently only import & export feeds as OPML.
- (IBAction)shareMenu:(NSButton*)sender {
	if (!sender.menu) {
		sender.menu = [[NSMenu alloc] initWithTitle:NSLocalizedString(@"Import / Export menu", nil)];
		sender.menu.autoenablesItems = NO;
		[sender.menu addItemWithTitle:NSLocalizedString(@"Import Feeds …", nil) action:nil keyEquivalent:@""].tag = 101;
		[sender.menu addItemWithTitle:NSLocalizedString(@"Export Feeds …", nil) action:nil keyEquivalent:@""].tag = 102;
		// TODO: Add menus for online sync? email export? etc.
	}
	if ([sender.menu popUpMenuPositioningItem:nil atLocation:NSMakePoint(0,sender.frame.size.height) inView:sender]) {
		NSInteger tag = sender.menu.highlightedItem.tag;
		if (tag == 101) {
			[OpmlExport showImportDialog:self.view.window withContext:self.dataStore.managedObjectContext];
		} else if (tag == 102) {
			[OpmlExport showExportDialog:self.view.window withContext:self.dataStore.managedObjectContext];
		}
	}
}


#pragma mark - Insert & Edit Feed Items / Modal Dialog


/**
 Open a new modal window to edit the selected @c FeedGroup.
 @note isGroupEdit @c flag will be overwritten if @c FeedGroup parameter is not @c nil.
 
 @param fg @c FeedGroup to be edited. If @c nil a new object will be created at the current selection.
 @param flag If @c YES open group edit modal dialog. If @c NO open feed edit modal dialog.
 */
- (void)showModalForFeedGroup:(FeedGroup*)fg isGroupEdit:(BOOL)flag {
	if (fg.type == SEPARATOR) return;
	[self beginCoreDataChange];
	if (!fg || ![fg isKindOfClass:[FeedGroup class]]) {
		fg = [self insertFeedGroupAtSelection:(flag ? GROUP : FEED)];
	}
	
	ModalEditDialog *editDialog = (fg.type == GROUP ? [ModalGroupEdit modalWith:fg] : [ModalFeedEdit modalWith:fg]);
	
	[self.view.window beginSheet:[editDialog getModalSheet] completionHandler:^(NSModalResponse returnCode) {
		if (returnCode == NSModalResponseOK) {
			[editDialog applyChangesToCoreDataObject];
		}
		if ([self endCoreDataChangeShouldUndo:(returnCode != NSModalResponseOK)]) {
			[self.dataStore rearrangeObjects];
		}
	}];
}

/// Insert @c FeedGroup item either after current selection or inside selected folder (if expanded)
- (FeedGroup*)insertFeedGroupAtSelection:(FeedGroupType)type {
	FeedGroup *fg = [FeedGroup newGroup:type inContext:self.dataStore.managedObjectContext];
	NSIndexPath *pth = [self indexPathForInsertAtNode:[[self.dataStore selectedNodes] firstObject]];
	[self.dataStore insertObject:fg atArrangedObjectIndexPath:pth];
	
	if (pth.length > 1) { // some subfolder and not root folder (has parent!)
		NSTreeNode *parentNode = [[self.dataStore arrangedObjects] descendantNodeAtIndexPath:pth].parentNode;
		fg.parent = parentNode.representedObject;
		[self restoreOrderingAndIndexPathStr:parentNode];
	} else {
		[self restoreOrderingAndIndexPathStr:[self.dataStore arrangedObjects]]; // .parent = nil
	}
	return fg;
}

/**
 Index path will be selected as follow:
 - @b root: append at end
 - @b folder (expanded): append at front
 - @b else: append after item.

 @return indexPath where item will be inserted.
 */
- (NSIndexPath*)indexPathForInsertAtNode:(NSTreeNode*)node {
	if (!node) { // append to root
		return [NSIndexPath indexPathWithIndex:[self.dataStore arrangedObjects].childNodes.count]; // or 0 to append at front
	} else if ([self.outlineView isItemExpanded:node]) { // append to group (if open)
		return [node.indexPath indexPathByAddingIndex:0]; // or 'selection.childNodes.count' to append at end
	} else { // append before / after selected item
		NSIndexPath *pth = node.indexPath;
		// remove the two lines below to insert infront of selection (instead of after selection)
		NSUInteger lastIdx = [pth indexAtPosition:pth.length - 1];
		return [[pth indexPathByRemovingLastIndex] indexPathByAddingIndex:lastIdx + 1];
	}
}

/// Loop over all descendants and update @c sortIndex @c (FeedGroup) as well as all @c indexPath @c (Feed)
- (void)restoreOrderingAndIndexPathStr:(NSTreeNode*)parent {
	NSArray<NSTreeNode*> *children = parent.childNodes;
	for (NSUInteger i = 0; i < children.count; i++) {
		FeedGroup *fg = [children objectAtIndex:i].representedObject;
		if (fg.sortIndex != (int32_t)i)
			fg.sortIndex = (int32_t)i;
		[fg iterateSorted:NO overDescendantFeeds:^(Feed *feed, BOOL *cancel) {
			[feed calculateAndSetIndexPathString];
		}];
	}
}


#pragma mark - Dragging Support, Data Source Delegate


/// Begin drag-n-drop operation by copying selected nodes to memory
- (BOOL)outlineView:(NSOutlineView *)outlineView writeItems:(NSArray *)items toPasteboard:(NSPasteboard *)pboard {
	[self beginCoreDataChange];
	[pboard declareTypes:[NSArray arrayWithObject:dragNodeType] owner:self];
	[pboard setString:@"dragging" forType:dragNodeType];
	self.currentlyDraggedNodes = items;
	return YES;
}

/// Finish drag-n-drop operation by saving changes to persistent store
- (void)outlineView:(NSOutlineView *)outlineView draggingSession:(NSDraggingSession *)session endedAtPoint:(NSPoint)screenPoint operation:(NSDragOperation)operation {
	[self endCoreDataChangeShouldUndo:NO];
	self.currentlyDraggedNodes = nil;
}

/// Perform drag-n-drop operation, move nodes to new destination and update all indices
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

/// Validate method whether items can be dropped at destination
- (NSDragOperation)outlineView:(NSOutlineView *)outlineView validateDrop:(id <NSDraggingInfo>)info proposedItem:(id)item proposedChildIndex:(NSInteger)index {
	NSTreeNode *parent = item;
	if (index == -1 && [parent isLeaf]) { // if drag is on specific item and that item isnt a group
		return NSDragOperationNone;
	}
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


/// Populate @c NSOutlineView data cells with core data object values.
- (NSView *)outlineView:(NSOutlineView *)outlineView viewForTableColumn:(NSTableColumn *)tableColumn item:(id)item {
	FeedGroup *fg = [(NSTreeNode*)item representedObject];
	BOOL isSeperator = (fg.type == SEPARATOR);
	BOOL isRefreshColumn = [tableColumn.identifier isEqualToString:@"RefreshColumn"];
	
	NSString *cellIdent = (isRefreshColumn ? @"cellRefresh" : (isSeperator ? @"cellSeparator" : @"cellFeed"));
	// owner is nil to prohibit repeated awakeFromNib calls
	NSTableCellView *cellView = [self.outlineView makeViewWithIdentifier:cellIdent owner:nil];
	
	if (isRefreshColumn) {
		NSString *str = [fg refreshString];
		cellView.textField.stringValue = str;
		cellView.textField.textColor = (str.length > 1 ? [NSColor controlTextColor] : [NSColor disabledControlTextColor]);
	} else if (isSeperator) {
		return cellView; // refresh cell already skipped with the above if condition
	} else {
		cellView.textField.objectValue = fg.name;
		cellView.imageView.image = (fg.type == GROUP ? [NSImage imageNamed:NSImageNameFolder] : [fg.feed iconImage16]);
	}
	return cellView;
}


#pragma mark - Keyboard Commands: undo, redo, copy, enter


/// Returning @c NO will result in a Action-Not-Available-Buzzer sound
- (BOOL)respondsToSelector:(SEL)aSelector {
	if (aSelector == @selector(undo:))
		return [self.undoManager canUndo] && self.undoManager.groupingLevel == 0 && ![FeedDownload isUpdating];
	if (aSelector == @selector(redo:))
		return [self.undoManager canRedo] && self.undoManager.groupingLevel == 0 && ![FeedDownload isUpdating];
	if (aSelector == @selector(copy:) || aSelector == @selector(enterPressed:)) {
		BOOL outlineHasFocus = [[self.view.window firstResponder] isKindOfClass:[NSOutlineView class]];
		BOOL hasSelection = (self.dataStore.selectedNodes.count > 0);
		if (!outlineHasFocus || !hasSelection)
			return NO;
		if (aSelector == @selector(copy:))
			return YES;
		// can edit only if selection is not a separator
		return (((FeedGroup*)self.dataStore.selectedNodes.firstObject.representedObject).type != SEPARATOR);
	}
	return [super respondsToSelector:aSelector];
}

/// Perform undo operation and redraw UI & menu bar unread count
- (void)undo:(id)sender {
	[self.undoManager undo];
	[self saveWithUnpredictableChange];
}

/// Perform redo operation and redraw UI & menu bar unread count
- (void)redo:(id)sender {
	[self.undoManager redo];
	[self saveWithUnpredictableChange];
}

/// User pressed enter; open edit dialog for selected item.
- (void)enterPressed:(id)sender {
	[self showModalForFeedGroup:self.dataStore.selectedObjects.firstObject isGroupEdit:YES]; // yes will be overwritten anyway
}

/// Copy human readable description of selected nodes to clipboard.
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
