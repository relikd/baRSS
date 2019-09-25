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

@import RSXML2;
#import "OpmlFile.h"
#import "FeedMeta+Ext.h"
#import "FeedGroup+Ext.h"
#import "StoreCoordinator.h"
#import "Constants.h"
#import "NSDate+Ext.h"
#import "NSView+Ext.h"
#import "NSError+Ext.h"

#pragma mark - Helper

/// Loop over all subviews and find the @c NSButton that is selected.
static NSInteger RadioGroupSelection(NSView *view) {
	for (NSButton *btn in view.subviews) {
		if ([btn isKindOfClass:[NSButton class]] && btn.state == NSControlStateValueOn) {
			return btn.tag;
		}
	}
	return -1;
}


// ################################################################
// #
// #  OPML Import
// #
// ################################################################
#pragma mark - Import

@implementation OpmlFileImport

+ (instancetype)withDelegate:(id<OpmlFileImportDelegate>)delegate {
	OpmlFileImport *opml = [[super alloc] init];
	opml.delegate = delegate;
	return opml;
}

/// Display Open File Panel to select @c .opml file. Perform web requests (feed data & icon) within a single undo group.
- (void)showImportDialog:(NSWindow*)window {
	NSOpenPanel *op = [NSOpenPanel openPanel];
	op.allowedFileTypes = @[UTI_OPML];
	op.allowsMultipleSelection = YES;
	[op beginSheetModalForWindow:window completionHandler:^(NSModalResponse result) {
		if (result == NSModalResponseOK) {
			[self importFiles:op.URLs];
		}
	}];
}

/// Perform core data import on all items of all @c files
- (void)importFiles:(NSArray<NSURL*>*)files {
	id<OpmlFileImportDelegate> controller = self.delegate;
	BOOL respondBegin = [controller respondsToSelector:@selector(opmlFileImportWillBegin:)];
	BOOL respondEnd = [controller respondsToSelector:@selector(opmlFileImportDidEnd:)];
	
	NSManagedObjectContext *moc = [controller opmlFileImportContext];
	if (respondBegin)
		[controller opmlFileImportWillBegin:moc];
	
	NSUInteger lastIndex = [StoreCoordinator countRootItemsInContext:moc];
	__block NSUInteger current = lastIndex;
	[self enumerateFiles:files withBlock:^(RSOPMLItem *item) {
		[self importFeed:item parent:nil index:(int32_t)current inContext:moc];
		current += 1;
	} finally:(!respondEnd ? nil : ^{ // ignore block if delegate doesn't respond
		[controller opmlFileImportDidEnd:moc];
	})];
}

/// Loop over all files and parse XML data. Calls @c block() for each root @c RSOPMLItem.
- (void)enumerateFiles:(NSArray<NSURL*>*)files withBlock:(void(^)(RSOPMLItem *item))block finally:(nullable dispatch_block_t)finally {
	dispatch_group_t group = dispatch_group_create();
	for (NSURL *url in files) {
		dispatch_group_enter(group);
		NSData *data = [NSData dataWithContentsOfURL:url];
		RSXMLData *xml = [[RSXMLData alloc] initWithData:data url:url];
		RSOPMLParser *parser = [RSOPMLParser parserWithXMLData:xml];
		[parser parseAsync:^(RSOPMLItem * _Nullable doc, NSError * _Nullable error) {
			if (![error inCasePresent:NSApp]) {
				for (RSOPMLItem *itm in doc.children) {
					block(itm);
				}
			}
			dispatch_group_leave(group);
		}];
	}
	if (finally) dispatch_group_notify(group, dispatch_get_main_queue(), finally);
}

/**
 Import single item and recursively repeat import for each child.
 
 @param item The item to be imported.
 @param parent The already processed parent item.
 @param idx @c sortIndex within the @c parent item.
 @param moc Managed object context.
 */
- (void)importFeed:(RSOPMLItem*)item parent:(FeedGroup*)parent index:(int32_t)idx inContext:(NSManagedObjectContext*)moc {
	FeedGroupType type = GROUP;
	if ([item attributeForKey:OPMLXMLURLKey]) {
		type = FEED;
	} else if ([item attributeForKey:@"separator"]) { // baRSS specific
		type = SEPARATOR;
	}
	
	FeedGroup *newFeed = [FeedGroup newGroup:type inContext:moc];
	[newFeed setParent:parent andSortIndex:idx];
	
	if (type == SEPARATOR)
		return;
	
	newFeed.name = item.displayName;
	
	if (type == FEED) {
		id refresh = [item attributeForKey:@"refreshInterval"]; // baRSS specific
		int32_t interval = kDefaultFeedRefreshInterval; // TODO: set -1, then auto
		if (refresh)
			interval = (int32_t)[refresh integerValue];
		
		newFeed.feed.meta.url = [item attributeForKey:OPMLXMLURLKey];
		newFeed.feed.meta.refresh = interval;
	} else { // GROUP
		for (NSUInteger i = 0; i < item.children.count; i++) {
			[self importFeed:item.children[i] parent:newFeed index:(int32_t)i inContext:moc];
		}
	}
}

/**
 Ask user for permission to import new items (prior import). User can choose to append or replace existing items.
 If user chooses to replace existing items, perform core data request to delete all feeds.
 
 @param document Used to count feed items that will be imported
 @return @c -1: User clicked 'Cancel' button. @c 0: Append items. @c 1: Overwrite items.
 */
//- (NSInteger)askToAppendOrOverwriteAlert:(RSOPMLItem*)document inContext:(NSManagedObjectContext*)moc {
//	NSUInteger count = [self recursiveNumberOfFeeds:document];
//	NSAlert *alert = [[NSAlert alloc] init];
//	alert.messageText = [NSString stringWithFormat:NSLocalizedString(@"Import of %lu feed items", nil), count];
//	alert.informativeText = NSLocalizedString(@"Do you want to append or replace existing items?", nil);
//	[alert addButtonWithTitle:NSLocalizedString(@"Import", nil)];
//	[alert addButtonWithTitle:NSLocalizedString(@"Cancel", nil)];
//	alert.accessoryView = [NSView radioGroup:@[NSLocalizedString(@"Append", nil),
//											   NSLocalizedString(@"Overwrite", nil)]];
//
//	if ([alert runModal] == NSAlertFirstButtonReturn) {
//		return RadioGroupSelection(alert.accessoryView);
//	}
//	return -1; // cancel button
//}

/// Count items where @c xmlURL key is set.
//- (NSUInteger)recursiveNumberOfFeeds:(RSOPMLItem*)document {
//	if ([document attributeForKey:OPMLXMLURLKey]) {
//		return 1;
//	} else {
//		NSUInteger sum = 0;
//		for (RSOPMLItem *child in document.children) {
//			sum += [self recursiveNumberOfFeeds:child];
//		}
//		return sum;
//	}
//}

@end


// ################################################################
// #
// #  OPML Export
// #
// ################################################################
#pragma mark - Export

@implementation OpmlFileExport

+ (instancetype)withDelegate:(nullable id<OpmlFileExportDelegate>)delegate {
	OpmlFileExport *opml = [[super alloc] init];
	opml.delegate = delegate;
	return opml;
}

/// Display Save File Panel to select file destination.
- (void)showExportDialog:(NSWindow*)window {
	NSSavePanel *sp = [NSSavePanel savePanel];
	sp.nameFieldStringValue = [NSString stringWithFormat:@"baRSS feeds %@", [NSDate dayStringLocalized]];
	sp.allowedFileTypes = @[UTI_OPML];
	sp.allowsOtherFileTypes = YES;
	NSView *select = [NSView radioGroup:@[NSLocalizedString(@"Everything", nil),
										  NSLocalizedString(@"Selection", nil)]];
	NSView *nested = [NSView radioGroup:@[NSLocalizedString(@"Hierarchical", nil),
										  NSLocalizedString(@"Flattened", nil)]];
	NSView *v1 = [NSView wrapView:select withLabel:NSLocalizedString(@"Export:", nil) padding:PAD_M];
	NSView *v2 = [NSView wrapView:nested withLabel:NSLocalizedString(@"Format:", nil) padding:PAD_M];
	NSView *final = [[NSView alloc] init];
	[v1 placeIn:final x:0 yTop:0];
	[v2 placeIn:final x:NSWidth(v1.frame) + 100 yTop:0];
	[final setFrameSize:NSMakeSize(NSMaxX(v2.frame), NSHeight(v2.frame))];
	sp.accessoryView = final;
	
	[sp beginSheetModalForWindow:window completionHandler:^(NSModalResponse result) {
		if (result == NSModalResponseOK) {
			OpmlFileExportOptions opt = 0;
			if (RadioGroupSelection(select) == 0)
				opt |= OpmlFileExportOptionFullBackup;
			if (RadioGroupSelection(nested) == 1)
				opt |= OpmlFileExportOptionFlattened;
			[self writeOPMLFile:sp.URL withOptions:opt];
		}
	}];
}

/**
 Convert list of @c FeedGroup to @c NSXMLDocument and write to local file @c url.
 On error: show application alert (which is also returned).
 
 @note Calls @c opmlExportListOfFeedGroups: on @c delegate to obtain export list.
 */
- (nullable NSError*)writeOPMLFile:(NSURL*)url withOptions:(OpmlFileExportOptions)opt {
	NSArray<FeedGroup*> *list = [self.delegate opmlFileExportListOfFeedGroups:opt];
	if (!list) list = [StoreCoordinator sortedFeedGroupsWithParent:nil inContext:nil]; // fetch all if delegate == nil
	NSError *error;
	// TODO: set error if nil or empty
	if (list.count > 0) {
		BOOL keepTree = !(opt & OpmlFileExportOptionFlattened);
		NSXMLDocument *doc = [self xmlDocumentForFeeds:list hierarchical:keepTree];
		NSData *xml = [doc XMLDataWithOptions:NSXMLNodePreserveAttributeOrder | NSXMLNodePrettyPrint];
		[xml writeToURL:url options:NSDataWritingAtomic error:&error];
	}
	[error inCasePresent:NSApp];
	return error;
}

/**
 Create NSXMLNode structure with application header nodes and body node containing feed items.
 
 @param flag If @c YES keep parent-child structure intact. If @c NO ignore all parents and add @c Feed items only.
 */
- (NSXMLDocument*)xmlDocumentForFeeds:(NSArray<FeedGroup*>*)list hierarchical:(BOOL)flag {
	NSXMLElement *head = [NSXMLElement elementWithName:@"head"];
	head.children = @[[NSXMLElement elementWithName:@"title" stringValue:@"baRSS feeds"],
					  [NSXMLElement elementWithName:@"ownerName" stringValue:@"baRSS"],
					  [NSXMLElement elementWithName:@"dateCreated" stringValue:[NSDate timeStringISO8601]] ];
	
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
- (void)appendChild:(FeedGroup*)item toNode:(NSXMLElement *)parent hierarchical:(BOOL)flag {
	if (flag || item.type != GROUP) {
		// dont add group node if hierarchical == NO
		NSXMLElement *outline = [NSXMLElement elementWithName:@"outline"];
		[parent addChild:outline];
		[outline addAttribute:[NSXMLNode attributeWithName:OPMLTitleKey stringValue:item.anyName]];
		[outline addAttribute:[NSXMLNode attributeWithName:OPMLTextKey stringValue:item.anyName]];
		
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

@end
