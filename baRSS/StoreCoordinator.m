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

#pragma mark - Managing contexts -

+ (NSManagedObjectContext*)getMainContext {
	return [(AppHook*)NSApp persistentContainer].viewContext;
}

+ (NSManagedObjectContext*)createChildContext {
	NSManagedObjectContext *context = [[NSManagedObjectContext alloc] initWithConcurrencyType:NSMainQueueConcurrencyType];
	[context setParentContext:[self getMainContext]];
	context.undoManager = nil;
	//context.automaticallyMergesChangesFromParent = YES;
	return context;
}

+ (void)saveContext:(NSManagedObjectContext*)context andParent:(BOOL)flag {
	// Performs the save action for the application, which is to send the save: message to the application's managed object context. Any encountered errors are presented to the user.
	if (![context commitEditing]) {
		NSLog(@"%@:%@ unable to commit editing before saving", [self class], NSStringFromSelector(_cmd));
	}
	NSError *error = nil;
	if (context.hasChanges && ![context save:&error]) {
		// Customize this code block to include application-specific recovery steps.
		[[NSApplication sharedApplication] presentError:error];
	}
	if (flag && context.parentContext) {
		[self saveContext:context.parentContext andParent:flag];
	}
}

#pragma mark - Feed Update -

+ (NSArray<FeedConfig*>*)getListOfFeedsThatNeedUpdate:(BOOL)forceAll inContext:(NSManagedObjectContext*)moc {
	// TODO: Get Feed instead of FeedConfig
	NSFetchRequest *fr = [NSFetchRequest fetchRequestWithEntityName: FeedConfig.entity.name];
	if (!forceAll) {
		// when fetching also get those feeds that would need update soon (now + 30s)
		fr.predicate = [NSPredicate predicateWithFormat:@"type = %d AND scheduled <= %@", FEED, [NSDate dateWithTimeIntervalSinceNow:+30]];
	} else {
		fr.predicate = [NSPredicate predicateWithFormat:@"type = %d", FEED];
	}
	NSError *err;
	NSArray *result = [moc executeFetchRequest:fr error:&err];
	if (err) NSLog(@"%@", err);
	return result;
}

+ (NSDate*)nextScheduledUpdate {
	// Always get context first, or 'FeedConfig.entity.name' may not be available on app start
	NSManagedObjectContext *moc = [self getMainContext];
	NSExpression *exp = [NSExpression expressionForFunction:@"min:"
												  arguments:@[[NSExpression expressionForKeyPath:@"scheduled"]]];
	NSExpressionDescription *expDesc = [[NSExpressionDescription alloc] init];
	[expDesc setName:@"earliestDate"];
	[expDesc setExpression:exp];
	[expDesc setExpressionResultType:NSDateAttributeType];
	
	NSFetchRequest *fr = [NSFetchRequest fetchRequestWithEntityName: FeedConfig.entity.name];
	fr.predicate = [NSPredicate predicateWithFormat:@"type = %d", FEED];
	[fr setResultType:NSDictionaryResultType];
	[fr setPropertiesToFetch:@[expDesc]];
	
	NSError *err;
	NSArray *fetchResults = [moc executeFetchRequest:fr error:&err];
	if (err) NSLog(@"%@", err);
	return fetchResults.firstObject[@"earliestDate"]; // can be nil
}

#pragma mark - Feed Display -

+ (NSInteger)unreadCountForIndexPathString:(NSString*)str {
	// Always get context first, or 'FeedConfig.entity.name' may not be available on app start
	NSManagedObjectContext *moc = [self getMainContext];
	NSExpression *exp = [NSExpression expressionForFunction:@"sum:"
												  arguments:@[[NSExpression expressionForKeyPath:@"unreadCount"]]];
	NSExpressionDescription *expDesc = [[NSExpressionDescription alloc] init];
	[expDesc setName:@"totalUnread"];
	[expDesc setExpression:exp];
	[expDesc setExpressionResultType:NSInteger32AttributeType];
	
	NSFetchRequest *fr = [NSFetchRequest fetchRequestWithEntityName: Feed.entity.name];
	if (str && str.length > 0)
		fr.predicate = [NSPredicate predicateWithFormat:@"indexPath BEGINSWITH %@", str];
	[fr setResultType:NSDictionaryResultType];
	[fr setPropertiesToFetch:@[expDesc]];
	
	NSError *err;
	NSArray *fetchResults = [moc executeFetchRequest:fr error:&err];
	if (err) NSLog(@"%@", err);
	return [fetchResults.firstObject[@"totalUnread"] integerValue];
}

+ (NSArray*)sortedObjectIDsForParent:(id)parent isFeed:(BOOL)flag inContext:(NSManagedObjectContext*)moc {
//	NSManagedObjectContext *moc = [self getMainContext];
	NSFetchRequest *fr = [NSFetchRequest fetchRequestWithEntityName: (flag ? FeedItem.entity : FeedConfig.entity).name];
	fr.predicate = [NSPredicate predicateWithFormat:(flag ? @"feed.config = %@" : @"parent = %@"), parent];
	fr.sortDescriptors = @[[NSSortDescriptor sortDescriptorWithKey:@"sortIndex" ascending:!flag]];
	[fr setResultType:NSManagedObjectIDResultType];
	
	NSError *err;
	NSArray *fetchResults = [moc executeFetchRequest:fr error:&err];
	if (err) NSLog(@"%@", err);
	return fetchResults;
}

//+ (void)addToSortIndex:(int)num start:(int)index parent:(FeedConfig*)config inContext:(NSManagedObjectContext*)moc {
//	NSBatchUpdateRequest *ur = [[NSBatchUpdateRequest alloc] initWithEntityName: FeedConfig.entity.name];
//	ur.predicate = [NSPredicate predicateWithFormat:@"parent = %@ AND sortIndex >= %d", config, index];
//	ur.propertiesToUpdate = @{@"sortIndex": [NSExpression expressionWithFormat: @"sortIndex + %d", num]};
//	ur.resultType = NSUpdatedObjectsCountResultType;//NSUpdatedObjectIDsResultType;//NSStatusOnlyResultType;
//	NSError *err;
//	NSBatchUpdateResult *result = [moc executeRequest:ur error:&err];
//	if (err) NSLog(@"%@", err);
//	NSLog(@"Result: %@", result.result);
//	//[NSManagedObjectContext mergeChangesFromRemoteContextSave:@{NSUpdatedObjectsKey : result.result} intoContexts:@[moc]];
//}

#pragma mark - Restore Sound State -

+ (void)deleteUnreferencedFeeds {
	NSManagedObjectContext *moc = [self getMainContext];
	NSFetchRequest *fr = [NSFetchRequest fetchRequestWithEntityName:Feed.entity.name];
	fr.predicate = [NSPredicate predicateWithFormat:@"config = NULL"];
	NSBatchDeleteRequest *bdr = [[NSBatchDeleteRequest alloc] initWithFetchRequest:fr];
	NSError *err;
	[moc executeRequest:bdr error:&err];
	if (err) NSLog(@"%@", err);
}

+ (void)restoreFeedCountsAndIndexPaths {
	NSManagedObjectContext *moc = [self getMainContext];
	NSError *err;
	NSArray *result = [moc executeFetchRequest:[NSFetchRequest fetchRequestWithEntityName: Feed.entity.name] error:&err];
	if (err) NSLog(@"%@", err);
	[moc performBlock:^{
		for (Feed *feed in result) {
			int16_t totalCount = (int16_t)feed.items.count;
			int16_t unreadCount = (int16_t)[[feed.items valueForKeyPath:@"@sum.unread"] integerValue];
			if (feed.articleCount != totalCount)
				feed.articleCount = totalCount;
			if (feed.unreadCount != unreadCount)
				feed.unreadCount = unreadCount; // remember to update global total unread count
			
			NSString *pathStr = [feed.config indexPathString];
			if (![feed.indexPath isEqualToString:pathStr])
				feed.indexPath = pathStr;
		}
	}];
}

@end
