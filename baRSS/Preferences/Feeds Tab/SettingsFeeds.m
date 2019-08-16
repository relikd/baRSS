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

#import "SettingsFeeds+DragDrop.h"
#import "Constants.h"
#import "StoreCoordinator.h"
#import "ModalFeedEdit.h"
#import "FeedGroup+Ext.h"
#import "UpdateScheduler.h"
#import "SettingsFeedsView.h"

@interface SettingsFeeds ()
@property (strong) SettingsFeedsView *view; // override super
@property (strong) NSUndoManager *undoManager;
@property (strong) NSTimer *timerStatusInfo;
@end

@implementation SettingsFeeds
@dynamic view;

- (void)loadView {
	[self initCoreDataStore];
	self.view = [[SettingsFeedsView alloc] initWithController:self];
	self.view.outline.delegate = self; // viewForTableColumn
	[self prepareOutlineViewForDragDrop:self.view.outline];
}

- (void)viewDidLoad {
    [super viewDidLoad];
	// Register for notifications
	RegisterNotification(kNotificationFeedUpdated, @selector(feedUpdated:), self);
	RegisterNotification(kNotificationFeedIconUpdated, @selector(feedUpdated:), self);
	RegisterNotification(kNotificationGroupInserted, @selector(groupInserted:), self);
	// Status bar
	RegisterNotification(kNotificationScheduleTimerChanged, @selector(updateStatusInfo), self);
	RegisterNotification(kNotificationNetworkStatusChanged, @selector(updateStatusInfo), self);
	RegisterNotification(kNotificationBackgroundUpdateInProgress, @selector(updateStatusInfo), self);
}

- (void)dealloc {
	[[NSNotificationCenter defaultCenter] removeObserver:self];
}

/// Initialize status info timer
- (void)viewWillAppear {
	// needed to scroll outline view to top (if prefs open on another tab)
	[self.dataStore setSelectionIndexPath:[NSIndexPath indexPathWithIndex:0]];
	self.timerStatusInfo = [NSTimer timerWithTimeInterval:NSTimeIntervalSince1970 target:self selector:@selector(updateStatusInfo) userInfo:nil repeats:YES];
	[[NSRunLoop mainRunLoop] addTimer:self.timerStatusInfo forMode:NSRunLoopCommonModes];
	[self updateStatusInfo];
}

/// Timer cleanup
- (void)viewWillDisappear {
	// in viewWillDisappear otherwise dealloc will not be called
	[self.timerStatusInfo invalidate];
	self.timerStatusInfo = nil;
}


#pragma mark - Persist state


/// Prepare undo manager and tree controller
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

/**
 Refresh current context from parent context and start new undo grouping.
 @note Should be balanced with @c endCoreDataChangeUndoEmpty:forceUndo:
 */
- (void)beginCoreDataChange {
	// Does seem to create problems with undo stack if refreshing from parent context
	//[self.dataStore.managedObjectContext refreshAllObjects];
	[self.undoManager beginUndoGrouping];
}

/**
 End undo grouping and save changes to persistent store. Or undo group if no changes occured.
 @note Should be balanced with @c beginCoreDataChange

 @param undoEmpty If @c YES undo the last operation if no changes were made (unnecessary undo).
 @param force If @c YES force @c NSUndoManager to undo the changes immediatelly.
 @return Returns @c YES if context was saved.
 */
- (BOOL)endCoreDataChangeUndoEmpty:(BOOL)undoEmpty forceUndo:(BOOL)force {
	[self.undoManager endUndoGrouping];
	if (force || (undoEmpty && !self.dataStore.managedObjectContext.hasChanges)) {
		[self.undoManager disableUndoRegistration];
		[self.undoManager undoNestedGroup];
		[self.undoManager enableUndoRegistration];
		return NO;
	}
	[StoreCoordinator saveContext:self.dataStore.managedObjectContext andParent:YES];
	return YES;
}

/// After the user did undo or redo we can't ensure integrity without doing some additional work.
- (void)saveWithUnpredictableChange {
	// dont use unless you merge changes from main
//	NSManagedObjectContext *moc = self.dataStore.managedObjectContext;
//	NSPredicate *pred = [NSPredicate predicateWithFormat:@"class == %@", [FeedArticle class]];
//	NSInteger del = [[[moc.deletedObjects filteredSetUsingPredicate:pred] valueForKeyPath:@"@sum.unread"] integerValue];
//	NSInteger ins = [[[moc.insertedObjects filteredSetUsingPredicate:pred] valueForKeyPath:@"@sum.unread"] integerValue];
//	NSLog(@"%ld, %ld", del, ins);
	[StoreCoordinator saveContext:self.dataStore.managedObjectContext andParent:YES];
	PostNotification(kNotificationTotalUnreadCountReset, nil);
	[self.dataStore rearrangeObjects]; // update ordering
	[UpdateScheduler scheduleNextFeed];
}

/// Callback method fired when feed (or icon) has been updated in the background.
- (void)feedUpdated:(NSNotification*)notify {
	NSManagedObjectID *oid = notify.object;
	NSManagedObjectContext *moc = self.dataStore.managedObjectContext;
	Feed *feed = [moc objectRegisteredForID:oid];
	if (feed) {
		if (self.undoManager.groupingLevel == 0) // don't mess around if user is editing something
			[moc refreshObject:feed mergeChanges:YES];
		[self.dataStore rearrangeObjects]; // update display, show new icon
	}
}

/// Callback method fired when feed is inserted via a 'feed://' url
- (void)groupInserted:(NSNotification*)notify {
	[self.dataStore fetch:self];
}


#pragma mark - Activity Spinner & Status Info


/// Callback method to update status info. Called more often as the interval is getting shorter.
- (void)updateStatusInfo {
	if ([UpdateScheduler feedsInQueue] > 0) {
		[self.timerStatusInfo setFireDate:[NSDate distantFuture]];
		self.view.status.stringValue = [UpdateScheduler updatingXFeeds];
		[self.view.spinner startAnimation:nil];
	} else {
		[self.view.spinner stopAnimation:nil];
		double remaining;
		self.view.status.stringValue = [UpdateScheduler remainingTimeTillNextUpdate:&remaining];
		if (remaining < 1e5) { // keep timer running if < 28 hours
			// Next update is aligned with minute (fmod) else update 1/sec
			NSDate *nextUpdate = [NSDate dateWithTimeIntervalSinceNow: (remaining > 60 ? fmod(remaining, 60) : 1)];
			[self.timerStatusInfo setFireDate:nextUpdate];
		}
	}
}


#pragma mark - UI Button Interaction


/// Open clicked or selected item for editing.
- (void)editSelectedItem {
	FeedGroup *chosen = [self userSelectionFirst].representedObject;
	[self showModalForFeedGroup:chosen isGroupEdit:YES]; // yes will be overwritten anyway
}

/// Open clicked item for editing.
- (void)doubleClickOutlineView:(NSOutlineView*)sender {
	if (sender.clickedRow != -1) // only if there is a clicked item
		[self editSelectedItem];
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
	[self insertFeedGroupAtSelection:SEPARATOR];
	[self endCoreDataChangeUndoEmpty:NO forceUndo:NO];
}

/// Remove feed button. User has selected one or more item in outline view.
- (void)remove:(id)sender {
	NSArray<NSTreeNode*> *nodes = [self userSelectionAll];
	NSArray<NSTreeNode*> *parentNodes = [nodes valueForKeyPath:@"parentNode"];
	[self beginCoreDataChange];
	[self.dataStore removeObjectsAtArrangedObjectIndexPaths:[nodes valueForKeyPath:@"indexPath"]];
	[self restoreOrderingAndIndexPathStr:parentNodes];
	[self endCoreDataChangeUndoEmpty:NO forceUndo:NO];
	[UpdateScheduler scheduleNextFeed];
	PostNotification(kNotificationTotalUnreadCountReset, nil);
}

- (void)openImportDialog {
	[[OpmlFileImport withDelegate:self] showImportDialog:self.view.window];
}

- (void)openExportDialog {
	[[OpmlFileExport withDelegate:self] showExportDialog:self.view.window];
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
		return [self.undoManager canUndo] && self.undoManager.groupingLevel == 0 && ![UpdateScheduler isUpdating];
	if (aSelector == @selector(redo:))
		return [self.undoManager canRedo] && self.undoManager.groupingLevel == 0 && ![UpdateScheduler isUpdating];
	if (aSelector == @selector(copy:) || aSelector == @selector(remove:))
		return ([self userSelectionFirst] != nil);
	if (aSelector == @selector(editSelectedItem)) {
		FeedGroup *chosen = [self userSelectionFirst].representedObject;
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
	[[NSPasteboard generalPasteboard] declareTypes:@[NSPasteboardTypeString] owner:self]; // DragDrop handles callback
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
	} else {
		flag = (fg.type == GROUP);
	}
	
	ModalEditDialog *editDialog = (flag ? [ModalGroupEdit modalWith:fg] : [ModalFeedEdit modalWith:fg]);
	
	[self.view.window beginSheet:[editDialog getModalSheet] completionHandler:^(NSModalResponse returnCode) {
		if (returnCode == NSModalResponseOK) {
			[editDialog applyChangesToCoreDataObject];
		}
		if ([self endCoreDataChangeUndoEmpty:YES forceUndo:(returnCode != NSModalResponseOK)]) {
			if (!flag) [UpdateScheduler scheduleNextFeed]; // only for feed edit
			[self.dataStore rearrangeObjects]; // update display, edited title or icon
		}
	}];
}

/// Insert @c FeedGroup item at the end of the current folder (or inside if expanded)
- (FeedGroup*)insertFeedGroupAtSelection:(FeedGroupType)type {
	NSTreeNode *selNode = [self userSelectionFirst];
	FeedGroup *selObj = selNode.representedObject;
	// If group selected and expanded, insert into group. Else: append at end of current folder
	if (![self.view.outline isItemExpanded:selNode]) {
		selObj = selObj.parent; // nullable
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


#pragma mark - Data Source Delegate


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


#pragma mark - Helper Methods


/**
 Expected user selection as displayed in outline (border highlight).
 Return clicked row only if it isn't included in the selection.
 */
- (NSArray<NSTreeNode*>*)userSelectionAll {
	NSOutlineView *ov = self.view.outline;
	NSTreeNode *clicked = [ov itemAtRow: ov.clickedRow];
	if (!clicked || [self.dataStore.selectedNodes containsObject:clicked]) {
		return self.dataStore.selectedNodes;
	}
	return @[clicked];
}

/// Return clicked row (if present) or first selected node otherwise.
- (NSTreeNode*)userSelectionFirst {
	NSTreeNode *clicked = [self.view.outline itemAtRow: self.view.outline.clickedRow];
	if (clicked) return clicked;
	return self.dataStore.selectedNodes.firstObject;
}

/// Loop over all descendants and update @c sortIndex @c (FeedGroup) as well as all @c indexPath @c (Feed)
- (void)restoreOrderingAndIndexPathStr:(NSArray<NSTreeNode*>*)parentsList {
	for (NSTreeNode *parent in parentsList) {
		for (NSUInteger i = 0; i < parent.childNodes.count; i++) {
			FeedGroup *fg = parent.childNodes[i].representedObject;
			[fg setSortIndexIfChanged:(int32_t)i];
		}
	}
}

@end
