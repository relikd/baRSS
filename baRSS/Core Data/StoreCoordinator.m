#import "StoreCoordinator.h"
#import "AppHook.h"
#import "Constants.h"
#import "FaviconDownload.h"
#import "UserPrefs.h"
#import "Feed+Ext.h"
#import "NSURL+Ext.h"
#import "NSError+Ext.h"
#import "NSFetchRequest+Ext.h"

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
	if (![context commitEditing])
		NSLogCaller(@"unable to commit editing before saving");
	NSError *error = nil;
	if (context.hasChanges && ![context save:&error])
		[error inCasePresent:NSApp];
	if (flag && context.parentContext)
		[self saveContext:context.parentContext andParent:flag];
}


#pragma mark - Options


/// @return Value for option with @c key or @c nil.
+ (nullable NSString*)optionForKey:(NSString*)key {
	return [[[Options fetchRequest] where:@"key = %@", key] fetchFirst:[self getMainContext]].value;
}

/// Init new option with given @c key
+ (void)setOption:(NSString*)key value:(NSString*)value {
	NSManagedObjectContext *moc = [self getMainContext];
	Options *opt = [[[Options fetchRequest] where:@"key = %@", key] fetchFirst:moc];
	if (!opt) {
		opt = [[Options alloc] initWithEntity:Options.entity insertIntoManagedObjectContext:moc];
		opt.key = key;
	}
	if (opt.value != value) {
		opt.value = value;
	}
	[self saveContext:moc andParent:YES];
	[moc reset];
}


#pragma mark - Feed Update

/// @return @c NSDate of next (earliest) feed update. May be @c nil.
+ (NSDate*)nextScheduledUpdate {
	NSFetchRequest *fr = [FeedMeta fetchRequest];
	[fr addFunctionExpression:@"min:" onKeyPath:@"scheduled" name:@"minDate" type:NSDateAttributeType];
	return [fr fetchFirstDict: [self getMainContext]][@"minDate"];
}

/**
 List of @c Feed items that need to be updated. Scheduled time is now (or in past).

 @param forceAll If @c YES get a list of all @c Feed regardless of schedules time.
 @param moc If @c nil perform requests on main context (ok for reading).
 */
+ (NSArray<Feed*>*)listOfFeedsThatNeedUpdate:(BOOL)forceAll inContext:(nullable NSManagedObjectContext*)moc {
	NSFetchRequest *fr = [Feed fetchRequest];
	if (!forceAll) {
		// when fetching also get those feeds that would need update soon (now + 2s)
		[fr where:@"meta.scheduled <= %@", [NSDate dateWithTimeIntervalSinceNow:+2]];
	}
	return [fr fetchAllRows:moc ? moc : [self getMainContext]];
}


#pragma mark - Count Elements

/// @return @c YES if core data has no stored @c FeedGroup
+ (BOOL)isEmpty {
	return [[FeedGroup fetchRequest] fetchFirst:[self getMainContext]] == nil;
}

/// @return Sum of all unread @c FeedArticle items.
+ (NSUInteger)countTotalUnread {
	return [[[FeedArticle fetchRequest] where:@"unread = YES"] fetchCount: [self getMainContext]];
}

/// @return Count of objects at root level. Aka @c sortIndex for the next @c FeedGroup item.
+ (NSUInteger)countRootItemsInContext:(NSManagedObjectContext*)moc {
	return [[[FeedGroup fetchRequest] where:@"parent = NULL"] fetchCount:moc];
}

/// @return Unread and total count grouped by @c Feed item.
+ (NSArray<NSDictionary*>*)countAggregatedUnread {
	NSFetchRequest *fr = [Feed fetchRequest];
	fr.propertiesToGroupBy = @[ @"indexPath" ];
	fr.propertiesToFetch = @[ @"indexPath" ];
	[fr addFunctionExpression:@"sum:" onKeyPath:@"articles.unread" name:@"unread" type:NSInteger32AttributeType];
	[fr addFunctionExpression:@"count:" onKeyPath:@"articles.unread" name:@"total" type:NSInteger32AttributeType];
	return (NSArray<NSDictionary*>*)[fr fetchAllRows: [self getMainContext]];
}


#pragma mark - Get List Of Elements

/**
 @param moc If @c nil perform requests on main context (ok for reading).
 @return Sorted list of @c FeedGroup items where @c FeedGroup.parent @c = @c parent.
 */
+ (NSArray<FeedGroup*>*)sortedFeedGroupsWithParent:(nullable id)parent inContext:(nullable NSManagedObjectContext*)moc {
	return [[[[FeedGroup fetchRequest] where:@"parent = %@", parent] sortASC:@"sortIndex"] fetchAllRows:moc ? moc : [self getMainContext]];
}

/// @return Sorted list of @c FeedArticle items where @c FeedArticle.feed @c = @c parent.
//+ (NSArray<FeedArticle*>*)sortedArticlesWithParent:(id)parent inContext:(NSManagedObjectContext*)moc {
//	return [[[[FeedArticle fetchRequest] where:@"feed = %@", parent] sortDESC:@"sortIndex"] fetchAllRows:moc];
//}

/// @return Unsorted list of @c Feed items where @c articles.count @c == @c 0.
//+ (NSArray<Feed*>*)listOfFeedsMissingArticlesInContext:(NSManagedObjectContext*)moc {
//	return [[[Feed fetchRequest] where:@"articles.@count == 0"] fetchAllRows:moc];
//}

/**
 @param moc If @c nil perform requests on main context (ok for reading).
 @return Single @c Feed item where @c Feed.indexPath @c = @c path.
 */
+ (Feed*)feedWithIndexPath:(nonnull NSString*)path inContext:(nullable NSManagedObjectContext*)moc {
	return [[[Feed fetchRequest] where:@"indexPath = %@", path] fetchFirst:moc ? moc : [self getMainContext]];
}

/// @return URL of @c Feed item where @c Feed.indexPath @c = @c path.
+ (NSString*)urlForFeedWithIndexPath:(nonnull NSString*)path {
	return [[[[Feed fetchRequest] where:@"indexPath = %@", path] select:@[@"link"]] fetchFirstDict: [self getMainContext]][@"link"];
}

/// @return Unsorted list of object IDs where @c Feed.indexPath begins with @c path @c + @c "."
+ (NSArray<NSManagedObjectID*>*)feedIDsForIndexPath:(nonnull NSString*)path inContext:(NSManagedObjectContext*)moc {
	return [[[Feed fetchRequest] where:@"indexPath BEGINSWITH %@", [path stringByAppendingString:@"."]] fetchIDs:moc];
}


#pragma mark - Unread Articles List & Mark Read

/// @return Return predicate that will match either exactly one, @b or a list of, @b or all @c Feed items.
+ (nullable NSPredicate*)predicateWithPath:(nullable NSString*)path isFeed:(BOOL)flag inContext:(NSManagedObjectContext*)moc {
	if (!path) return nil; // match all
	if (flag) {
		Feed *obj = [self feedWithIndexPath:path inContext:moc];
		return [NSPredicate predicateWithFormat:@"feed = %@", obj.objectID];
	}
	NSArray *list = [self feedIDsForIndexPath:path inContext:moc];
	if (list && list.count > 0) {
		return [NSPredicate predicateWithFormat:@"feed IN %@", list];
	}
	return [NSPredicate predicateWithValue:NO]; // match none
}

/**
 Return object list with @c FeedArticle where @c unread @c = @c YES. In the same order the user provided.

 @param path Match @c Feed items where @c indexPath string matches @c path.
 @param feedFlag If @c YES path must match exactly. If @c NO match items that begin with @c path + @c "."
 @param sortFlag Whether articles should be returned in sorted order (e.g., for 'open all unread').
 @param readFlag Match @c FeedArticle where @c unread @c = @c readFlag.
 @param limit Only return first @c X articles that match the criteria.
 @return Sorted list of @c FeedArticle with @c unread @c = @c YES.
 */
+ (NSArray<FeedArticle*>*)articlesAtPath:(nullable NSString*)path isFeed:(BOOL)feedFlag sorted:(BOOL)sortFlag unread:(BOOL)readFlag inContext:(NSManagedObjectContext*)moc limit:(NSUInteger)limit {
	NSFetchRequest<FeedArticle*> *fr = [[FeedArticle fetchRequest] where:@"unread = %d", readFlag];
	fr.fetchLimit = limit;
	if (sortFlag) {
		if (!path || !feedFlag)
			[fr sortASC:@"feed.indexPath"];
		[fr sortDESC:@"sortIndex"];
	}
	/* UNUSED. Batch updates will break NSUndoManager in preferences. Fix that before usage.
	 NSBatchUpdateRequest *bur = [NSBatchUpdateRequest batchUpdateRequestWithEntityName: FeedArticle.entity.name];
	 bur.propertiesToUpdate = @{ @"unread": @(!readFlag) };
	 bur.resultType = NSUpdatedObjectIDsResultType;
	 bur.predicate = [NSPredicate predicateWithFormat:@"unread = %d", readFlag];*/
	NSPredicate *feedFilter = [self predicateWithPath:path isFeed:feedFlag inContext:moc];
	if (feedFilter)
		fr.predicate = [NSCompoundPredicate andPredicateWithSubpredicates:@[fr.predicate, feedFilter]];
	return [fr fetchAllRows:moc];
}

/**
 For provided articles, pen link, mark read, and save changes.
 @warning Will invalidate context.
 
 @param list Should only contain @c FeedArticle
 @param markRead Whether the articles should be marked read or unread.
 @param openLinks Whether to open the link or mark read without opening
 */
+ (void)updateArticles:(NSArray<FeedArticle*>*)list markRead:(BOOL)markRead andOpen:(BOOL)openLinks inContext:(NSManagedObjectContext*)moc {
	BOOL success = NO;
	if (openLinks) {
		NSMutableArray<NSURL*> *urls = [NSMutableArray arrayWithCapacity:list.count];
		for (FeedArticle *fa in list) {
			if (fa.link.length > 0)
				[urls addObject:[NSURL URLWithString:fa.link]];
		}
		if (urls.count > 0)
			success = UserPrefsOpenURLs(urls);
	}
	// if success == NO, do not modify unread state
	if (!openLinks || success) {
		for (FeedArticle *fa in list) {
			fa.unread = !markRead;
		}
		[self saveContext:moc andParent:YES];
		[moc reset];
		NSNumber *num = [NSNumber numberWithInteger: (markRead ? -1 : +1) * (NSInteger)list.count ];
		PostNotification(kNotificationTotalUnreadCountChanged, num);
	}
}


#pragma mark - Restore Sound State

/// Remove orphan core data entries with optional alert message of removed items count.
+ (void)cleanupAndShowAlert:(BOOL)flag {
	NSUInteger deleted = [self deleteUnreferenced];
	[self restoreFeedIndexPaths];
	PostNotification(kNotificationTotalUnreadCountReset, nil);
	if (flag) {
		NSAlert *alert = [[NSAlert alloc] init];
		alert.messageText = NSLocalizedString(@"Database cleanup successful", nil);
		alert.informativeText = [NSString stringWithFormat:NSLocalizedString(@"Removed %lu unreferenced database entries.", nil), deleted];
		alert.alertStyle = NSAlertStyleInformational;
		[alert runModal];
	}
}

/// Iterate over all @c Feed and re-calculate @c indexPath.
+ (void)restoreFeedIndexPaths {
	NSManagedObjectContext *moc = [self getMainContext];
	for (Feed *f in [[Feed fetchRequest] fetchAllRows:moc]) {
		[f calculateAndSetIndexPathString];
	}
	[self saveContext:moc andParent:YES];
	[moc reset];
}

/**
 Delete all @c Feed items where @c group @c = @c NULL and all @c FeedMeta, @c FeedIcon, @c FeedArticle where @c feed @c = @c NULL.
 */
+ (NSUInteger)deleteUnreferenced {
	NSUInteger deleted = 0;
	NSManagedObjectContext *moc = [self getMainContext];
	deleted += [self batchDelete:Feed.entity nullAttribute:@"group" inContext:moc];
	deleted += [self batchDelete:FeedMeta.entity nullAttribute:@"feed" inContext:moc];
	deleted += [self batchDelete:FeedArticle.entity nullAttribute:@"feed" inContext:moc];
	if (deleted > 0) {
		[self saveContext:moc andParent:YES];
		[moc reset];
	}
	return deleted;
}

/// Delete all @c FeedGroup items.
//+ (NSUInteger)deleteAllGroups {
//	NSManagedObjectContext *moc = [self getMainContext];
//	NSUInteger deleted = [self batchDelete:FeedGroup.entity nullAttribute:nil inContext:moc];
//	[self saveContext:moc andParent:YES];
//	[moc reset];
//	return deleted;
//}

/**
 Perform batch delete on entities of type @c entity where @c column @c IS @c NULL. If @c column is @c nil, delete all rows.
 */
+ (NSUInteger)batchDelete:(NSEntityDescription*)entity nullAttribute:(NSString*)column inContext:(NSManagedObjectContext*)moc {
	NSFetchRequest *fr = [NSFetchRequest fetchRequestWithEntityName: entity.name];
	if (column && column.length > 0) {
		// using @count here to also find items where foreign key is set but referencing a non-existing object.
		fr.predicate = [NSPredicate predicateWithFormat:@"count(%K) == 0", column];
	}
	NSBatchDeleteRequest *bdr = [[NSBatchDeleteRequest alloc] initWithFetchRequest:fr];
	bdr.resultType = NSBatchDeleteResultTypeCount;
	NSError *err;
	NSBatchDeleteResult *res = [moc executeRequest:bdr error:&err];
	[err inCaseLog:"Couldn't delete batch"];
	return [res.result unsignedIntegerValue];
}

/// Remove orphan favicons. @return Number of removed items.
+ (NSUInteger)cleanupFavicons {
	NSURL *base = [[NSURL faviconsCacheURL] URLByResolvingSymlinksInPath];
	if (![base existsAndIsDir:YES]) return 0;
	
	NSFileManager *fm = [NSFileManager defaultManager];
	NSDirectoryEnumerationOptions opt = NSDirectoryEnumerationSkipsSubdirectoryDescendants | NSDirectoryEnumerationSkipsPackageDescendants | NSDirectoryEnumerationSkipsHiddenFiles;
	NSDirectoryEnumerator *enumerator = [fm enumeratorAtURL:base includingPropertiesForKeys:nil options:opt errorHandler:nil];
	NSMutableArray<NSURL*> *toBeDeleted = [NSMutableArray array];
	
	NSArray<NSManagedObjectID*> *feedIds = [[Feed fetchRequest] fetchIDs:[self getMainContext]];
	NSArray<NSString*> *pks = [feedIds valueForKeyPath:@"URIRepresentation.lastPathComponent"];
	
	for (NSURL *path in enumerator)
		if (![pks containsObject:path.lastPathComponent])
			[toBeDeleted addObject:path];
	for (NSURL *path in toBeDeleted)
		[fm removeItemAtURL:path error:nil];
	return toBeDeleted.count;
}

@end
