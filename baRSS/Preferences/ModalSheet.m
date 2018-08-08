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

#define BETWEEN(x,min,max) (x < min ? min : x > max ? max : x)


#pragma mark - ModalSheet

@implementation ModalSheet

- (void)didTapDoneButton:(id)sender { [self closeWithResponse:NSModalResponseOK]; }
- (void)didTapCancelButton:(id)sender { [self closeWithResponse:NSModalResponseAbort]; }

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
	
	NSRect cFrame = NSMakeRect(padWindow, padWindow, BETWEEN(prevWidth, minWidth, maxWidth), content.frame.size.height);
	NSRect wFrame = CGRectInset(cFrame, -padWindow, -padWindow);
	
	NSWindowStyleMask style = NSWindowStyleMaskTitled | NSWindowStyleMaskResizable | NSWindowStyleMaskFullSizeContentView;
	ModalSheet *sheet = [[super alloc] initWithContentRect:wFrame styleMask:style backing:NSBackingStoreBuffered defer:NO];
	
	// Respond buttons
	NSButton *btnDone = [NSButton buttonWithTitle:NSLocalizedString(@"Done", nil) target:sheet action:@selector(didTapDoneButton:)];
	btnDone.keyEquivalent = @"\r"; // Enter / Return
	btnDone.autoresizingMask = NSViewMinXMargin | NSViewMaxYMargin;
	
	NSButton *btnCancel = [NSButton buttonWithTitle:NSLocalizedString(@"Cancel", nil) target:sheet action:@selector(didTapCancelButton:)];
	btnCancel.keyEquivalent = [NSString stringWithFormat:@"%c", 0x1b]; // ESC
	btnCancel.autoresizingMask = NSViewMinXMargin | NSViewMaxYMargin;
	
	NSRect align = [btnDone alignmentRectForFrame:btnDone.frame];
	align.origin.x = wFrame.size.width - align.size.width - padWindow;
	align.origin.y = padWindow;
	[btnDone setFrameOrigin:[btnDone frameForAlignmentRect:align].origin];

	align.origin.x -= [btnCancel alignmentRectForFrame:btnCancel.frame].size.width + padButtons;
	[btnCancel setFrameOrigin:[btnCancel frameForAlignmentRect:align].origin];
	
	// this is equivalent, however I'm not sure if these values will change in a future OS
//	[btnDone setFrameOrigin:NSMakePoint(wFrame.size.width - btnDone.frame.size.width - 12, 13)]; // =20 with alignment
//	[btnCancel setFrameOrigin:NSMakePoint(btnDone.frame.origin.x - btnCancel.frame.size.width, 13)];
	
	// add all UI elements to the window view
	content.frame = cFrame;
	[sheet.contentView addSubview:content];
	[sheet.contentView addSubview:btnDone];
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


#pragma mark - ModalFeedEdit


@implementation ModalFeedEdit
- (void)setDefaultValues {
	self.url.stringValue = @"";
	self.title.stringValue = @"";
	self.refreshNum.intValue = 30;
	[self.refreshUnit selectItemAtIndex:1];
}
- (void)setURL:(NSString*)url name:(NSString*)name refreshNum:(int32_t)num unit:(int16_t)unit {
	self.url.objectValue = url;
	self.title.objectValue = name;
	self.refreshNum.intValue = num;
	[self.refreshUnit selectItemAtIndex:BETWEEN(unit, 0, self.refreshUnit.numberOfItems - 1)];
}
+ (NSString*)stringForRefreshNum:(int32_t)num unit:(int16_t)unit {
	return [NSString stringWithFormat:@"%d%c", num, [@"smhdw" characterAtIndex:(NSUInteger)BETWEEN(unit, 0, 4)]];
}
@end


#pragma mark - ModalGroupEdit


@implementation ModalGroupEdit
- (void)setDefaultValues {
	self.title.stringValue = @"New Group";
}
- (void)setGroupName:(NSString*)name {
	self.title.objectValue = name;
}
@end


#pragma mark - StrictUIntFormatter


@implementation StrictUIntFormatter
- (NSString *)stringForObjectValue:(id)obj {
	return [NSString stringWithFormat:@"%d", [[NSString stringWithFormat:@"%@", obj] intValue]];
}
- (BOOL)getObjectValue:(out id  _Nullable __autoreleasing *)obj forString:(NSString *)string errorDescription:(out NSString *__autoreleasing  _Nullable *)error {
	*obj = [[NSNumber numberWithInt:[string intValue]] stringValue];
	return YES;
}
- (BOOL)isPartialStringValid:(NSString *__autoreleasing  _Nonnull *)partialStringPtr proposedSelectedRange:(NSRangePointer)proposedSelRangePtr originalString:(NSString *)origString originalSelectedRange:(NSRange)origSelRange errorDescription:(NSString *__autoreleasing  _Nullable *)error {
	for (NSUInteger i = 0; i < [*partialStringPtr length]; i++) {
		unichar c = [*partialStringPtr characterAtIndex:i];
		if (c < '0' || c > '9')
			return NO;
	}
	return YES;
}
@end
