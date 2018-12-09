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

#import "FeedGroup+CoreDataClass.h"

@interface FeedGroup (Ext)
/// Enum type to distinguish different @c FeedGroup types: @c GROUP, @c FEED, @c SEPARATOR
typedef enum int16_t {
	/// Other types: @c GROUP, @c FEED, @c SEPARATOR
	GROUP = 0,
	FEED = 1,
	SEPARATOR = 2
} FeedGroupType;

@property (readonly) FeedGroupType typ;

+ (instancetype)newGroup:(FeedGroupType)type inContext:(NSManagedObjectContext*)context;
- (void)setName:(NSString*)name andRefreshString:(NSString*)refreshStr;
// Handle children and parents
- (NSString*)indexPathString;
- (NSMutableArray<FeedGroup*>*)allParents;
- (BOOL)iterateSorted:(BOOL)ordered overDescendantFeeds:(void(^)(Feed *feed, BOOL* cancel))block;
// Printing
- (NSString*)readableDescription;
@end
