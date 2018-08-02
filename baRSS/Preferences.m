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
@property (weak) IBOutlet NSToolbar *toolbar;
@property (weak) IBOutlet NSView *viewGeneral;
@property (weak) IBOutlet NSView *viewFeeds;

@property (weak) IBOutlet NewsController *newsController;
@property (weak) IBOutlet NSOutlineView *feedsOutline;
@end

@implementation Preferences
- (void)awakeFromNib {
	[super awakeFromNib];
	if (self.window.contentView.subviews.count == 0) {
		self.window.contentView = self.viewGeneral;
		self.toolbar.selectedItemIdentifier = self.toolbar.items.firstObject.itemIdentifier;
	}
}

- (IBAction)clickGeneral:(NSToolbarItem *)sender {
	self.window.contentView = self.viewGeneral;
}

- (IBAction)clickFeeds:(NSToolbarItem *)sender {
	self.window.contentView = self.viewFeeds;
}

- (BOOL)acceptsFirstResponder {
	return YES;
}

- (void)keyDown:(NSEvent *)event {
	if (event.modifierFlags & NSEventModifierFlagCommand) {
		bool holdShift = event.modifierFlags & NSEventModifierFlagShift;
		@try {
			unichar key = [event.characters characterAtIndex:0];
			switch (key) {
				case 'w': [self close]; break;
				case 'q': [NSApplication.sharedApplication terminate:self]; break;
			}
			if (self.window.contentView == self.viewFeeds) { // these only apply for NSOutlineView
				switch (key) {
					case 'z':
						if (holdShift) [self.newsController.managedObjectContext.undoManager redo];
						else           [self.newsController.managedObjectContext.undoManager undo];
						[self.newsController rearrangeObjects]; // update the ordering
						break;
					case 'n': [self.newsController addFeed:nil]; break;
					case 'o': break; // open .opml file
					case 's': break; // save data or backup .opml file
					case 'c': // copy row entry
						[self.newsController copyDescriptionOfSelectedItems];
						break;
					case 'a': [self.feedsOutline selectAll:nil]; break;
					// TODO: delete
				}
			}
		} @catch (NSException *exception) {
			NSLog(@"%@", event);
		}
	}
}

@end
