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

+ (NSArray<FeedConfig*>*)getListOfFeedsThatNeedUpdate:(BOOL)forceAll {
	NSManagedObjectContext *moc = [self getContext];
	NSFetchRequest *fr = [NSFetchRequest fetchRequestWithEntityName: FeedConfig.entity.name];
	if (!forceAll) {
		fr.predicate = [NSPredicate predicateWithFormat:@"type = %d AND scheduled <= %@", FEED, [NSDate date]];
	} else {
		fr.predicate = [NSPredicate predicateWithFormat:@"type = %d", FEED];
	}
	NSError *err;
	NSArray *result = [moc executeFetchRequest:fr error:&err];
	if (err) NSLog(@"%@", err);
	return result;
}

+ (NSDate*)nextScheduledUpdate {
	NSExpression *exp = [NSExpression expressionForFunction:@"min:" arguments:@[[NSExpression expressionForKeyPath:@"scheduled"]]];
	NSExpressionDescription *expDesc = [[NSExpressionDescription alloc] init];
	[expDesc setName:@"earliestDate"];
	[expDesc setExpression:exp];
	[expDesc setExpressionResultType:NSDateAttributeType];
	
	NSFetchRequest *fr = [NSFetchRequest fetchRequestWithEntityName: FeedConfig.entity.name];
	fr.predicate = [NSPredicate predicateWithFormat:@"type = %d", FEED];
	[fr setResultType:NSDictionaryResultType];
	[fr setPropertiesToFetch:@[expDesc]];
	
	NSError *err;
	NSArray *fetchResults = [[self getContext] executeFetchRequest:fr error:&err];
	if (err) NSLog(@"%@", err);
	return [fetchResults firstObject][@"earliestDate"]; // can be nil
}

+ (id)objectWithID:(NSManagedObjectID*)objID {
	return [[self getContext] objectWithID:objID];
}


+ (void)overwriteConfig:(FeedConfig*)config withFeed:(RSParsedFeed*)obj {
	NSArray<NSString*> *readURLs = [self alreadyReadURLsInFeed:config.feed];
	[config.managedObjectContext performBlockAndWait:^{
		if (config.feed)
			[config.managedObjectContext deleteObject:(NSManagedObject*)config.feed];
		if (obj) {
			config.feed = [StoreCoordinator createFeedFrom:obj inContext:config.managedObjectContext alreadyRead:readURLs];
		}
	}];
}

#pragma mark - Helper methods -

+ (FeedItem*)createFeedItemFrom:(RSParsedArticle*)entry inContext:(NSManagedObjectContext*)context {
	FeedItem *b = [[FeedItem alloc] initWithEntity:FeedItem.entity insertIntoManagedObjectContext:context];
	b.guid = entry.guid;
	b.title = entry.title;
	b.abstract = entry.abstract;
	b.body = entry.body;
	b.author = entry.author;
	b.link = entry.link;
	b.published = entry.datePublished;
	return b;
}

+ (Feed*)createFeedFrom:(RSParsedFeed*)obj inContext:(NSManagedObjectContext*)context alreadyRead:(NSArray<NSString*>*)urls {
	Feed *a = [[Feed alloc] initWithEntity:Feed.entity insertIntoManagedObjectContext:context];
	a.title = obj.title;
	a.subtitle = obj.subtitle;
	a.link = obj.link;
	for (RSParsedArticle *article in obj.articles) {
		FeedItem *b = [self createFeedItemFrom:article inContext:context];
		if ([urls containsObject:b.link]) {
			b.unread = NO;
		}
		[a addItemsObject:b];
	}
	return a;
}

+ (NSArray<NSString*>*)alreadyReadURLsInFeed:(Feed*)local {
	if (!local || !local.items) return nil;
	NSMutableArray<NSString*> *mArr = [NSMutableArray arrayWithCapacity:local.items.count];
	for (FeedItem *f in local.items) {
		if (!f.unread) {
			[mArr addObject:f.link];
		}
	}
	return mArr;
}

@end
