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

#import <Cocoa/Cocoa.h>

@interface MenuItemInfo : NSObject
@property (strong) NSManagedObjectID *objID;
+ (instancetype)withID:(NSManagedObjectID*)oid;
+ (instancetype)withID:(NSManagedObjectID*)oid unread:(int)count;
@end


@interface NSMenuItem (MenuItemInfo)
/**
 Iteration block for descendants of @c NSMenuItem.

 @param count The number of sub-elements contained in that @c NSMenuItem. 1 for @c FeedItems at the deepest layer.
              Otherwise the number of (updated) descendants.
 @return Return how many elements are updated in this block execution. If none were changed return @c 0.
                If execution should be stopped early, return @c -1.
 */
typedef int (^MenuItemInfoRecursiveBlock) (NSMenuItem *item, int count);

- (BOOL)hasUnread;
- (int)unreadCount;
- (void)markReadAndUpdateTitle:(int)count;
- (void)markAncestorsRead:(int)count;
- (int)siblingsDescendantItemInfo:(MenuItemInfoRecursiveBlock)block unreadEntriesOnly:(BOOL)flag;
@end

