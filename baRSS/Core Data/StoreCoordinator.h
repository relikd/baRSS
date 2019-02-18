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

#import <Foundation/Foundation.h>
#import "DBv1+CoreDataModel.h"

@interface StoreCoordinator : NSObject
// Managing contexts
+ (NSManagedObjectContext*)createChildContext;
+ (void)saveContext:(NSManagedObjectContext*)context andParent:(BOOL)flag;

// Feed update
+ (NSDate*)nextScheduledUpdate;
+ (NSArray<Feed*>*)getListOfFeedsThatNeedUpdate:(BOOL)forceAll inContext:(NSManagedObjectContext*)moc;

// Count elements
+ (NSUInteger)countTotalUnread;
+ (NSUInteger)countRootItemsInContext:(NSManagedObjectContext*)moc;
+ (NSArray<NSDictionary*>*)countAggregatedUnread;

// Get List Of Elements
+ (NSArray<FeedGroup*>*)sortedFeedGroupsWithParent:(id)parent inContext:(NSManagedObjectContext*)moc;
+ (NSArray<FeedArticle*>*)sortedArticlesWithParent:(id)parent inContext:(NSManagedObjectContext*)moc;
+ (NSArray<Feed*>*)listOfFeedsMissingArticlesInContext:(NSManagedObjectContext*)moc;
+ (NSArray<Feed*>*)listOfFeedsMissingIconsInContext:(NSManagedObjectContext*)moc;
+ (Feed*)feedWithIndexPath:(nonnull NSString*)path inContext:(NSManagedObjectContext*)moc;
+ (NSString*)urlForFeedWithIndexPath:(nonnull NSString*)path;

// Unread articles list & mark articled read
+ (NSArray<FeedArticle*>*)articlesAtPath:(nullable NSString*)path isFeed:(BOOL)feedFlag sorted:(BOOL)sortFlag unread:(BOOL)readFlag inContext:(NSManagedObjectContext*)moc limit:(NSUInteger)limit;

// Restore sound state
+ (void)restoreFeedIndexPaths;
+ (NSUInteger)deleteUnreferenced;
+ (NSUInteger)deleteAllGroups;
@end