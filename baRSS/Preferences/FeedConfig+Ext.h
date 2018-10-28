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

#import "FeedConfig+CoreDataClass.h"

@class FeedItem;

@interface FeedConfig (Ext)
/// Enum type to distinguish different @c FeedConfig types
typedef enum int16_t {
	GROUP = 0,
	FEED = 1,
	SEPARATOR = 2
} FeedConfigType;
/**
 Iteration block for descendants of @c FeedItem.

 @param parent The parent @c FeedConfig where this @c FeedItem belongs to.
 @param item Currently processed @c FeedItem.
 @return Return @c YES to continue processing. Return @c NO to stop processing and exit early.
 */
typedef BOOL (^FeedConfigRecursiveItemsBlock) (FeedConfig *parent, FeedItem *item);

@property (getter=typ, setter=setTyp:) FeedConfigType typ;
@property (readonly) NSArray<FeedConfig*> *sortedChildren;
@property (readonly) NSIndexPath *indexPath;

- (BOOL)descendantFeedItems:(FeedConfigRecursiveItemsBlock)block;
- (void)calculateAndSetScheduled;
- (void)mergeChangesAndSave;
- (NSString*)readableRefreshString;
- (NSString*)readableDescription;
@end
