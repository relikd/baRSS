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
	
	NSArray *lbls = @[NSLocalizedString(@"Open URLs with:", nil),
					  NSLocalizedString(@"Default RSS Reader:", nil)];
	NSView *labels = [[NSView labelColumn:lbls rowHeight:HEIGHT_POPUP padding:PAD_M] placeIn:self x:PAD_WIN yTop:PAD_WIN];
	CGFloat x = NSMaxX(labels.frame) + PAD_S;
	
	self.popupHttpApplication = [[self createPopup:x top: PAD_WIN + 1] action:@selector(changeHttpApplication:) target:controller];
	self.popupDefaultRSSReader = [[self createPopup:x top: YFromTop(self.popupHttpApplication) + PAD_M] action:@selector(changeDefaultRSSReader:) target:controller];
	
	// Add fix cache button
	[[[[NSView button:NSLocalizedString(@"Fix Cache", nil)] action:@selector(fixCache:) target:controller]
	  tooltip:NSLocalizedString(@"Will remove unreferenced feed entries", nil)] placeIn:self xRight:PAD_WIN y:PAD_WIN];
	return self;
}

/// Helper method to create sizable popup button
- (NSPopUpButton*)createPopup:(CGFloat)x top:(CGFloat)y {
	return [[[NSView popupButton:0] placeIn:self x:x yTop:y] sizeToRight:PAD_WIN];
}

@end
