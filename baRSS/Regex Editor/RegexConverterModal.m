#import "RegexConverterModal.h"
#import "UserPrefs.h"
#import "NSView+Ext.h"

@interface RegexConverterModal()
@property (assign) BOOL respondToShouldClose;
@end

@implementation RegexConverterModal

/// Designated initializer. 'Done' and 'Cancel' buttons will be added automatically.
- (instancetype)initWithView:(NSView*)content {
	static CGFloat const contentOffsetY = PAD_WIN + HEIGHT_BUTTON + PAD_L;

	CGSize sz = content.frame.size;
	sz.width += 2 * (NSInteger)PAD_WIN;
	sz.height += PAD_WIN + contentOffsetY; // the second PAD_WIN is already in contentOffsetY

	NSWindowStyleMask style = NSWindowStyleMaskTitled | NSWindowStyleMaskResizable | NSWindowStyleMaskFullSizeContentView;
	self = [super initWithContentRect:NSMakeRect(0, 0, sz.width, sz.height) styleMask:style backing:NSBackingStoreBuffered defer:NO];
	[content placeIn:self.contentView x:PAD_WIN y:contentOffsetY];

	self.minSize = sz;

	// Add default interaction buttons
	NSButton *btnDone = [self createButton:NSLocalizedString(@"Done", nil) atX:PAD_WIN];
	NSButton *btnCancel = [self createButton:NSLocalizedString(@"Cancel", nil) atX:sz.width - NSMinX(btnDone.frame) + PAD_M];
	btnDone.tag = 42; // mark 'Done' button
	//btnDone.keyEquivalent = @"\r"; // Enter / Return
	btnCancel.keyEquivalent = [NSString stringWithFormat:@"%c", 0x1b]; // ESC
	return self;
}

/// Helper method to create bottom-right aligned button.
- (NSButton*)createButton:(NSString*)text atX:(CGFloat)x {
	return [[[NSView button:text] action:@selector(didTapButton:) target:self] placeIn:self.contentView xRight:x y:PAD_WIN];
}

/// Sets bool for future usage
- (void)setDelegate:(id<NSWindowDelegate>)delegate {
	[super setDelegate:delegate];
	self.respondToShouldClose = [delegate respondsToSelector:@selector(windowShouldClose:)];
}

/**
 Called after user has clicked the 'Done' (Return) or 'Cancel' (Esc) button.
 In the later case set @c .didTapCancel @c = @c YES
 */
- (void)didTapButton:(NSButton*)sender {
	BOOL successful = (sender.tag == 42); // 'Done' button
	_didTapCancel = !successful;
	if (self.respondToShouldClose && ![self.delegate windowShouldClose:self]) {
		return;
	}
	// Remove subviews to avoid _NSKeyboardFocusClipView issues
	[self.contentView.subviews makeObjectsPerformSelector:@selector(removeFromSuperview)];
	[self.sheetParent endSheet:self returnCode:(successful ? NSModalResponseOK : NSModalResponseCancel)];
}

@end
