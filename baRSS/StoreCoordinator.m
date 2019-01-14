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

#pragma mark - Managing contexts

/// @return The application main persistent context.
+ (NSManagedObjectContext*)getMainContext {
	return [(AppHook*)NSApp persistentContainer].viewContext;
}

/// New child context with @c NSMainQueueConcurrencyType and without undo manager.
+ (NSManagedObjectContext*)createChildContext {
	NSManagedObjectContext *context = [[NSManagedObjectContext alloc] initWithConcurrencyType:NSMainQueueConcurrencyType];
	[context setParentContext:[self getMainContext]];
	context.undoManager = nil;
	//context.automaticallyMergesChangesFromParent = YES;
	return context;
}

/**
 Commit changes and perform save operation on @c context.

 @param flag If @c YES save any parent context as well (recursive).
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


#pragma mark - Helper

/// Perform fetch and return result. If an error occurs, print it to the console.
+ (NSArray*)fetchAllRows:(NSFetchRequest*)req inContext:(NSManagedObjectContext*)moc {
	NSError *err;
	NSArray *fetchResults = [moc executeFetchRequest:req error:&err];
	if (err) NSLog(@"ERROR: Fetch request failed: %@", err);
	//NSLog(@"%@ ==> %@", req, fetchResults); // debugging
	return fetchResults;
}

/// Perform aggregated fetch where result is a single row. Use convenient methods @c fetchDate: or @c fetchInteger:.
+ (id)fetchSingleRow:(NSManagedObjectContext*)moc request:(NSFetchRequest*)req expression:(NSExpression*)exp resultType:(NSAttributeType)type {
	NSExpressionDescription *expDesc = [[NSExpressionDescription alloc] init];
	[expDesc setName:@"singleRowAttribute"];
	[expDesc setExpression:exp];
	[expDesc setExpressionResultType:type];
	[req setResultType:NSDictionaryResultType];
	[req setPropertiesToFetch:@[expDesc]];
	return [self fetchAllRows:req inContext:moc].firstObject[@"singleRowAttribute"];
}

/// Convenient method on @c fetchSingleRow: with @c NSDate return type. May be @c nil.
+ (NSDate*)fetchDate:(NSManagedObjectContext*)moc request:(NSFetchRequest*)req expression:(NSExpression*)exp {
	return [self fetchSingleRow:moc request:req expression:exp resultType:NSDateAttributeType]; // can be nil
}

/// Convenient method on @c fetchSingleRow: with @c NSInteger return type.
+ (NSInteger)fetchInteger:(NSManagedObjectContext*)moc request:(NSFetchRequest*)req expression:(NSExpression*)exp {
	return [[self fetchSingleRow:moc request:req expression:exp resultType:NSInteger32AttributeType] integerValue];
}


#pragma mark - Feed Update

/**
 List of @c Feed items that need to be updated. Scheduled time is now (or in past).

 @param forceAll If @c YES get a list of all @c Feed regardless of schedules time.
 */
+ (NSArray<Feed*>*)getListOfFeedsThatNeedUpdate:(BOOL)forceAll inContext:(NSManagedObjectContext*)moc {
	NSFetchRequest *fr = [NSFetchRequest fetchRequestWithEntityName: Feed.entity.name];
	if (!forceAll) {
		// when fetching also get those feeds that would need update soon (now + 10s)
		fr.predicate = [NSPredicate predicateWithFormat:@"meta.scheduled <= %@", [NSDate dateWithTimeIntervalSinceNow:+10]];
	}
	return [self fetchAllRows:fr inContext:moc];
}

/// @return @c NSDate of next (earliest) feed update. May be @c nil.
+ (NSDate*)nextScheduledUpdate {
	// Always get context first, or 'FeedMeta.entity.name' may not be available on app start
	NSManagedObjectContext *moc = [self getMainContext];
	NSExpression *exp = [NSExpression expressionForFunction:@"min:" arguments:@[[NSExpression expressionForKeyPath:@"scheduled"]]];
	NSFetchRequest *fr = [NSFetchRequest fetchRequestWithEntityName: FeedMeta.entity.name];
	return [self fetchDate:moc request:fr expression:exp];
}


#pragma mark - Main Menu Display

/**
 Perform core data fetch request with sum over all unread feeds matching @c str.

 @param str A dot separated string of integer index parts.
 */
+ (NSInteger)unreadCountForIndexPathString:(NSString*)str {
	// Always get context first, or 'Feed.entity.name' may not be available on app start
	NSManagedObjectContext *moc = [self getMainContext];
	NSExpression *exp = [NSExpression expressionForFunction:@"sum:" arguments:@[[NSExpression expressionForKeyPath:@"unreadCount"]]];
	NSFetchRequest *fr = [NSFetchRequest fetchRequestWithEntityName: Feed.entity.name];
	if (str && str.length > 0)
		fr.predicate = [NSPredicate predicateWithFormat:@"indexPath BEGINSWITH %@", str];
	return [self fetchInteger:moc request:fr expression:exp];
}

/**
 Get sorted list of @c ObjectIDs for either @c FeedGroup or @c FeedArticle.

 @param parent Either @c ObjectID or actual object. Or @c nil for root folder.
 @param flag If @c YES request list of @c FeedArticle instead of @c FeedGroup
 */
+ (NSArray*)sortedObjectIDsForParent:(id)parent isFeed:(BOOL)flag inContext:(NSManagedObjectContext*)moc {
	NSFetchRequest *fr = [NSFetchRequest fetchRequestWithEntityName: (flag ? FeedArticle.entity : FeedGroup.entity).name];
	fr.predicate = [NSPredicate predicateWithFormat:(flag ? @"feed.group = %@" : @"parent = %@"), parent];
	fr.sortDescriptors = @[[NSSortDescriptor sortDescriptorWithKey:@"sortIndex" ascending:!flag]];
	[fr setResultType:NSManagedObjectIDResultType]; // only get ids
	return [self fetchAllRows:fr inContext:moc];
}


#pragma mark - OPML Import & Export

/// @return Count of objects at root level. Also the @c sortIndex for the next item.
+ (NSInteger)numberRootItemsInContext:(NSManagedObjectContext*)moc {
	NSExpression *exp = [NSExpression expressionForFunction:@"count:" arguments:@[[NSExpression expressionForEvaluatedObject]]];
	NSFetchRequest *fr = [NSFetchRequest fetchRequestWithEntityName: FeedGroup.entity.name];
	fr.predicate = [NSPredicate predicateWithFormat:@"parent = NULL"];
	return [self fetchInteger:moc request:fr expression:exp];
}

/// @return Sorted list of root element objects.
+ (NSArray<FeedGroup*>*)sortedListOfRootObjectsInContext:(NSManagedObjectContext*)moc {
	NSFetchRequest *fr = [NSFetchRequest fetchRequestWithEntityName: FeedGroup.entity.name];
	fr.predicate = [NSPredicate predicateWithFormat:@"parent = NULL"];
	fr.sortDescriptors = @[[NSSortDescriptor sortDescriptorWithKey:@"sortIndex" ascending:YES]];
	return [self fetchAllRows:fr inContext:moc];
}


#pragma mark - Restore Sound State

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
	NSArray *result = [self fetchAllRows:[NSFetchRequest fetchRequestWithEntityName: Feed.entity.name] inContext:moc];
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

/// @return All @c Feed items where @c articles.count @c == @c 0
+ (NSArray<Feed*>*)listOfMissingFeedsInContext:(NSManagedObjectContext*)moc {
	NSFetchRequest *fr = [NSFetchRequest fetchRequestWithEntityName: Feed.entity.name];
	// More accurate but with subquery on FeedArticle: "count(articles) == 0"
	fr.predicate = [NSPredicate predicateWithFormat:@"articleCount == 0"];
	return [self fetchAllRows:fr inContext:moc];
}

@end
