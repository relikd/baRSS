//
//  The MIT License (MIT)
//  Copyright (c) 2019 Oleg Geier
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
#import "StoreCoordinator.h"
#import "Constants.h"
#import "WebFeed.h"
#import "FeedGroup+Ext.h"

// Pasteboard type used during internal row reordering
const NSPasteboardType dragReorder = @"de.relikd.baRSS.drag-reorder";

@implementation SettingsFeeds (DragDrop)

/// Set self as @c dataSource and register drag types
- (void)prepareOutlineViewForDragDrop:(NSOutlineView*)outline {
	outline.dataSource = self;
	[outline registerForDraggedTypes:@[dragReorder, (NSPasteboardType)kUTTypeFileURL]];
	[outline setDraggingSourceOperationMask:NSDragOperationMove forLocal:YES]; // reorder
	[outline setDraggingSourceOperationMask:NSDragOperationCopy forLocal:NO]; // export
}


#pragma mark - Dragging Support, Data Source Delegate


/// Begin drag-n-drop operation by copying selected nodes to memory & prepare @c FilePromise
- (BOOL)outlineView:(NSOutlineView *)outlineView writeItems:(NSArray *)items toPasteboard:(NSPasteboard *)pasteboard {
	NSFilePromiseProvider *opml = [[NSFilePromiseProvider alloc] initWithFileType:UTI_OPML delegate:self];
	[pasteboard writeObjects:@[opml]]; // opml file export
	[pasteboard setString:@"dragging" forType:dragReorder]; // internal row reordering
	[pasteboard addTypes:@[NSPasteboardTypeString] owner:self]; // string export, same as Cmd-C
	self.currentlyDraggedNodes = items;
	return YES;
}

/// Clear previous memory after drag operation
- (void)outlineView:(NSOutlineView *)outlineView draggingSession:(NSDraggingSession *)session endedAtPoint:(NSPoint)screenPoint operation:(NSDragOperation)operation {
	self.currentlyDraggedNodes = nil;
}

/// Prohibit drag if destination is leaf or source has no opml
- (NSDragOperation)outlineView:(NSOutlineView *)outlineView validateDrop:(id <NSDraggingInfo>)info proposedItem:(NSTreeNode*)parent proposedChildIndex:(NSInteger)index {
	if (info.numberOfValidItemsForDrop == 0 // none of the files is opml
		|| (index == -1 && [parent isLeaf])) { // drag on specific item (-1) that is not a group
		return NSDragOperationNone;
	}
	if (info.draggingSource == outlineView) {
		// Internal item reordering (dragReorder)
		for (NSTreeNode *selection in self.currentlyDraggedNodes) {
			if (IndexPathIsChildOfParent(parent.indexPath, selection.indexPath))
				return NSDragOperationNone; // cannot move items into a child of its own
		}
		return NSDragOperationMove;
	} else {
		// Dropped file urls, set whole table as destination
		[outlineView setDropItem:nil dropChildIndex:NSOutlineViewDropOnItemIndex];
		return NSDragOperationGeneric;
	}
}

/// Perform drag-n-drop operation, move nodes to new destination and update all indices
- (BOOL)outlineView:(NSOutlineView *)outlineView acceptDrop:(id <NSDraggingInfo>)info item:(NSTreeNode*)newParent childIndex:(NSInteger)index {
	if (info.numberOfValidItemsForDrop == 0)
		return NO;
	
	if (info.draggingSource == outlineView) {
		// Calculate drop path
		if (!newParent) newParent = [self.dataStore arrangedObjects]; // root
		NSUInteger idx = (NSUInteger)index;
		if (index == -1) // if folder, append to end
			idx = newParent.childNodes.count;
		
		// Internal item reordering (dragReorder)
		[self beginCoreDataChange];
		NSArray<NSTreeNode*> *previousParents = [self.currentlyDraggedNodes valueForKeyPath:@"parentNode"];
		[self.dataStore moveNodes:self.currentlyDraggedNodes toIndexPath:[newParent.indexPath indexPathByAddingIndex:idx]];
		[self restoreOrderingAndIndexPathStr:[previousParents arrayByAddingObject:newParent]];
		[self endCoreDataChangeUndoEmpty:YES forceUndo:NO];
	} else {
		// File import
		NSArray<NSURL*> *files = [info.draggingPasteboard readObjectsForClasses:@[NSURL.class] options:@{ NSPasteboardURLReadingContentsConformToTypesKey: @[UTI_OPML] }];
		[self importOpmlFiles:files];
	}
	return YES;
}


#pragma mark - OPML File Import


/// Helper method is also called from Application Delegate
- (void)importOpmlFiles:(NSArray<NSURL*>*)files {
	[[OpmlFileImport withDelegate:self] importFiles:files];
}

/// Filter out file urls that are not opml files
- (void)outlineView:(NSOutlineView *)outlineView updateDraggingItemsForDrag:(id <NSDraggingInfo>)info {
	if ([info.draggingPasteboard canReadItemWithDataConformingToTypes:@[(NSPasteboardType)kUTTypeFileURL]]) {
		NSDraggingItemEnumerationOptions opt = NSDraggingItemEnumerationClearNonenumeratedImages;
		NSArray<Class> *cls = @[ [NSURL class] ];
		NSDictionary *dict = @{ NSPasteboardURLReadingContentsConformToTypesKey: @[UTI_OPML] };
		__block NSInteger count = 0;
		[info enumerateDraggingItemsWithOptions:opt forView:nil classes:cls searchOptions:dict usingBlock:^(NSDraggingItem * _Nonnull draggingItem, NSInteger idx, BOOL * _Nonnull stop) {
			++count;
		}];
		info.numberOfValidItemsForDrop = count;
	}
}

/// OPML import (context provider)
- (NSManagedObjectContext *)opmlFileImportContext {
	return self.dataStore.managedObjectContext;
}

/// OPML import (will begin)
- (void)opmlFileImportWillBegin:(NSManagedObjectContext*)moc {
	[self beginCoreDataChange];
}

/// OPML import (did end). Save changes, select newly inserted, and perform web request.
- (void)opmlFileImportDidEnd:(NSManagedObjectContext*)moc {
	if (moc.undoManager.groupingLevel == 1 && !moc.hasChanges) { // exit early, dont need to create empty arrays
		[self endCoreDataChangeUndoEmpty:YES forceUndo:YES];
		return;
	}
	// Get list of feeds, and root level selection
	NSUInteger count = moc.insertedObjects.count;
	NSMutableArray<NSIndexPath*> *selection = [NSMutableArray arrayWithCapacity:count];
	NSMutableArray<Feed*> *feedsList = [NSMutableArray arrayWithCapacity:count];
	for (__kindof NSManagedObject *obj in moc.insertedObjects) {
		if ([obj isKindOfClass:[Feed class]]) {
			[feedsList addObject:obj]; // list of feeds that need download
		} else if ([obj isKindOfClass:[FeedGroup class]]) {
			FeedGroup *fg = obj;
			if (fg.parent == nil) // list of root level parents
				[selection addObject:[NSIndexPath indexPathWithIndex:(NSUInteger)fg.sortIndex]];
		}
	}
	// Persist state, because on crash we have at least inserted items (without articles & icons)
	[StoreCoordinator saveContext:moc andParent:YES];
	if (selection.count > 0)
		[self.dataStore setSelectionIndexPaths:[selection sortedArrayUsingSelector:@selector(compare:)]];
	[WebFeed batchDownloadFeeds:feedsList favicons:YES showErrorAlert:YES finally:^{
		[self endCoreDataChangeUndoEmpty:NO forceUndo:NO];
		[self someDatesChangedScheduleUpdateTimer];
	}];
}


#pragma mark - OPML File Export


/// OPML export with drag-n-drop (filename)
- (nonnull NSString *)filePromiseProvider:(nonnull NSFilePromiseProvider *)filePromiseProvider fileNameForType:(nonnull NSString *)fileType {
	CFStringRef ext = UTTypeCopyPreferredTagWithClass((__bridge CFStringRef)(fileType), kUTTagClassFilenameExtension);
	return [@"baRSS export" stringByAppendingPathExtension: CFBridgingRelease(ext)];
}

/// OPML export with drag-n-drop (write)
- (void)filePromiseProvider:(nonnull NSFilePromiseProvider *)filePromiseProvider writePromiseToURL:(nonnull NSURL *)url completionHandler:(nonnull void (^)(NSError * _Nullable))completionHandler {
	NSError *err = [[OpmlFileExport withDelegate:self] writeOPMLFile:url withOptions:0];
	completionHandler(err);
}

/// OPML export: drag-n-drop & menu export (content provider)
- (NSArray<FeedGroup*>*)opmlFileExportListOfFeedGroups:(OpmlFileExportOptions)options {
	if (options & OpmlFileExportOptionFullBackup) // through button or menu click
		return [self.dataStore.arrangedObjects.childNodes valueForKeyPath:@"representedObject"];
	// drag-n-drop with file promise provider
	return [[self draggedTopLevelNodes] valueForKeyPath:@"representedObject"];
}


#pragma mark - String Export


/// Called during export for @c NSPasteboardTypeString (text drag and copy:)
- (void)pasteboard:(NSPasteboard *)sender provideDataForType:(NSPasteboardType)type {
	if (type == NSPasteboardTypeString) {
		NSMutableString *str = [[NSMutableString alloc] init];
		for (NSTreeNode *node in [self draggedTopLevelNodes]) {
			[self traverseChildren:node appendString:str prefix:@""];
		}
		[str deleteCharactersInRange: NSMakeRange(str.length - 1, 1)]; // delete trailing new-line
		[sender setString:str forType:type];
	}
}

/**
 Go through all children recursively and prepend the string with spaces as nesting
 @param obj Root Node or parent Node
 @param str An initialized @c NSMutableString to append to
 @param prefix Should be @c @@"" for the first call
 */
- (void)traverseChildren:(NSTreeNode*)obj appendString:(NSMutableString*)str prefix:(NSString*)prefix {
	FeedGroup *fg = obj.representedObject;
	[str appendFormat:@"%@%@\n", prefix, [fg readableDescription]];
	prefix = [prefix stringByAppendingString:@"  "];
	for (NSTreeNode *child in obj.childNodes) {
		[self traverseChildren:child appendString:str prefix:prefix];
	}
}


#pragma mark - Helper Methods


/// Selection without redundant nodes that are already present in some selected parent node
- (NSArray<NSTreeNode*>*)draggedTopLevelNodes {
	NSArray *nodes = self.currentlyDraggedNodes;
	if (!nodes) nodes = self.dataStore.selectedNodes; // fallback to selection (e.g., Cmd-C)
	NSMutableArray<NSTreeNode*> *result = [NSMutableArray arrayWithCapacity:nodes.count];
	for (NSTreeNode *current in nodes) {
		BOOL skip = NO;
		for (NSTreeNode *stored in result) {
			if (IndexPathIsChildOfParent(current.indexPath, stored.indexPath)) {
				skip = YES; break;
			}
		}
		if (skip == NO) [result addObject:current];
	}
	return result;
}

NS_INLINE BOOL IndexPathIsChildOfParent(NSIndexPath *child, NSIndexPath *parent) {
	while (child.length > parent.length)
		child = [child indexPathByRemovingLastIndex];
	return [child isEqualTo:parent];
}

@end
