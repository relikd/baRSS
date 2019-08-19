//
//  The MIT License (MIT)
//  Copyright (c) 2019 Oleg Geier
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

#import "SettingsGeneralView.h"
#import "SettingsGeneral.h"
#import "NSView+Ext.h"

@implementation SettingsGeneralView

- (instancetype)initWithController:(SettingsGeneral*)controller {
	self = [super initWithFrame:NSZeroRect];
	// Change default feed reader application
	NSTextField *l1 = [[NSView label:NSLocalizedString(@"Default feed reader:", nil)] placeIn:self x:PAD_WIN yTop:PAD_WIN + 3];
	NSButton *help = [[[NSView helpButton] action:@selector(clickHowToDefaults:) target:controller] placeIn:self xRight:PAD_WIN yTop:PAD_WIN];
	self.defaultReader = [[[[NSView label:@""] bold] placeIn:self x:NSMaxX(l1.frame) + PAD_S yTop:PAD_WIN + 3] sizeToRight:NSWidth(help.frame) + PAD_WIN];
	// Popup button 'Open URLs with:'
	CGFloat y = YFromTop(help) + PAD_M;
	NSTextField *l2 = [[NSView label:NSLocalizedString(@"Open URLs with:", nil)] placeIn:self x:PAD_WIN yTop:y + 1];
	self.popupHttpApplication = [[[[NSView popupButton:0] placeIn:self x:NSMaxX(l2.frame) + PAD_S yTop:y] sizeToRight:PAD_WIN]
								 action:@selector(changeHttpApplication:) target:controller];
	return self;
}

@end
