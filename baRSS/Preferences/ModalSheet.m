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
@property (weak) NSButton *btnDone;
@property (assign) BOOL respondToShouldClose;
@end

@implementation ModalSheet
@synthesize didCloseAndSave = _didCloseAndSave, didCloseAndCancel = _didCloseAndCancel;

/// User did click the 'Done' button.
- (void)didTapDoneButton:(id)sender { [self closeWithResponse:NSModalResponseOK]; }
/// User did click the 'Cancel' button.
- (void)didTapCancelButton:(id)sender { [self closeWithResponse:NSModalResponseCancel]; }
/// Manually disable 'Done' button if a task is still running.
- (void)setDoneEnabled:(BOOL)accept { self.btnDone.enabled = accept; }

- (void)setDelegate:(id<NSWindowDelegate>)delegate {
	[super setDelegate:delegate];
	self.respondToShouldClose = [delegate respondsToSelector:@selector(windowShouldClose:)];
}

/**
 Called after user has clicked the 'Done' (Return) or 'Cancel' (Esc) button.
 Flags controller as being closed @c .closeInitiated @c = @c YES.
 And removes all subviews (clean up).
 */
- (void)closeWithResponse:(NSModalResponse)response {
	if (response == NSModalResponseOK && self.respondToShouldClose && ![self.delegate windowShouldClose:self]) {
		return;
	}
	_didCloseAndSave = (response == NSModalResponseOK);
	_didCloseAndCancel = (response != NSModalResponseOK);
	// store modal view width and remove subviews to avoid _NSKeyboardFocusClipView issues
	// first object is always the view of the modal dialog
	CGFloat w = self.contentView.subviews.firstObject.frame.size.width;
	[[NSUserDefaults standardUserDefaults] setInteger:(NSInteger)w forKey:@"modalSheetWidth"];
	[self.contentView.subviews makeObjectsPerformSelector:@selector(removeFromSuperview)];
	[self.sheetParent endSheet:self returnCode:response];
}

/**
 Designated initializer for @c ModalSheet. 'Done' and 'Cancel' button will be added automatically.

 @param content @c NSView will be displayed in dialog box.
 */
- (instancetype)initWithView:(NSView*)content {
	static const int padWindow = 20;
	static const int minWidth = 320;
	static const int maxWidth = 1200;
	
	NSInteger prevWidth = [[NSUserDefaults standardUserDefaults] integerForKey:@"modalSheetWidth"];
	if      (prevWidth < minWidth)  prevWidth = minWidth;
	else if (prevWidth > maxWidth)  prevWidth = maxWidth;
	
	NSSize contentSize = NSMakeSize(prevWidth, content.frame.size.height);
	[content setFrameSize:contentSize];
	
	NSSize wSize = NSMakeSize(contentSize.width + 2 * padWindow, contentSize.height + 2 * padWindow);
	
	NSWindowStyleMask style = NSWindowStyleMaskTitled | NSWindowStyleMaskResizable | NSWindowStyleMaskFullSizeContentView;
	self = [super initWithContentRect:NSMakeRect(0, 0, wSize.width, wSize.height) styleMask:style backing:NSBackingStoreBuffered defer:NO];
	if (self) {
		NSButton *btnDone = [NSButton buttonWithTitle:NSLocalizedString(@"Done", nil) target:self action:@selector(didTapDoneButton:)];
		NSButton *btnCancel = [NSButton buttonWithTitle:NSLocalizedString(@"Cancel", nil) target:self action:@selector(didTapCancelButton:)];
		btnDone.keyEquivalent = @"\r"; // Enter / Return
		btnCancel.keyEquivalent = [NSString stringWithFormat:@"%c", 0x1b]; // ESC
		
		// Make room for buttons
		wSize.height += btnDone.frame.size.height;
		[self setContentSize:wSize];
		
		// Restrict resizing to width only (after setContentSize:)
		self.minSize = NSMakeSize(minWidth + 2 * padWindow, wSize.height);
		self.maxSize = NSMakeSize(maxWidth + 2 * padWindow, wSize.height);
		
		// Content view (set origin after setContentSize:)
		[content setFrameOrigin:NSMakePoint(padWindow, wSize.height - padWindow - contentSize.height)];
		[self.contentView addSubview:content];
		
		// Respond buttons
		[self placeButtons:@[btnDone, btnCancel] inBottomRightCornerWithPadding:padWindow];
		[self.contentView addSubview:btnCancel];
		[self.contentView addSubview:btnDone];
		self.btnDone = btnDone;
	}
	return self;
}

/**
 Buttons will stick to the right margin and bottom margin when resizing. Also sets autoresizingMask.

 @param buttons First item is rightmost button. Next buttons will be appended left of that button and so on.
 @param padding Distance between button and right / bottom edge.
 */
- (void)placeButtons:(NSArray<NSButton*> *)buttons inBottomRightCornerWithPadding:(int)padding {
	NSEdgeInsets edge = buttons.firstObject.alignmentRectInsets;
	NSPoint p = NSMakePoint(self.contentView.frame.size.width - padding + edge.right, padding - edge.bottom);
	for (NSButton *btn in buttons) {
		p.x -= btn.frame.size.width;
		[btn setFrameOrigin:p];
		btn.autoresizingMask = NSViewMinXMargin | NSViewMaxYMargin;
	}
}

/**
 Resize modal window by @c dy. Makes room for additional content. Use negative values to shrink window.
 */
- (void)extendContentViewBy:(CGFloat)dy {
	self.minSize = NSMakeSize(self.minSize.width, self.minSize.height + dy);
	self.maxSize = NSMakeSize(self.maxSize.width, self.maxSize.height + dy);
	NSRect r = self.frame;
	r.size.height += dy;
	[self setFrame:r display:YES animate:YES];
}

@end


