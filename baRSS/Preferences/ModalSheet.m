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

#import "ModalSheet.h"

@interface ModalSheet()
@property (strong) NSButton *btnDone;
@end

@implementation ModalSheet

- (void)didTapDoneButton:(id)sender { [self closeWithResponse:NSModalResponseOK]; }
- (void)didTapCancelButton:(id)sender { [self closeWithResponse:NSModalResponseAbort]; }
- (void)setDoneEnabled:(BOOL)accept { self.btnDone.enabled = accept; }

- (void)closeWithResponse:(NSModalResponse)response {
	// store modal view width and remove subviews to avoid _NSKeyboardFocusClipView issues
	// first object is always the view of the modal dialog
	CGFloat w = self.contentView.subviews.firstObject.frame.size.width;
	[[NSUserDefaults standardUserDefaults] setInteger:(NSInteger)w forKey:@"modalSheetWidth"];
	[self.contentView.subviews makeObjectsPerformSelector:@selector(removeFromSuperview)];
	[self.sheetParent endSheet:self returnCode:response];
}

+ (instancetype)modalWithView:(NSView*)content {
	static const int padWindow = 20;
	static const int padButtons = 12;
	static const int minWidth = 320;
	static const int maxWidth = 1200;
	
	NSInteger prevWidth = [[NSUserDefaults standardUserDefaults] integerForKey:@"modalSheetWidth"];
	if      (prevWidth < minWidth)  prevWidth = minWidth;
	else if (prevWidth > maxWidth)  prevWidth = maxWidth;
	
	NSRect cFrame = NSMakeRect(padWindow, padWindow, prevWidth, content.frame.size.height);
	NSRect wFrame = CGRectInset(cFrame, -padWindow, -padWindow);
	
	NSWindowStyleMask style = NSWindowStyleMaskTitled | NSWindowStyleMaskResizable | NSWindowStyleMaskFullSizeContentView;
	ModalSheet *sheet = [[super alloc] initWithContentRect:wFrame styleMask:style backing:NSBackingStoreBuffered defer:NO];
	
	// Respond buttons
	sheet.btnDone = [NSButton buttonWithTitle:NSLocalizedString(@"Done", nil) target:sheet action:@selector(didTapDoneButton:)];
	sheet.btnDone.keyEquivalent = @"\r"; // Enter / Return
	sheet.btnDone.autoresizingMask = NSViewMinXMargin | NSViewMaxYMargin;
	
	NSButton *btnCancel = [NSButton buttonWithTitle:NSLocalizedString(@"Cancel", nil) target:sheet action:@selector(didTapCancelButton:)];
	btnCancel.keyEquivalent = [NSString stringWithFormat:@"%c", 0x1b]; // ESC
	btnCancel.autoresizingMask = NSViewMinXMargin | NSViewMaxYMargin;
	
	NSRect align = [sheet.btnDone alignmentRectForFrame:sheet.btnDone.frame];
	align.origin.x = wFrame.size.width - align.size.width - padWindow;
	align.origin.y = padWindow;
	[sheet.btnDone setFrameOrigin:[sheet.btnDone frameForAlignmentRect:align].origin];

	align.origin.x -= [btnCancel alignmentRectForFrame:btnCancel.frame].size.width + padButtons;
	[btnCancel setFrameOrigin:[btnCancel frameForAlignmentRect:align].origin];
	
	// this is equivalent, however I'm not sure if these values will change in a future OS
//	[btnDone setFrameOrigin:NSMakePoint(wFrame.size.width - btnDone.frame.size.width - 12, 13)]; // =20 with alignment
//	[btnCancel setFrameOrigin:NSMakePoint(btnDone.frame.origin.x - btnCancel.frame.size.width, 13)];
	
	// add all UI elements to the window view
	content.frame = cFrame;
	[sheet.contentView addSubview:content];
	[sheet.contentView addSubview:sheet.btnDone];
	[sheet.contentView addSubview:btnCancel];
	
	// add respond buttons to the window height
	wFrame.size.height += align.size.height + padButtons;
	[sheet setContentSize:wFrame.size];
	
	// constraints on resizing
	sheet.minSize = NSMakeSize(minWidth + 2 * padWindow, wFrame.size.height);
	sheet.maxSize = NSMakeSize(maxWidth, wFrame.size.height);
	return sheet;
}
@end


