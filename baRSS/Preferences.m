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

@interface Preferences ()
@property (weak) IBOutlet NSView *viewGeneral;
@property (weak) IBOutlet NSView *viewFeeds;
@property (weak) IBOutlet NewsController *newsController;
@end

@implementation Preferences

- (void)awakeFromNib {
	[super awakeFromNib];
	if (self.contentView.subviews.count == 0) {
		self.contentView = self.viewGeneral;
		self.toolbar.selectedItemIdentifier = self.toolbar.items.firstObject.itemIdentifier;
	}
}

- (IBAction)tabGeneralClicked:(NSToolbarItem *)sender {
	self.contentView = self.viewGeneral;
}

- (IBAction)tabFeedsClicked:(NSToolbarItem *)sender {
	self.contentView = self.viewFeeds;
}

- (void)undo:(id)sender {
	if (self.contentView == self.viewFeeds) {
		[self.newsController.managedObjectContext.undoManager undo];
		[self.newsController rearrangeObjects]; // update the ordering
	}
}

- (void)redo:(id)sender {
	if (self.contentView == self.viewFeeds) {
		[self.newsController.managedObjectContext.undoManager redo];
		[self.newsController rearrangeObjects]; // update the ordering
	}
}

- (void)copy:(id)sender {
	[self.newsController copyDescriptionOfSelectedItems];
}

@end
