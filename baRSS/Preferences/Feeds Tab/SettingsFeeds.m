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
#import "SettingsFeedsView.h"
#import "NSDate+Ext.h"

@interface SettingsFeeds ()
@property (strong) SettingsFeedsView *view; // override super

@property (strong) NSArray<NSTreeNode*> *currentlyDraggedNodes;
@property (strong) NSUndoManager *undoManager;

@property (strong) NSTimer *timerStatusInfo;
@end

@implementation SettingsFeeds
@dynamic view;

// TODO: drag-n-drop feeds to opml file?
// Declare a string constant for the drag type - to be used when writing and retrieving pasteboard data...
static NSString *dragNodeType = @"baRSS-feed-drag";

- (void)loadView {
	[self initCoreDataStore];
	self.view = [[SettingsFeedsView alloc] initWithController:self];
	[self.view.outline registerForDraggedTypes:[NSArray arrayWithObject:dragNodeType]];
}

- (void)viewDidLoad {
    [super viewDidLoad];
	// Register for notifications
	[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(feedUpdated:) name:kNotificationFeedUpdated object:nil];
	[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(feedUpdated:) name:kNotificationFeedIconUpdated object:nil];
	[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(updateInProgress:) name:kNotificationBackgroundUpdateInProgress object:nil];
}

- (void)dealloc {
	[[NSNotificationCenter defaultCenter] removeObserver:self];
}

- (void)initCoreDataStore {
	self.undoManager = [[NSUndoManager alloc] init];
	self.undoManager.groupsByEvent = NO;
	self.undoManager.levelsOfUndo = 30;
	
	self.dataStore = [[NSTreeController alloc] init];
	self.dataStore.managedObjectContext = [StoreCoordinator createChildContext];
	self.dataStore.managedObjectContext.undoManager = self.undoManager;
	self.dataStore.childrenKeyPath = @"children";
	self.dataStore.leafKeyPath = @"type";
	self.dataStore.entityName = @"FeedGroup";
	self.dataStore.objectClass = [FeedGroup class];
	self.dataStore.fetchPredicate = [NSPredicate predicateWithFormat:@"parent == nil"];
	self.dataStore.sortDescriptors = [NSArray arrayWithObject:[NSSortDescriptor sortDescriptorWithKey:@"sortIndex" ascending:YES]];
	
	NSError *error;
	BOOL ok = [self.dataStore fetchWithRequest:nil merge:NO error:&error];
	if (!ok || error) {
		[[NSApplication sharedApplication] presentError:error];
	}
}


#pragma mark - Activity Spinner & Status Info


/// Initialize status info timer
- (void)viewWillAppear {
	[self.dataStore rearrangeObjects]; // needed to scroll outline view to top (if prefs open on another tab)
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
}

/// Callback method to update status info. Will be called more often when interval is getting shorter.
- (void)keepTimerRunning {
	NSDate *date = [FeedDownload dateScheduled];
	if (date) {
		double nextFire = fabs(date.timeIntervalSinceNow);
		if (nextFire > 1e9) { // distance future, over 31 years
			self.view.status.stringValue = @"";
			return;
		}
		self.view.status.stringValue = [NSString stringWithFormat:NSLocalizedString(@"Next update in %@", nil),
										[NSDate stringForRemainingTime:date]];
		// Next update is aligned with minute (fmod) else update 1/sec
		NSDate *nextUpdate = [NSDate dateWithTimeIntervalSinceNow: (nextFire > 60 ? fmod(nextFire, 60) : 1)];
		[self.timerStatusInfo setFireDate:nextUpdate];
	}
}

/// Start ( @c c @c > @c 0 ) or stop ( @c c @c = @c 0 ) activity spinner. Also, sets status info.
- (void)activateSpinner:(NSInteger)c {
	if (c == 0) {
		[self.view.spinner stopAnimation:nil];
		self.view.status.stringValue = @"";
		[self.timerStatusInfo fire];
	} else {
		[self.timerStatusInfo setFireDate:[NSDate distantFuture]];
		[self.view.spinner startAnimation:nil];
		if (c == 1) { // exactly one feed
			self.view.status.stringValue = NSLocalizedString(@"Updating 1 feed …", nil);
		} else if (c < 0) { // unknown number of feeds
			self.view.status.stringValue = NSLocalizedString(@"Updating feeds …", nil);
		} else {
			self.view.status.stringValue = [NSString stringWithFormat:NSLocalizedString(@"Updating %lu feeds …", nil), c];
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


/// Open clicked or selected item for editing.
- (void)editSelectedItem {
	FeedGroup *chosen = [self clickedItem];
	if (!chosen) chosen = self.dataStore.selectedObjects.firstObject;
	[self showModalForFeedGroup:chosen isGroupEdit:YES]; // yes will be overwritten anyway
}

/// Open clicked item for editing.
- (void)doubleClickOutlineView:(NSOutlineView*)sender {
	FeedGroup *fg = [self clickedItem];
	if (!fg) return;
	[self showModalForFeedGroup:fg isGroupEdit:YES]; // yes will be overwritten anyway
}

/// Add feed button.
- (void)addFeed {
	[self showModalForFeedGroup:nil isGroupEdit:NO];
}

/// Add group button.
- (void)addGroup {
	[self showModalForFeedGroup:nil isGroupEdit:YES];
}

/// Add separator button.
- (void)addSeparator {
	[self beginCoreDataChange];
	[self insertFeedGroupAtSelection:SEPARATOR].name = @"---";
	[self endCoreDataChangeShouldUndo:NO];
}

/// Remove feed button. User has selected one or more item in outline view.
- (void)remove:(id)sender {
	[self beginCoreDataChange];
	NSArray<NSTreeNode*> *parentNodes = [self.dataStore.selectedNodes valueForKeyPath:@"parentNode"];
	[self.dataStore remove:sender];
	for (NSTreeNode *parent in [self filterOutRedundant:parentNodes]) {
		[self restoreOrderingAndIndexPathStr:parent];
	}
	[self endCoreDataChangeShouldUndo:NO];
	[[NSNotificationCenter defaultCenter] postNotificationName:kNotificationTotalUnreadCountReset object:nil];
}

- (void)openImportDialog {
	[OpmlExport showImportDialog:self.view.window withContext:self.dataStore.managedObjectContext];
}

- (void)openExportDialog {
	[OpmlExport showExportDialog:self.view.window withContext:self.dataStore.managedObjectContext];
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

/// Insert @c FeedGroup item at the end of the current folder (or inside if expanded)
- (FeedGroup*)insertFeedGroupAtSelection:(FeedGroupType)type {
	FeedGroup *selObj = self.dataStore.selectedObjects.firstObject;
	NSTreeNode *selNode = self.dataStore.selectedNodes.firstObject;
	// If group selected and expanded, insert into group. Else: append at end of current folder
	if (![self.view.outline isItemExpanded:selNode]) {
		selObj = selObj.parent;
		selNode = selNode.parentNode;
	}
	// If no selection, append to root folder
	if (!selNode) selNode = [self.dataStore arrangedObjects];
	// Insert new node
	NSUInteger index = selNode.childNodes.count;
	FeedGroup *fg = [FeedGroup newGroup:type inContext:self.dataStore.managedObjectContext];
	[self.dataStore insertObject:fg atArrangedObjectIndexPath:[selNode.indexPath indexPathByAddingIndex:index]];
	[fg setParent:selObj andSortIndex:(int32_t)index];
	return fg;
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
	
	NSArray<NSTreeNode*> *previousParents = [self.currentlyDraggedNodes valueForKeyPath:@"parentNode"];
	[self.dataStore moveNodes:self.currentlyDraggedNodes toIndexPath:[destParent.indexPath indexPathByAddingIndex:idx]];
	
	for (NSTreeNode *node in [self filterOutRedundant:[previousParents arrayByAddingObject:destParent]]) {
		[self restoreOrderingAndIndexPathStr:node];
	}

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


// Data source is handled by bindings anyway. These methods can be ignored
- (NSInteger)outlineView:(NSOutlineView *)outlineView numberOfChildrenOfItem:(id)item { return 0; }
- (BOOL)outlineView:(NSOutlineView *)outlineView isItemExpandable:(id)item { return YES; }
- (id)outlineView:(NSOutlineView *)outlineView child:(NSInteger)index ofItem:(id)item { return nil; }
- (id)outlineView:(NSOutlineView *)outlineView objectValueForTableColumn:(NSTableColumn *)tableColumn byItem:(id)item { return nil; }

/// Populate @c NSOutlineView data cells with core data object values.
- (NSView *)outlineView:(NSOutlineView *)outlineView viewForTableColumn:(NSTableColumn *)tableColumn item:(NSTreeNode*)item {
	NSUserInterfaceItemIdentifier ident = tableColumn.identifier;
	if (ident == CustomCellName) {
		FeedGroup *fg = [item representedObject];
		if (fg.type == SEPARATOR)
			ident = CustomCellSeparator;
	}
	NSTableCellView *v = [outlineView makeViewWithIdentifier:ident owner:self];
	if (v) return v;
	if (ident == CustomCellName)      return [NameColumnCell new];
	if (ident == CustomCellRefresh)   return [RefreshColumnCell new];
	if (ident == CustomCellSeparator) return [SeparatorColumnCell new];
	return nil;
}

/// @return User clicked cell item or @c nil if user did not click on a cell.
- (FeedGroup*)clickedItem {
	NSOutlineView *ov = self.view.outline;
	return [(NSTreeNode*)[ov itemAtRow:ov.clickedRow] representedObject];
}


#pragma mark - Keyboard Commands: undo, redo, copy, enter


/// Also look for commands right click menu of outline view
- (void)keyDown:(NSEvent *)event {
	if (![self.view.outline.menu performKeyEquivalent:event]) {
		[super keyDown:event];
	}
}

/// Returning @c NO will result in a Action-Not-Available-Buzzer sound
- (BOOL)respondsToSelector:(SEL)aSelector {
	if (aSelector == @selector(undo:))
		return [self.undoManager canUndo] && self.undoManager.groupingLevel == 0 && ![FeedDownload isUpdating];
	if (aSelector == @selector(redo:))
		return [self.undoManager canRedo] && self.undoManager.groupingLevel == 0 && ![FeedDownload isUpdating];
	if (aSelector == @selector(copy:) || aSelector == @selector(remove:))
		return self.dataStore.selectedNodes.count > 0;
	if (aSelector == @selector(editSelectedItem)) {
		FeedGroup *chosen = [self clickedItem];
		if (!chosen) chosen = self.dataStore.selectedObjects.firstObject;
		if (chosen && chosen.type != SEPARATOR)
			return YES; // can edit only if selection is not a separator
		return NO;
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

/// Copy human readable description of selected nodes to clipboard.
- (void)copy:(id)sender {
	NSMutableString *str = [[NSMutableString alloc] init];
	for (NSTreeNode *node in [self filterOutRedundant:self.dataStore.selectedNodes]) {
		[self traverseChildren:node appendString:str prefix:@""];
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

/// Remove redundant nodes that are already present in some selected parent node
- (NSArray<NSTreeNode*>*)filterOutRedundant:(NSArray<NSTreeNode*>*)nodes {
	NSMutableArray<NSTreeNode*> *result = [NSMutableArray arrayWithCapacity:nodes.count];
	for (NSTreeNode *current in nodes) {
		BOOL skip = NO;
		for (NSTreeNode *stored in result) {
			NSIndexPath *p = current.indexPath;
			while (p.length > stored.indexPath.length)
				p = [p indexPathByRemovingLastIndex];
			if ([p isEqualTo:stored.indexPath]) {
				skip = YES; break;
			}
		}
		if (skip == NO) [result addObject:current];
	}
	return result;
}

@end
