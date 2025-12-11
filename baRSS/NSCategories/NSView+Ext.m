#import "NSView+Ext.h"
#import "StrictUIntFormatter.h"

@implementation NSView (Ext)

#pragma mark - UI: TextFields -

/// Create label with non-editable text. Ensures uniform fontsize and text color. @c 17px height.
+ (NSTextField*)label:(NSString*)text {
	NSTextField *label = [NSTextField labelWithString:text];
	[label setFrameSize: NSMakeSize(0, HEIGHT_LABEL)];
	label.font = [NSFont systemFontOfSize: NSFont.systemFontSize];
	label.textColor = [NSColor controlTextColor];
	label.lineBreakMode = NSLineBreakByTruncatingTail;
//	label.backgroundColor = [NSColor yellowColor];
//	label.drawsBackground = YES;
	return [label sizeWidthToFit];
}

/// Create input text field with placeholder text. @c 21px height.
+ (NSTextField*)inputField:(NSString*)placeholder width:(CGFloat)w {
	NSTextField *input = [NSTextField textFieldWithString:@""];
	[input setFrameSize: NSMakeSize(w, HEIGHT_INPUTFIELD)];
	input.alignment = NSTextAlignmentJustified;
	input.placeholderString = placeholder;
	input.font = [NSFont systemFontOfSize: NSFont.systemFontSize];
	input.textColor = [NSColor controlTextColor];
	return input;
}

/// Create input text field which only accepts integer values. (calls `inputField`) `21px` height.
/// `field.formatter` is of type `StrictUIntFormatter`.
+ (NSTextField*)integerField:(NSString*)placeholder unit:(nullable NSString*)unit width:(CGFloat)w {
	NSTextField *input = [self inputField:placeholder width:w];
	input.formatter = [StrictUIntFormatter new];
	((StrictUIntFormatter*)input.formatter).unit = unit;
	return input;
}

/// Create view with @c NSTextField subviews with right-aligned and row-centered text from @c labels.
+ (NSView*)labelColumn:(NSArray<NSString*>*)labels rowHeight:(CGFloat)h padding:(CGFloat)pad {
	CGFloat w = 0, y = 0;
	CGFloat off = (h - HEIGHT_LABEL) / 2;
	NSView *parent = [[NSView alloc] init];
	for (NSUInteger i = 0; i < labels.count; i++) {
		NSTextField *lbl = [[NSView label:labels[i]] placeIn:parent xRight:0 yTop:y + off];
		w = Max(w, NSWidth(lbl.frame));
		y += h + pad;
	}
	[parent setFrameSize: NSMakeSize(w, y - pad)];
	return parent;
}


#pragma mark - UI: Buttons -


/// Create button. @c 21px height.
+ (NSButton*)button:(NSString*)text {
	NSButton *btn = [[NSButton alloc] initWithFrame: NSMakeRect(0, 0, 0, HEIGHT_BUTTON)];
	btn.font = [NSFont systemFontOfSize:NSFont.systemFontSize];
	btn.bezelStyle = NSBezelStyleRounded;
	btn.title = text;
	return [btn sizeWidthToFit];
}

/// Create @c NSBezelStyleSmallSquare image button. @c 25x21px
+ (NSButton*)buttonImageSquare:(nonnull NSImageName)name {
	NSButton *btn = [[NSButton alloc] initWithFrame: NSMakeRect(0, 0, 25, HEIGHT_BUTTON)];
	btn.bezelStyle = NSBezelStyleSmallSquare;
	btn.image = [NSImage imageNamed:name];
	if (!btn.image)  btn.title = name; // fallback to text
	return btn;
}

/// Create pure image button with no border.
+ (NSButton*)buttonIcon:(nonnull NSImageName)name size:(CGFloat)size {
	NSButton *btn = [[NSButton alloc] initWithFrame: NSMakeRect(0, 0, size, size)];
	btn.bezelStyle = NSBezelStyleRounded;
	btn.bordered = NO;
	btn.image = [NSImage imageNamed:name];
	NSSize s = btn.image.size;
	if (s.width > s.height)
		[btn.image setSize:NSMakeSize(size, size * (s.height / s.width))];
	else
		[btn.image setSize:NSMakeSize(size * (s.width / s.height), size)];
	return btn;
}

/// Create round button with question mark. @c 21x21px
+ (NSButton*)helpButton {
	NSButton *btn = [[NSButton alloc] initWithFrame: NSMakeRect(0, 0, 21, 21)];
	btn.bezelStyle = NSBezelStyleHelpButton;
	btn.title = @"";
	return btn;
}

/// Create gray inline button with rounded corners. @c 16px height.
+ (NSButton*)inlineButton:(NSString*)text {
	NSButton *btn = [[NSButton alloc] initWithFrame: NSMakeRect(0, 0, 0, HEIGHT_INLINEBUTTON)];
	btn.font = [NSFont monospacedDigitSystemFontOfSize: NSFont.labelFontSize weight: NSFontWeightBold];
	btn.bezelStyle = NSBezelStyleInline;
	btn.controlSize = NSControlSizeSmall;
	btn.title = text;
	return [btn sizeWidthToFit];
}

/// Create empty drop down button. @c 21px height.
+ (NSPopUpButton*)popupButton:(CGFloat)w {
	return [[NSPopUpButton alloc] initWithFrame: NSMakeRect(0, 0, w, HEIGHT_POPUP) pullsDown:NO];
}


#pragma mark - UI: Others -


/// Create @c ImageView with square @c size
+ (NSImageView*)imageView:(nullable NSImageName)name size:(CGFloat)size {
	NSImageView *imgView = [[NSImageView alloc] initWithFrame: NSMakeRect(0, 0, size, size)];
	if (name) imgView.image = [NSImage imageNamed:name];
	return imgView;
}

/// Create checkbox. @c 14px height.
+ (NSButton*)checkbox:(BOOL)flag {
	NSButton *check = [NSButton checkboxWithTitle:@"" target:nil action:nil];
	check.title = @""; // needed, otherwise will print "Button"
	check.frame = NSMakeRect(0, 0, HEIGHT_CHECKBOX, HEIGHT_CHECKBOX);
	check.state = (flag? NSControlStateValueOn : NSControlStateValueOff);
	return check;
}

/// Create progress spinner. @c 16px size.
+ (NSProgressIndicator*)activitySpinner {
	NSProgressIndicator *spin = [[NSProgressIndicator alloc] initWithFrame: NSMakeRect(0, 0, HEIGHT_SPINNER, HEIGHT_SPINNER)];
	spin.indeterminate = YES;
	spin.displayedWhenStopped = NO;
	spin.style = NSProgressIndicatorStyleSpinning;
	spin.controlSize = NSControlSizeSmall;
	return spin;
}

/// Create grouping view with vertically, left-aligned radio buttons. Action is identical for all buttons (grouping).
+ (nullable NSView*)radioGroup:(NSArray<NSString*>*)entries target:(id)target action:(nonnull SEL)action {
	if (entries.count == 0)
		return nil;
	CGFloat w = 0, h = 0;
	NSView *parent = [[NSView alloc] init];
	for (NSUInteger i = entries.count; i > 0; i--) {
		NSButton *btn = [NSButton radioButtonWithTitle:entries[i-1] target:target action:action];
		btn.tag = (NSInteger)i-1;
		if (btn.tag == 0)
			btn.state = NSControlStateValueOn;
		w = Max(w, NSWidth(btn.frame)); // find max width (before alignmentRect:)
		[btn placeIn:parent x:0 y:h];
		h += NSHeight([btn alignmentRectForFrame:btn.frame]) + PAD_XS;
	}
	[parent setFrameSize: NSMakeSize(w, h - PAD_XS)];
	return parent;
}

/// Same as @c radioGroup:target:action: but using dummy action to ignore radio button click events.
+ (nullable NSView*)radioGroup:(NSArray<NSString*>*)entries {
	return [self radioGroup:entries target:self action:@selector(donothing)];
}

/// Solely used to group radio buttons
+ (void)donothing {}


#pragma mark - UI: Enclosing Container -


/// Create transient popover with initial view controller and view @c size
+ (NSPopover*)popover:(NSSize)size {
	NSPopover *pop = [[NSPopover alloc] init];
	pop.behavior = NSPopoverBehaviorTransient;
	pop.contentViewController = [[NSViewController alloc] init];
	pop.contentViewController.view = [[NSView alloc] initWithFrame:NSMakeRect(0, 0, size.width, size.height)];
	return pop;
}

/// Insert @c scrollView, remove @c self from current view and set as @c documentView for the newly created scroll view.
- (NSScrollView*)wrapContent:(NSView*)content inScrollView:(NSRect)rect {
	NSScrollView *scroll = [[[NSScrollView alloc] initWithFrame:rect] sizableWidthAndHeight];
	scroll.borderType = NSBezelBorder;
	scroll.hasVerticalScroller = YES;
	scroll.horizontalScrollElasticity = NSScrollElasticityNone;
	[self addSubview:scroll];
	
	if (content.superview) [content removeFromSuperview]; // remove if added already (e.g., helper methods above)
	content.frame = NSMakeRect(0, 0, scroll.contentSize.width, scroll.contentSize.height);
	scroll.documentView = content;
	return scroll;
}

/// Create view with @c NSTextField label in front of the view.
+ (NSView*)wrapView:(NSView*)other withLabel:(NSString*)str padding:(CGFloat)pad {
	NSView *parent = [[NSView alloc] initWithFrame: NSZeroRect];
	NSTextField *label = [NSView label:str];
	[label placeIn:parent x:pad yTop:pad];
	[other placeIn:parent x:pad + NSWidth(label.frame) yTop:pad];
	[parent setFrameSize: NSMakeSize(NSMaxX(other.frame), NSHeight(other.frame) + 2 * pad)];
	return parent;
}


#pragma mark - Insert UI elements in parent view -


/**
 Set frame origin and insert @c self in @c parent view with @c frameForAlignmentRect:.
 You may use @c CENTER to automatically calculate midpoint in parent view.
 The @c autoresizingMask will be set accordingly.
 */
- (instancetype)placeIn:(NSView*)parent x:(CGFloat)x y:(CGFloat)y {
	if (x == CENTER) {
		x = (NSWidth(parent.frame) - NSWidth(self.frame)) / 2;
		self.autoresizingMask |= NSViewMinXMargin | NSViewMaxXMargin;
	}
	if (y == CENTER) {
		y = (NSHeight(parent.frame) - NSHeight(self.frame)) / 2;
		self.autoresizingMask |= NSViewMinYMargin | NSViewMaxYMargin;
	}
	[self setFrameOrigin: NSMakePoint(x, y)];
	self.frame = [self frameForAlignmentRect:self.frame];
	[parent addSubview:self];
	return self;
}

/// Same as @c placeIn:x:y: but measure position from top instead of bottom. Also sets @c autoresizingMask.
- (instancetype)placeIn:(NSView*)parent x:(CGFloat)x yTop:(CGFloat)y {
	return [[self placeIn:parent x:x y:NSHeight(parent.frame) - NSHeight(self.frame) - y] alignTop];
}

/// Same as @c placeIn:x:y: but measure position from right instead of left. Also sets @c autoresizingMask.
- (instancetype)placeIn:(NSView*)parent xRight:(CGFloat)x y:(CGFloat)y {
	return [[self placeIn:parent x:NSWidth(parent.frame) - NSWidth(self.frame) - x y:y] alignRight];
}

/// Set origin by measuring from top right (@c CENTER is not allowed here). Also sets @c autoresizingMask.
- (instancetype)placeIn:(NSView*)parent xRight:(CGFloat)x yTop:(CGFloat)y {
	[self setFrameOrigin: NSMakePoint(NSWidth(parent.frame) - NSWidth(self.frame) - x,
									  NSHeight(parent.frame) - NSHeight(self.frame) - y)];
	self.autoresizingMask = NSViewMinXMargin | NSViewMinYMargin;
	self.frame = [self frameForAlignmentRect:self.frame];
	[parent addSubview:self];
	return self;
}


#pragma mark - Modify existing UI elements -


// Aligned Frame Origins
// pad - view.alignmentRectInsets.left;
// pad - view.alignmentRectInsets.bottom;
// NSWidth(view.superview.frame) - NSWidth(view.frame) - pad + view.alignmentRectInsets.right;
// NSHeight(view.superview.frame) - NSHeight(view.frame) - pad + view.alignmentRectInsets.top;

/// Modify @c .autoresizingMask; Clear @c NSViewMaxYMargin flag and set @c NSViewMinYMargin
- (instancetype)alignTop { self.autoresizingMask = (self.autoresizingMask & ~NSViewMaxYMargin) | NSViewMinYMargin; return self; }

/// Modify @c .autoresizingMask; Clear @c NSViewMaxXMargin flag and set @c NSViewMinXMargin
- (instancetype)alignRight { self.autoresizingMask = (self.autoresizingMask & ~NSViewMaxXMargin) | NSViewMinXMargin; return self; }

/// Modify @c .autoresizingMask; Add @c NSViewWidthSizable @c | @c NSViewHeightSizable flags
- (instancetype)sizableWidthAndHeight { self.autoresizingMask |= NSViewWidthSizable | NSViewHeightSizable; return self; }

/// Extend frame in its @c superview and stick to right with padding. Adds @c NSViewWidthSizable to @c autoresizingMask
- (instancetype)sizeToRight:(CGFloat)rightPadding  {
	SetFrameWidth(self, NSWidth(self.superview.frame) - NSMinX(self.frame) - rightPadding + self.alignmentRectInsets.right);
	self.autoresizingMask |= NSViewWidthSizable;
	return self;
}

/// Set @c width to @c fittingSize.width but keep original height.
- (instancetype)sizeWidthToFit {
	SetFrameWidth(self, self.fittingSize.width);
	return self;
}

/// Set @c tooltip and @c accessibilityTitle of view and return self
- (instancetype)tooltip:(NSString*)tt {
	self.toolTip = tt;
	if (self.accessibilityLabel.length == 0)
		self.accessibilityLabel = tt;
	else
		self.accessibilityValueDescription = tt;
	return self;
}



/// Helper method to set frame width and keep same height
static inline void SetFrameWidth(NSView *view, CGFloat w) {
	[view setFrameSize: NSMakeSize(w, NSHeight(view.frame))];
}


#pragma mark - Debugging -


/// Set background color on @c .layer
- (instancetype)colorLayer:(NSColor*)color {
	self.layer = [CALayer layer];
	self.layer.backgroundColor = color.CGColor;
	return self;
}

+ (NSView*)redCube:(CGFloat)size {
	return [[[NSView alloc] initWithFrame: NSMakeRect(0, 0, size, size)] colorLayer:NSColor.redColor];
}

@end


#pragma mark - NSControl specific -


@implementation NSControl (Ext)

/// Set @c target and @c action simultaneously
- (instancetype)action:(SEL)selector target:(nullable id)target {
	self.action = selector;
	self.target = target;
	return self;
}

/// Set system font with current @c pointSize @c + @c 2. A label will be @c 19px height.
- (instancetype)large { SetFontAndResize(self, [NSFont systemFontOfSize: self.font.pointSize + 2]); return self; }

/// Set system font with @c smallSystemFontSize and perform @c sizeToFit. A label will be @c 14px height.
- (instancetype)small { SetFontAndResize(self, [NSFont systemFontOfSize: NSFont.smallSystemFontSize]); return self; }

/// Set monospaced font with @c labelFontSize regular and perform @c sizeToFit. A label will be @c 13px height.
- (instancetype)tiny { SetFontAndResize(self, [NSFont monospacedDigitSystemFontOfSize: NSFont.labelFontSize weight: NSFontWeightRegular]); return self; }

/// Set system bold font with current @c pointSize
- (instancetype)bold { SetFontAndResize(self, [NSFont boldSystemFontOfSize: self.font.pointSize]); return self; }

/// Set @c .alignment to @c NSTextAlignmentRight
- (instancetype)textRight { self.alignment = NSTextAlignmentRight; return self; }

/// Set @c .alignment to @c NSTextAlignmentCenter
- (instancetype)textCenter { self.alignment = NSTextAlignmentCenter; return self; }

/// Helper method to set new font, subsequently run @c sizeToFit
static inline void SetFontAndResize(NSControl *control, NSFont *font) {
	control.font = font; [control sizeToFit];
}

@end


@implementation NSTextField (Ext)

/// Set text color to @c systemGrayColor
- (instancetype)gray { self.textColor = [NSColor systemGrayColor]; return self; }

/// Set @c .selectable to @c YES
- (instancetype)selectable { self.selectable = YES; return self; }

/// Set @c .maximumNumberOfLines @c = @c 7 and @c preferredMaxLayoutWidth.
- (instancetype)multiline:(NSSize)size {
	[self setFrameSize:size];
	self.preferredMaxLayoutWidth = size.width;
	self.lineBreakMode = NSLineBreakByWordWrapping;
	self.usesSingleLineMode = NO;
	self.maximumNumberOfLines = 7; // used in ModalFeedEditView
	return self;
}

@end
