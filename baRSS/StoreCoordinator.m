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
#import "Feed+Ext.h"

#import <RSXML/RSXML.h>

@implementation StoreCoordinator

#pragma mark - Managing contexts -

/**
 @return The application main persistent context.
 */
+ (NSManagedObjectContext*)getMainContext {
	return [(AppHook*)NSApp persistentContainer].viewContext;
}

/**
 New child context with @c NSMainQueueConcurrencyType and without undo manager.
 */
+ (NSManagedObjectContext*)createChildContext {
	NSManagedObjectContext *context = [[NSManagedObjectContext alloc] initWithConcurrencyType:NSMainQueueConcurrencyType];
	[context setParentContext:[self getMainContext]];
	context.undoManager = nil;
	//context.automaticallyMergesChangesFromParent = YES;
	return context;
}

/**
 Commit changes and perform save operation on @c context.

 @param flag If @c YES save any parent context (recursive).
 */
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

/**
 List of @c Feed items that need to be updated. Scheduled time is now (or in past).

 @param forceAll If @c YES get a list of all @c Feed regardless of schedules time.
 */
+ (NSArray<Feed*>*)getListOfFeedsThatNeedUpdate:(BOOL)forceAll inContext:(NSManagedObjectContext*)moc {
	NSFetchRequest *fr = [NSFetchRequest fetchRequestWithEntityName: Feed.entity.name];
	if (!forceAll) {
		// when fetching also get those feeds that would need update soon (now + 30s)
		fr.predicate = [NSPredicate predicateWithFormat:@"meta.scheduled <= %@", [NSDate dateWithTimeIntervalSinceNow:+30]];
	}
	NSError *err;
	NSArray *result = [moc executeFetchRequest:fr error:&err];
	if (err) NSLog(@"%@", err);
	return result;
}

/**
 @return @c NSDate of next (earliest) feed update. May be @c nil.
 */
+ (NSDate*)nextScheduledUpdate {
	// Always get context first, or 'FeedMeta.entity.name' may not be available on app start
	NSManagedObjectContext *moc = [self getMainContext];
	NSExpression *exp = [NSExpression expressionForFunction:@"min:"
												  arguments:@[[NSExpression expressionForKeyPath:@"scheduled"]]];
	NSExpressionDescription *expDesc = [[NSExpressionDescription alloc] init];
	[expDesc setName:@"earliestDate"];
	[expDesc setExpression:exp];
	[expDesc setExpressionResultType:NSDateAttributeType];
	
	NSFetchRequest *fr = [NSFetchRequest fetchRequestWithEntityName: FeedMeta.entity.name];
	[fr setResultType:NSDictionaryResultType];
	[fr setPropertiesToFetch:@[expDesc]];
	
	NSError *err;
	NSArray *fetchResults = [moc executeFetchRequest:fr error:&err];
	if (err) NSLog(@"%@", err);
	return fetchResults.firstObject[@"earliestDate"]; // can be nil
}

#pragma mark - Feed Display -

/**
 Perform core data fetch request with sum over all unread feeds matching @c str.

 @param str A dot separated string of integer index parts.
 */
+ (NSInteger)unreadCountForIndexPathString:(NSString*)str {
	// Always get context first, or 'Feed.entity.name' may not be available on app start
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

/**
 Get sorted list of @c ObjectIDs for either @c FeedGroup or @c FeedArticle.

 @param parent Either @c ObjectID or actual object. Or @c nil for root folder.
 @param flag If @c YES request list of @c FeedArticle instead of @c FeedGroup
 */
+ (NSArray*)sortedObjectIDsForParent:(id)parent isFeed:(BOOL)flag inContext:(NSManagedObjectContext*)moc {
//	NSManagedObjectContext *moc = [self getMainContext];
	NSFetchRequest *fr = [NSFetchRequest fetchRequestWithEntityName: (flag ? FeedArticle.entity : FeedGroup.entity).name];
	fr.predicate = [NSPredicate predicateWithFormat:(flag ? @"feed.group = %@" : @"parent = %@"), parent];
	fr.sortDescriptors = @[[NSSortDescriptor sortDescriptorWithKey:@"sortIndex" ascending:!flag]];
	[fr setResultType:NSManagedObjectIDResultType];
	
	NSError *err;
	NSArray *fetchResults = [moc executeFetchRequest:fr error:&err];
	if (err) NSLog(@"%@", err);
	return fetchResults;
}

#pragma mark - Restore Sound State -

/**
 Delete all @c Feed items where @c group @c = @c NULL.
 */
+ (void)deleteUnreferencedFeeds {
	NSManagedObjectContext *moc = [self getMainContext];
	NSFetchRequest *fr = [NSFetchRequest fetchRequestWithEntityName: Feed.entity.name];
	fr.predicate = [NSPredicate predicateWithFormat:@"group = NULL"];
	NSBatchDeleteRequest *bdr = [[NSBatchDeleteRequest alloc] initWithFetchRequest:fr];
	NSError *err;
	[moc executeRequest:bdr error:&err];
	if (err) NSLog(@"%@", err);
}

/**
 Iterate over all @c Feed and re-calculate @c unreadCount, @c articleCount and @c indexPath.
 */
+ (void)restoreFeedCountsAndIndexPaths {
	NSManagedObjectContext *moc = [self getMainContext];
	NSError *err;
	NSArray *result = [moc executeFetchRequest:[NSFetchRequest fetchRequestWithEntityName: Feed.entity.name] error:&err];
	if (err) NSLog(@"%@", err);
	[moc performBlock:^{
		for (Feed *feed in result) {
			int16_t totalCount = (int16_t)feed.articles.count;
			int16_t unreadCount = (int16_t)[[feed.articles valueForKeyPath:@"@sum.unread"] integerValue];
			if (feed.articleCount != totalCount)
				feed.articleCount = totalCount;
			if (feed.unreadCount != unreadCount)
				feed.unreadCount = unreadCount; // remember to update global total unread count
			[feed calculateAndSetIndexPathString];
		}
	}];
}

@end
