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

#import "StoreCoordinator.h"
#import "AppHook.h"
#import <RSXML/RSXML.h>

@implementation StoreCoordinator

+ (NSManagedObjectContext*)getContext {
	return [(AppHook*)NSApp persistentContainer].viewContext;
}

+ (void)saveContext:(NSManagedObjectContext*)context {
	// Performs the save action for the application, which is to send the save: message to the application's managed object context. Any encountered errors are presented to the user.
	if (![context commitEditing]) {
		NSLog(@"%@:%@ unable to commit editing before saving", [self class], NSStringFromSelector(_cmd));
	}
	NSError *error = nil;
	if (context.hasChanges && ![context save:&error]) {
		// Customize this code block to include application-specific recovery steps.
		[[NSApplication sharedApplication] presentError:error];
	}
}

+ (void)deleteUnreferencedFeeds {
	NSManagedObjectContext *moc = [self getContext];
	NSFetchRequest *fr = [NSFetchRequest fetchRequestWithEntityName:Feed.entity.name];
	fr.predicate = [NSPredicate predicateWithFormat:@"config = NULL"];
	NSBatchDeleteRequest *bdr = [[NSBatchDeleteRequest alloc] initWithFetchRequest:fr];
	NSError *err;
	[moc executeRequest:bdr error:&err];
	if (err) NSLog(@"%@", err);
}

+ (NSArray<FeedConfig*>*)sortedFeedConfigItems {
	NSManagedObjectContext *moc = [self getContext];
	NSFetchRequest *fr = [NSFetchRequest fetchRequestWithEntityName: FeedConfig.entity.name];
	fr.predicate = [NSPredicate predicateWithFormat:@"parent = NULL"]; // %@", parent
	fr.sortDescriptors = @[[NSSortDescriptor sortDescriptorWithKey:@"sortIndex" ascending:YES]];
	NSError *err;
	NSArray *result = [moc executeFetchRequest:fr error:&err];
	if (err) NSLog(@"%@", err);
	return result;
}

+ (id)objectWithID:(NSManagedObjectID*)objID {
	return [[self getContext] objectWithID:objID];
}

+ (Feed*)createFeedFrom:(RSParsedFeed*)obj inContext:(NSManagedObjectContext*)context {
	Feed *a = [[Feed alloc] initWithEntity:Feed.entity insertIntoManagedObjectContext:context];
	a.title = obj.title;
	a.subtitle = obj.subtitle;
	a.link = obj.link;
	for (RSParsedArticle *entry in obj.articles) {
		FeedItem *b = [[FeedItem alloc] initWithEntity:FeedItem.entity insertIntoManagedObjectContext:context];
		b.guid = entry.guid;
		b.title = entry.title;
		b.abstract = entry.abstract;
		b.body = entry.body;
		b.author = entry.author;
		b.link = entry.link;
		b.published = entry.datePublished;
		// TODO: remove NSLog()
		if (!entry.datePublished)
			NSLog(@"No date for feed '%@'", obj.urlString);
		[a addItemsObject:b];
	}
	return a;
}

@end
