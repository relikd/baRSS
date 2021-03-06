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

@import Cocoa;
#import "FeedGroup+CoreDataClass.h"

/// Enum type to distinguish different @c FeedGroup types: @c GROUP, @c FEED, @c SEPARATOR
typedef NS_ENUM(int16_t, FeedGroupType) {
	/// Other types: @c GROUP, @c FEED, @c SEPARATOR
	GROUP = 0, FEED = 1, SEPARATOR = 2
};

NS_ASSUME_NONNULL_BEGIN

@interface FeedGroup (Ext)
/// Overwrites @c type attribute with enum. Use one of: @c GROUP, @c FEED, @c SEPARATOR.
@property (nonatomic) FeedGroupType type;
@property (nonnull, readonly) NSString *anyName;
@property (nonnull, readonly) NSImage* groupIconImage16;
@property (nonnull, readonly) NSImage* iconImage16;

+ (instancetype)newGroup:(FeedGroupType)type inContext:(NSManagedObjectContext*)context;
+ (instancetype)appendToRoot:(FeedGroupType)type inContext:(NSManagedObjectContext*)moc;
- (void)setParent:(nullable FeedGroup *)parent andSortIndex:(int32_t)sortIndex;
- (void)setSortIndexIfChanged:(int32_t)sortIndex;
- (void)setNameIfChanged:(nullable NSString*)name;
- (NSMenuItem*)newMenuItem;
// Handle children and parents
- (NSString*)indexPathString;
- (NSArray<FeedGroup*>*)sortedChildren;
- (NSMutableArray<FeedGroup*>*)allParents;
// Printing
- (NSString*)readableDescription;
@end

NS_ASSUME_NONNULL_END
