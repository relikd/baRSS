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

#import "OpmlExport.h"
#import "FeedMeta+Ext.h"
#import "FeedGroup+Ext.h"
#import "StoreCoordinator.h"
#import "FeedDownload.h"
#import "Constants.h"

@implementation OpmlExport

#pragma mark - Open & Save Panel

/// Display Open File Panel to select @c .opml file.
+ (void)showImportDialog:(NSWindow*)window withContext:(NSManagedObjectContext*)moc success:(nullable void(^)(NSArray<Feed*> *added))block {
	NSOpenPanel *op = [NSOpenPanel openPanel];
	op.allowedFileTypes = @[@"opml"];
	[op beginSheetModalForWindow:window completionHandler:^(NSModalResponse result) {
		if (result == NSModalResponseOK) {
			[self importFeedData:op.URL inContext:moc success:block];
		}
	}];
}

/// Display Save File Panel to select export destination. All feeds from core data will be exported.
+ (void)showExportDialog:(NSWindow*)window withContext:(NSManagedObjectContext*)moc {
	NSSavePanel *sp = [NSSavePanel savePanel];
	sp.nameFieldStringValue = [NSString stringWithFormat:@"baRSS feeds %@", [self currentDayAsString]];
	sp.allowedFileTypes = @[@"opml"];
	sp.allowsOtherFileTypes = YES;
	NSView *radioView = [self radioGroupCreate:@[NSLocalizedString(@"Hierarchical", nil),
												 NSLocalizedString(@"Flattened", nil)]];
	sp.accessoryView = [self viewByPrependingLabel:NSLocalizedString(@"Export format:", nil) toView:radioView];
	
	[sp beginSheetModalForWindow:window completionHandler:^(NSModalResponse result) {
		if (result == NSModalResponseOK) {
			BOOL flattened = ([self radioGroupSelection:radioView] == 1);
			NSString *exportString = [self exportFeedsHierarchical:!flattened inContext:moc];
			NSError *error;
			[exportString writeToURL:sp.URL atomically:YES encoding:NSUTF8StringEncoding error:&error];
			if (error) {
				[NSApp presentError:error];
			}
		}
	}];
}

/// Handle import dialog and perform web requests (feed data & icon). Creates a single undo group.
+ (void)showImportDialog:(NSWindow*)window withTreeController:(NSTreeController*)tree {
	NSManagedObjectContext *moc = tree.managedObjectContext;
	[moc.undoManager beginUndoGrouping];
	[self showImportDialog:window withContext:moc success:^(NSArray<Feed *> *added) {
		[StoreCoordinator saveContext:moc andParent:YES];
		[FeedDownload batchDownloadRSSAndFavicons:added showErrorAlert:YES rssFinished:^(NSArray<Feed *> *successful, BOOL *cancelFavicons) {
			if (successful.count > 0)
				[StoreCoordinator saveContext:moc andParent:YES];
			// we need to post a reset, since after deletion total unread count is wrong
			[[NSNotificationCenter defaultCenter] postNotificationName:kNotificationTotalUnreadCountReset object:nil];
		} finally:^(BOOL successful) {
			[moc.undoManager endUndoGrouping];
			if (successful) {
				[StoreCoordinator saveContext:moc andParent:YES];
				[tree rearrangeObjects]; // rearrange, because no new items appread instead only icon attrib changed
			}
		}];
	}];
}


#pragma mark - Import


/**
 Ask user for permission to import new items (prior import). User can choose to append or replace existing items.
 If user chooses to replace existing items, perform core data request to delete all feeds.

 @param document Used to count feed items that will be imported
 @return @c NO if user clicks 'Cancel' button. @c YES otherwise.
 */
+ (BOOL)askToAppendOrOverwriteAlert:(RSOPMLItem*)document inContext:(NSManagedObjectContext*)moc {
	NSUInteger count = [self recursiveNumberOfFeeds:document];
	NSAlert *alert = [[NSAlert alloc] init];
	alert.messageText = [NSString stringWithFormat:NSLocalizedString(@"Import of %lu feed items", nil), count];
	alert.informativeText = NSLocalizedString(@"Do you want to append or replace existing items?", nil);
	[alert addButtonWithTitle:NSLocalizedString(@"Import", nil)];
	[alert addButtonWithTitle:NSLocalizedString(@"Cancel", nil)];
	alert.accessoryView = [self radioGroupCreate:@[NSLocalizedString(@"Append", nil),
												   NSLocalizedString(@"Overwrite", nil)]];
	NSModalResponse code = [alert runModal];
	if (code == NSAlertSecondButtonReturn) { // cancel button
		return NO;
	}
	if ([self radioGroupSelection:alert.accessoryView] == 1) { // overwrite selected
		for (FeedGroup *g in [StoreCoordinator sortedListOfRootObjectsInContext:moc]) {
			[moc deleteObject:g];
		}
	}
	return YES;
}

/**
 Perform import of @c FeedGroup items.

 @param block Called after import finished. Parameter @c added is the list of inserted @c Feed items.
 */
+ (void)importFeedData:(NSURL*)fileURL inContext:(NSManagedObjectContext*)moc success:(nullable void(^)(NSArray<Feed*> *added))block {
	NSData *data = [NSData dataWithContentsOfURL:fileURL];
	RSXMLData *xml = [[RSXMLData alloc] initWithData:data urlString:@"opml-file-import"];
	RSOPMLParser *parser = [RSOPMLParser parserWithXMLData:xml];
	[parser parseAsync:^(RSOPMLItem * _Nullable doc, NSError * _Nullable error) {
		if (error) {
			[NSApp presentError:error];
		} else if ([self askToAppendOrOverwriteAlert:doc inContext:moc]) {
			NSMutableArray<Feed*> *list = [NSMutableArray array];
			int32_t idx = 0;
			if (moc.deletedObjects.count == 0) // if there are deleted objects, user choose to overwrite all items
				idx = (int32_t)[StoreCoordinator numberRootItemsInContext:moc];
			
			for (RSOPMLItem *item in doc.children) {
				[self importFeed:item parent:nil index:idx inContext:moc appendToList:list];
				idx += 1;
			}
			if (block) block(list);
		}
	}];
}

/**
 Import single item and recursively repeat import for each child.

 @param item The item to be imported.
 @param parent The already processed parent item.
 @param idx @c sortIndex within the @c parent item.
 @param moc Managed object context.
 @param list Mutable list where newly inserted @c Feed items will be added.
 */
+ (void)importFeed:(RSOPMLItem*)item parent:(FeedGroup*)parent index:(int32_t)idx inContext:(NSManagedObjectContext*)moc appendToList:(NSMutableArray<Feed*> *)list {
	FeedGroupType type = GROUP;
	if ([item attributeForKey:OPMLXMLURLKey]) {
		type = FEED;
	} else if ([item attributeForKey:@"separator"]) { // baRSS specific
		type = SEPARATOR;
	}
	
	FeedGroup *newFeed = [FeedGroup newGroup:type inContext:moc];
	[newFeed setParent:parent andSortIndex:idx];
	newFeed.name = (type == SEPARATOR ? @"---" : item.displayName);
	
	switch (type) {
		case GROUP:
			for (NSUInteger i = 0; i < item.children.count; i++) {
				[self importFeed:item.children[i] parent:newFeed index:(int32_t)i inContext:moc appendToList:list];
			}
			break;
			
		case FEED:
			@autoreleasepool {
				FeedMeta *meta = newFeed.feed.meta;
				meta.url = [item attributeForKey:OPMLXMLURLKey];
				id refresh = [item attributeForKey:@"refreshInterval"]; // baRSS specific
				if (refresh) {
					[meta setRefreshAndUnitFromInterval:(int32_t)[refresh integerValue]];
				} else {
					[meta setRefresh:30 unit:RefreshUnitMinutes];
				}
			}
			[list addObject:newFeed.feed];
			break;
			
		case SEPARATOR:
			break;
	}
}


#pragma mark - Export


/**
 Initiate export of current core data state. Write opml header and all root items.

 @param flag If @c YES keep parent-child structure intact. If @c NO ignore all parents and add @c Feed items only.
 @param moc Managed object context.
 @return Save this string to file.
 */
+ (NSString*)exportFeedsHierarchical:(BOOL)flag inContext:(NSManagedObjectContext*)moc {
	NSDictionary *info = @{@"dateCreated" : [NSDate date], @"ownerName" : @"baRSS", OPMLTitleKey : @"baRSS feeds"};
	RSOPMLItem *doc = [RSOPMLItem itemWithAttributes:info];
	@autoreleasepool {
		NSArray<FeedGroup*> *arr = [StoreCoordinator sortedListOfRootObjectsInContext:moc];
		for (FeedGroup *item in arr) {
			[self addChild:item toParent:doc hierarchical:flag];
		}
	}
	return [doc exportOPMLAsString];
}

/**
 Build up @c RSOPMLItem structure recursively. Essentially, re-create same structure as in core data storage.

 @param flag If @c NO don't add groups to export file but continue evaluation of child items.
 */
+ (void)addChild:(FeedGroup*)item toParent:(RSOPMLItem*)parent hierarchical:(BOOL)flag {
	RSOPMLItem *child = [RSOPMLItem new];
	[child setAttribute:item.name forKey:OPMLTitleKey];
	if (flag || item.type == SEPARATOR || item.feed) {
		[parent addChild:child]; // dont add item if item is group and hierarchical == NO
	}
	
	if (item.type == SEPARATOR) {
		[child setAttribute:@"true" forKey:@"separator"]; // baRSS specific
	} else if (item.feed) {
		[child setAttribute:@"rss" forKey:OPMLTypeKey];
		[child setAttribute:item.feed.link forKey:OPMLHMTLURLKey];
		[child setAttribute:item.feed.meta.url forKey:OPMLXMLURLKey];
		NSNumber *refreshNum = [NSNumber numberWithInteger:[item.feed.meta refreshInterval]];
		[child setAttribute:refreshNum forKey:@"refreshInterval"]; // baRSS specific
	} else {
		for (FeedGroup *subItem in [item sortedChildren]) {
			[self addChild:subItem toParent:(flag ? child : parent) hierarchical:flag];
		}
	}
}


#pragma mark - Helper


/// @return Date formatted as @c yyyy-MM-dd
+ (NSString*)currentDayAsString {
	NSDateComponents *now = [[NSCalendar currentCalendar] components:NSCalendarUnitDay | NSCalendarUnitMonth | NSCalendarUnitYear fromDate:[NSDate date]];
	return  [NSString stringWithFormat:@"%04ld-%02ld-%02ld", now.year, now.month, now.day];
}

/// Count items where @c xmlURL key is set.
+ (NSUInteger)recursiveNumberOfFeeds:(RSOPMLItem*)document {
	if ([document attributeForKey:OPMLXMLURLKey]) {
		return 1;
	} else {
		NSUInteger sum = 0;
		for (RSOPMLItem *child in document.children) {
			sum += [self recursiveNumberOfFeeds:child];
		}
		return sum;
	}
}

/// Solely used to group radio buttons
+ (void)donothing {}

/// Create a new view with as many @c NSRadioButton items as there are strings. Buttons @c tag is equal to the array index.
+ (NSView*)radioGroupCreate:(NSArray<NSString*>*)titles {
	if (titles.count == 0)
		return nil;
	
	NSRect viewRect = NSMakeRect(0, 0, 0, 8);
	NSInteger idx = (NSInteger)titles.count;
	NSView *v = [[NSView alloc] init];
	for (NSString *title in titles.reverseObjectEnumerator) {
		idx -= 1;
		NSButton *btn = [NSButton radioButtonWithTitle:title target:self action:@selector(donothing)];
		btn.tag = idx;
		btn.frame = NSOffsetRect(btn.frame, 0, viewRect.size.height);
		viewRect.size.height += btn.frame.size.height + 2; // 2px padding
		if (viewRect.size.width < btn.frame.size.width)
			viewRect.size.width = btn.frame.size.width;
		[v addSubview:btn];
		if (idx == 0)
			btn.state = NSControlStateValueOn;
	}
	viewRect.size.height += 6; // 8 - 2px padding
	v.frame = viewRect;
	return v;
}

/// Loop over all subviews and find the @c NSButton that is selected.
+ (NSInteger)radioGroupSelection:(NSView*)view {
	for (NSButton *btn in view.subviews) {
		if ([btn isKindOfClass:[NSButton class]] && btn.state == NSControlStateValueOn) {
			return btn.tag;
		}
	}
	return -1;
}

/// @return New view with @c NSTextField label in the top left corner and @c radioView on the right side.
+ (NSView*)viewByPrependingLabel:(NSString*)str toView:(NSView*)radioView {
	NSTextField *label = [NSTextField textFieldWithString:str];
	label.editable = NO;
	label.selectable = NO;
	label.bezeled = NO;
	label.drawsBackground = NO;
	
	NSRect fL = label.frame;
	NSRect fR = radioView.frame;
	fL.origin.y += fR.size.height - fL.size.height - 8;
	fR.origin.x += fL.size.width;
	label.frame = fL;
	radioView.frame = fR;
	
	NSView *view = [[NSView alloc] initWithFrame:NSMakeRect(0, 0, NSMaxX(fR), NSMaxY(fR))];
	[view addSubview:label];
	[view addSubview:radioView];
	return view;
}

@end
