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

#import "SettingsGeneral.h"
#import "AppHook.h"
#import "BarMenu.h"

@implementation SettingsGeneral

- (void)viewDidLoad {
    [super viewDidLoad];
}

- (IBAction)checkmarkClicked:(NSButton*)sender {
	// TODO: Could be optimized by updating only the relevant parts
	[[(AppHook*)NSApp barMenu] rebuildMenu];
}

- (IBAction)changeMenuBarIconSetting:(NSButton*)sender {
	[[(AppHook*)NSApp barMenu] updateBarIcon];
}

- (IBAction)changeMenuHeaderSetting:(NSButton*)sender {
	BOOL recursive = YES;
	NSString *bindingKey = [[sender infoForBinding:@"value"] valueForKey:NSObservedKeyPathKey];
	if ([bindingKey containsString:@"values.global"]) {
		recursive = NO; // item is in menu bar menu, no need to go recursive
	}
	[[(AppHook*)NSApp barMenu] updateMenuHeaders:recursive];
}

- (IBAction)changeMenuItemUpdateAllHidden:(NSButton*)sender {
	BOOL checked = (sender.state == NSControlStateValueOn);
	[[(AppHook*)NSApp barMenu] setItemUpdateAllHidden:!checked];
}

// TODO: show list of installed browsers and make menu choosable

@end
