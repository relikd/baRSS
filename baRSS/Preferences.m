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
#import "AppDelegate.h"

@interface Preferences ()
@property (weak) IBOutlet NSToolbar *toolbar;
@property (weak) IBOutlet NSView *viewGeneral;
@property (weak) IBOutlet NSView *viewFeeds;
@property (weak) IBOutlet AppDelegate *appDelegate;
@end

@implementation Preferences

- (void)windowDidLoad {
    [super windowDidLoad];
    NSLog(@"%@", @"hi");
    // Implement this method to handle any initialization after your window controller's window has been loaded from its nib file.
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
		if ([event.characters isEqualToString:@"w"]) {
			[self close];
		} else if ([event.characters isEqualToString:@"q"]) {
			[self.appDelegate quitClicked:self];
		}
		// TODO: new, delete, ...
	}
}

@end
