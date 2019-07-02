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
#import "NSDate+Ext.h"
#import "NSView+Ext.h"

@implementation OpmlExport

#pragma mark - Open & Save Panel

/// Display Open File Panel to select @c .opml file. Perform web requests (feed data & icon) within a single undo group.
+ (void)showImportDialog:(NSWindow*)window withContext:(NSManagedObjectContext*)moc {
	NSOpenPanel *op = [NSOpenPanel openPanel];
	op.allowedFileTypes = @[@"opml"];
	[op beginSheetModalForWindow:window completionHandler:^(NSModalResponse result) {
		if (result == NSModalResponseOK) {
			NSData *data = [NSData dataWithContentsOfURL:op.URL];
			RSXMLData *xml = [[RSXMLData alloc] initWithData:data urlString:@"opml-file-import"];
			RSOPMLParser *parser = [RSOPMLParser parserWithXMLData:xml];
			[parser parseAsync:^(RSOPMLItem * _Nullable doc, NSError * _Nullable error) {
				if (error) {
					[NSApp presentError:error];
				} else {
					[self importOPMLDocument:doc inContext:moc];
				}
			}];
		}
	}];
}

/// Display Save File Panel to select export destination. All feeds from core data will be exported.
+ (void)showExportDialog:(NSWindow*)window withContext:(NSManagedObjectContext*)moc {
	NSSavePanel *sp = [NSSavePanel savePanel];
	sp.nameFieldStringValue = [NSString stringWithFormat:@"baRSS feeds %@", [NSDate dayStringLocalized]];
	sp.allowedFileTypes = @[@"opml"];
	sp.allowsOtherFileTypes = YES;
	NSView *radioView = [NSView radioGroup:@[NSLocalizedString(@"Hierarchical", nil),
											 NSLocalizedString(@"Flattened", nil)]];
	sp.accessoryView = [NSView wrapView:radioView withLabel:NSLocalizedString(@"Export format:", nil) padding:PAD_M];
	
	[sp beginSheetModalForWindow:window completionHandler:^(NSModalResponse result) {
		if (result == NSModalResponseOK) {
			BOOL flattened = ([self radioGroupSelection:radioView] == 1);
			NSArray<FeedGroup*> *list = [StoreCoordinator sortedFeedGroupsWithParent:nil inContext:moc];
			NSXMLDocument *doc = [self xmlDocumentForFeeds:list hierarchical:!flattened];
			NSData *xml = [doc XMLDataWithOptions:NSXMLNodePreserveAttributeOrder | NSXMLNodePrettyPrint];
			NSError *error;
			[xml writeToURL:sp.URL options:NSDataWritingAtomic error:&error];
			if (error) {
				[NSApp presentError:error];
			}
		}
	}];
}


#pragma mark - Import


/**
 Ask user for permission to import new items (prior import). User can choose to append or replace existing items.
 If user chooses to replace existing items, perform core data request to delete all feeds.

 @param document Used to count feed items that will be imported
 @return @c -1: User clicked 'Cancel' button. @c 0: Append items. @c 1: Overwrite items.
 */
+ (NSInteger)askToAppendOrOverwriteAlert:(RSOPMLItem*)document inContext:(NSManagedObjectContext*)moc {
	NSUInteger count = [self recursiveNumberOfFeeds:document];
	NSAlert *alert = [[NSAlert alloc] init];
	alert.messageText = [NSString stringWithFormat:NSLocalizedString(@"Import of %lu feed items", nil), count];
	alert.informativeText = NSLocalizedString(@"Do you want to append or replace existing items?", nil);
	[alert addButtonWithTitle:NSLocalizedString(@"Import", nil)];
	[alert addButtonWithTitle:NSLocalizedString(@"Cancel", nil)];
	alert.accessoryView = [NSView radioGroup:@[NSLocalizedString(@"Append", nil),
											   NSLocalizedString(@"Overwrite", nil)]];
	
	if ([alert runModal] == NSAlertFirstButtonReturn) {
		return [self radioGroupSelection:alert.accessoryView];
	}
	return -1; // cancel button
}

/**
 Perform import of @c FeedGroup items.
 */
+ (void)importOPMLDocument:(RSOPMLItem*)doc inContext:(NSManagedObjectContext*)moc {
	NSInteger select = [self askToAppendOrOverwriteAlert:doc inContext:moc];
	if (select < 0 || select > 1) // not a valid selection (or cancel button)
		return;
	
	[moc.undoManager beginUndoGrouping];
	
	int32_t idx = 0;
	if (select == 1) { // overwrite selected
		for (FeedGroup *fg in [StoreCoordinator sortedFeedGroupsWithParent:nil inContext:moc]) {
			[moc deleteObject:fg]; // Not a batch delete request to support undo
		}
		[[NSNotificationCenter defaultCenter] postNotificationName:kNotificationTotalUnreadCountReset object:@0];
	} else {
		idx = (int32_t)[StoreCoordinator countRootItemsInContext:moc];
	}
	
	NSMutableArray<Feed*> *list = [NSMutableArray array];
	for (RSOPMLItem *item in doc.children) {
		[self importFeed:item parent:nil index:idx inContext:moc appendToList:list];
		idx += 1;
	}
	// Persist state, because on crash we have at least inserted items (without articles & icons)
	[StoreCoordinator saveContext:moc andParent:YES];
	[FeedDownload batchDownloadFeeds:list favicons:YES showErrorAlert:YES finally:^{
		[StoreCoordinator saveContext:moc andParent:YES];
		[moc.undoManager endUndoGrouping];
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
					[meta setRefreshAndSchedule:(int32_t)[refresh integerValue]];
				} else {
					[meta setRefreshAndSchedule:kDefaultFeedRefreshInterval]; // TODO: set -1, then auto
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
 Create NSXMLNode structure with application header nodes and body node containing feed items.
 
 @param flag If @c YES keep parent-child structure intact. If @c NO ignore all parents and add @c Feed items only.
 */
+ (NSXMLDocument*)xmlDocumentForFeeds:(NSArray<FeedGroup*>*)list hierarchical:(BOOL)flag {
	NSXMLElement *head = [NSXMLElement elementWithName:@"head"];
	head.children = @[[NSXMLElement elementWithName:@"title" stringValue:@"baRSS feeds"],
					  [NSXMLElement elementWithName:@"ownerName" stringValue:@"baRSS"],
					  [NSXMLElement elementWithName:@"dateCreated" stringValue:[NSDate dayStringISO8601]] ];
	
	NSXMLElement *body = [NSXMLElement elementWithName:@"body"];
	for (FeedGroup *item in list) {
		[self appendChild:item toNode:body hierarchical:flag];
	}
	
	NSXMLElement *opml = [NSXMLElement elementWithName:@"opml"];
	opml.attributes = @[[NSXMLNode attributeWithName:@"version" stringValue:@"1.0"]];
	opml.children = @[head, body];
	
	NSXMLDocument *xml = [NSXMLDocument documentWithRootElement:opml];
	xml.version = @"1.0";
	xml.characterEncoding = @"UTF-8";
	return xml;
}

/**
 Build up @c NSXMLNode structure recursively. Essentially, re-create same structure as in core data storage.
 
 @param flag If @c NO don't add groups to export file but continue evaluation of child items.
 */
+ (void)appendChild:(FeedGroup*)item toNode:(NSXMLElement *)parent hierarchical:(BOOL)flag {
	if (flag || item.type != GROUP) {
		// dont add group node if hierarchical == NO
		NSXMLElement *outline = [NSXMLElement elementWithName:@"outline"];
		[parent addChild:outline];
		[outline addAttribute:[NSXMLNode attributeWithName:OPMLTitleKey stringValue:item.name]];
		[outline addAttribute:[NSXMLNode attributeWithName:OPMLTextKey stringValue:item.name]];
		
		if (item.type == SEPARATOR) {
			[outline addAttribute:[NSXMLNode attributeWithName:@"separator" stringValue:@"true"]]; // baRSS specific
		} else if (item.feed) {
			[outline addAttribute:[NSXMLNode attributeWithName:OPMLHMTLURLKey stringValue:item.feed.link]];
			[outline addAttribute:[NSXMLNode attributeWithName:OPMLXMLURLKey stringValue:item.feed.meta.url]];
			[outline addAttribute:[NSXMLNode attributeWithName:OPMLTypeKey stringValue:@"rss"]];
			NSString *intervalStr = [NSString stringWithFormat:@"%d", item.feed.meta.refresh];
			[outline addAttribute:[NSXMLNode attributeWithName:@"refreshInterval" stringValue:intervalStr]]; // baRSS specific
			// TODO: option to export unread state?
		}
		parent = outline;
	}
	for (FeedGroup *subItem in [item sortedChildren]) {
		[self appendChild:subItem toNode:parent hierarchical:flag];
	}
}


#pragma mark - Helper


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

/// Loop over all subviews and find the @c NSButton that is selected.
+ (NSInteger)radioGroupSelection:(NSView*)view {
	for (NSButton *btn in view.subviews) {
		if ([btn isKindOfClass:[NSButton class]] && btn.state == NSControlStateValueOn) {
			return btn.tag;
		}
	}
	return -1;
}

@end
