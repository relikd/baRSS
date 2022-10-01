#import "ModalSheet.h"
#import "UserPrefs.h"
#import "NSView+Ext.h"

@interface ModalSheet()
@property (assign) BOOL respondToShouldClose;
@end

@implementation ModalSheet

/// Designated initializer. 'Done' and 'Cancel' buttons will be added automatically.
- (instancetype)initWithView:(NSView*)content {
	static NSInteger const minWidth = 320;
	static NSInteger const maxWidth = 1200;
	static CGFloat const contentOffsetY = PAD_WIN + HEIGHT_BUTTON + PAD_L;
	
	NSInteger w = UserPrefsInt(Pref_modalSheetWidth);
	if      (w < minWidth)  w = minWidth;
	else if (w > maxWidth)  w = maxWidth;
	
	CGFloat h = NSHeight(content.frame);
	[content setFrameSize: NSMakeSize(w, h)];
	
	// after content size, increase to window size
	w += 2 * (NSInteger)PAD_WIN;
	h += PAD_WIN + contentOffsetY; // the second PAD_WIN is already in contentOffsetY
	
	NSWindowStyleMask style = NSWindowStyleMaskTitled | NSWindowStyleMaskResizable | NSWindowStyleMaskFullSizeContentView;
	self = [super initWithContentRect:NSMakeRect(0, 0, w, h) styleMask:style backing:NSBackingStoreBuffered defer:NO];
	[content placeIn:self.contentView x:PAD_WIN y:contentOffsetY];
	
	// Restrict resizing to width only
	self.minSize = NSMakeSize(minWidth + 2 * PAD_WIN, h);
	self.maxSize = NSMakeSize(maxWidth + 2 * PAD_WIN, h);
	
	// Add default interaction buttons
	NSButton *btnDone = [self createButton:NSLocalizedString(@"Done", nil) atX:PAD_WIN];
	NSButton *btnCancel = [self createButton:NSLocalizedString(@"Cancel", nil) atX:w - NSMinX(btnDone.frame) + PAD_M];
	btnDone.tag = 42; // mark 'Done' button
	btnDone.keyEquivalent = @"\r"; // Enter / Return
	btnCancel.keyEquivalent = [NSString stringWithFormat:@"%c", 0x1b]; // ESC
	return self;
}

/// Helper method to create bottom-right aligned button.
- (NSButton*)createButton:(NSString*)text atX:(CGFloat)x {
	return [[[NSView button:text] action:@selector(didTapButton:) target:self] placeIn:self.contentView xRight:x y:PAD_WIN];
}

/// Manually disable 'Done' button if a task is still running.
- (void)setDoneEnabled:(BOOL)accept {
	((NSButton*)[self.contentView viewWithTag:42]).enabled = accept;
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
	// Save modal view width for next time
	NSInteger width = (NSInteger)(NSWidth(self.contentView.frame) - 2 * PAD_WIN);
	if (UserPrefsInt(Pref_modalSheetWidth) != width)
		UserPrefsSetInt(Pref_modalSheetWidth, width);
	// Remove subviews to avoid _NSKeyboardFocusClipView issues
	[self.contentView.subviews makeObjectsPerformSelector:@selector(removeFromSuperview)];
	[self.sheetParent endSheet:self returnCode:(successful ? NSModalResponseOK : NSModalResponseCancel)];
}

/// Resize modal window by @c dy. Makes room for additional content. Use negative values to shrink window.
- (void)extendContentViewBy:(CGFloat)dy {
	self.minSize = NSMakeSize(self.minSize.width, self.minSize.height + dy);
	self.maxSize = NSMakeSize(self.maxSize.width, self.maxSize.height + dy);
	NSRect r = self.frame;
	r.size.height += dy;
	[self setFrame:r display:YES animate:YES];
}

@end
