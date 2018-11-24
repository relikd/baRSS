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

#import "NSMenu+Ext.h"
#import "NSMenuItem+Ext.h"

@implementation NSMenu (Ext)

+ (instancetype)menuWithDelegate:(id<NSMenuDelegate>)target {
	NSMenu *menu = [[NSMenu alloc] initWithTitle:@"M"];
	menu.autoenablesItems = NO;
	menu.delegate = target;
	return menu;
}

- (instancetype)submenuWithIndex:(int)index isFeed:(BOOL)flag {
	NSMenu *menu = [NSMenu new];
	menu.title = [NSString stringWithFormat:@"%c%@.%d", (flag ? 'F' : 'G'), self.title, index];
	menu.autoenablesItems = NO;
	menu.delegate = self.delegate;
	return menu;
}

- (void)replaceSeparatorStringsWithActualSeparator {
	for (NSInteger i = 0; i < self.numberOfItems; i++) {
		NSMenuItem *oldItem = [self itemAtIndex:i];
		if ([oldItem.title isEqualToString:@"---SEPARATOR---"]) {
			NSMenuItem *newItem = [NSMenuItem separatorItem];
			newItem.representedObject = oldItem.representedObject;
			[self removeItemAtIndex:i];
			[self insertItem:newItem atIndex:i];
		}
	}
}

- (BOOL)isMainMenu {
	return [self.title isEqualToString:@"M"];
}

- (BOOL)isFeedMenu {
	return [self.title characterAtIndex:0] == 'F';
}

//- (void)iterateMenuItems:(void(^)(NSMenuItem*,BOOL))block atIndexPath:(NSIndexPath*)path  {
//	NSMenu *m = self;
//	for (NSUInteger u = 0; u < path.length; u++) {
//		NSUInteger i = [path indexAtPosition:u];
//		for (NSMenuItem *item in m.itemArray) {
//			if (![item.representedObject isKindOfClass:[NSManagedObjectID class]]) {
//				continue; // not a core data item
//			}
//			if (i == 0) {
//				BOOL isFinalItem = (u == path.length - 1);
//				block(item, isFinalItem);
//				if (isFinalItem) return; // item found!
//				m = item.submenu;
//				break; // cancel evaluation of remaining items
//			}
//			i -= 1;
//		}
//	}
//	return; // whenever a menu inbetween is nil (e.g., wasn't set yet)
//}

- (NSInteger)getFeedConfigOffsetAndUpdateUnread:(BOOL)hasUnread {
	for (NSInteger i = 0; i < self.numberOfItems; i++) {
		NSMenuItem *item = [self itemAtIndex:i];
		if ([item.representedObject isKindOfClass:[NSManagedObjectID class]]) {
			return i;
		} else {
			//[item applyUserSettingsDisplay]; // should not change while menu is open
			switch (item.tag & TagMaskType) {
				case TagOpenAllUnread: case TagMarkAllRead:
					item.enabled = hasUnread;
				default: break;
			}
		}
	}
	return 0;
}

@end
