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

#import "Preferences.h"
#import "NewsController.h"
#import "ModalSheet.h"

@interface Preferences ()
@property (weak) IBOutlet NSView *viewGeneral;
@property (weak) IBOutlet NSView *viewFeeds;
@property (weak) IBOutlet NewsController *newsController;
@end

@implementation Preferences

- (void)awakeFromNib {
	[super awakeFromNib];
	NSUInteger idx = (NSUInteger)[[NSUserDefaults standardUserDefaults] integerForKey:@"preferencesTab"];
	if (idx >= self.toolbar.items.count)
		idx = 0;
	[self tabClicked:self.toolbar.items[idx]];
}

- (IBAction)tabClicked:(NSToolbarItem *)sender {
	self.contentView = nil;
	if ([sender.itemIdentifier isEqualToString:@"tabGeneral"])
		self.contentView = self.viewGeneral;
	else if ([sender.itemIdentifier isEqualToString:@"tabFeeds"])
		self.contentView = self.viewFeeds;
	
	self.toolbar.selectedItemIdentifier = sender.itemIdentifier;
	[self recalculateKeyViewLoop];
	[self setInitialFirstResponder:self.contentView];
	
	[[NSUserDefaults standardUserDefaults] setInteger:(NSInteger)[self.toolbar.items indexOfObject:sender]
											   forKey:@"preferencesTab"];
}

- (void)undo:(id)sender {
	[self.newsController.managedObjectContext.undoManager undo];
	[self.newsController rearrangeObjects]; // update ordering
}

- (void)redo:(id)sender {
	[self.newsController.managedObjectContext.undoManager redo];
	[self.newsController rearrangeObjects]; // update ordering
}

- (void)copy:(id)sender {
	[self.newsController copyDescriptionOfSelectedItems];
}

- (void)enterPressed:(id)sender {
	[self.newsController openModalForSelection];
}

- (BOOL)respondsToSelector:(SEL)aSelector {
	bool isFeedView = (self.contentView == self.viewFeeds) && !self.attachedSheet;
	// Only if 'Feeds' Tab is selected  &  no open modal sheet  &  NSOutlineView has focus
	if (aSelector == @selector(enterPressed:) || aSelector == @selector(copy:)) {
		bool outlineHasFocus = [[self firstResponder] isKindOfClass:[NSOutlineView class]];
		return isFeedView && outlineHasFocus && (self.newsController.selectedNodes.count > 0);
	} else if (aSelector == @selector(undo:)) {
		return isFeedView && [self.newsController.managedObjectContext.undoManager canUndo];
	} else if (aSelector == @selector(redo:)) {
		return isFeedView && [self.newsController.managedObjectContext.undoManager canRedo];
	}
	return [super respondsToSelector:aSelector];
}

- (void)presentModal:(NSView*)view completion:(void (^ __nullable)(NSModalResponse returnCode))handler {
	[self.modalSheet setFormContent:view];
	[self beginSheet:self.modalSheet completionHandler:handler];
}

@end
