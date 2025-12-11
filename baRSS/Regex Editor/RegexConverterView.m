#import "RegexConverterView.h"
#import "RegexConverterController.h"
#import "RegexConverter+Ext.h"
#import "NSDate+Ext.h"
#import "NSView+Ext.h"

@interface RegexConverterView()
@property NSPopover *infoPopover;
@property (strong) IBOutlet NSTextField *popoverText;
@property (strong) IBOutlet NSButton *infoButtonEntry;
@end


@implementation RegexConverterView

static CGFloat const heightHowTo = 2 * HEIGHT_LABEL_SMALL;
static CGFloat const heightOutput = 150;
static CGFloat const heightRow = PAD_S + HEIGHT_INPUTFIELD;

- (instancetype)initWithController:(RegexConverterController*)controller {
	NSArray *lbls = @[
		NSLocalizedString(@"Entries", nil),
		NSLocalizedString(@"Link", nil),
		NSLocalizedString(@"Title", nil),
		NSLocalizedString(@"Description", nil),
		NSLocalizedString(@"Date", nil),
		NSLocalizedString(@"Date Format", nil),
	];
	NSView *labels = [NSView labelColumn:lbls rowHeight:HEIGHT_INPUTFIELD padding:PAD_S];
	
	self = [super initWithFrame:NSMakeRect(0, 0, 420, heightHowTo + PAD_L + NSHeight(labels.frame) + PAD_L + heightOutput)];
	self.autoresizingMask = NSViewWidthSizable | NSViewHeightSizable;
	
	[self makeHowTo];
	
	CGFloat x = NSWidth(labels.frame) + PAD_S;
	[labels placeIn:self x:0 yTop:heightHowTo + PAD_L];
	
	self.entry = [self inputAndExamples:0 x:x delegate:controller];
	self.href = [self inputAndExamples:1 x:x delegate:controller];
	self.title = [self inputAndExamples:2 x:x delegate:controller];
	self.desc = [self inputAndExamples:3 x:x delegate:controller];
	self.date = [self inputAndExamples:4 x:x delegate:controller];
	self.dateFormat = [self inputAndExamples:5 x:x delegate:controller];
	
	// output text field
	self.output = [self makeOutput];
	
	// prepare info popover
	self.infoPopover = [NSView popover: NSMakeSize(400, 100)];
	NSView *content = self.infoPopover.contentViewController.view;
	self.popoverText = [[[[[NSView label:@""] selectable] sizableWidthAndHeight]
						 multiline:NSMakeSize(384, 92)] placeIn:content x:8 y:4];
	return self;
}

- (NSTextView *)makeHowTo {
	NSTextView *tv = [[NSTextView new] sizableWidthAndHeight];
	tv.editable = NO; // but selectable
	tv.drawsBackground = NO;
	tv.textContainer.textView.string = NSLocalizedString(@"DIY regex converter. Press enter to confirm. For help, refer to online tools (e.g., regex101 with options: global + single-line)", nil);
	NSScrollView *scroll = [[tv wrapInScrollView:NSMakeSize(NSWidth(self.frame) + 2, heightHowTo)] placeIn:self x:-1 y:NSHeight(self.frame) - heightHowTo];
	scroll.drawsBackground = NO;
	scroll.borderType = NSNoBorder;
	scroll.verticalScrollElasticity = NSScrollElasticityNone;
	scroll.autoresizingMask = NSViewMinYMargin | NSViewWidthSizable;
	return tv;
}

- (NSTextView *)makeOutput {
	NSTextView *tv = [[NSTextView new] sizableWidthAndHeight];
	tv.editable = NO; // but selectable
	tv.backgroundColor = NSColor.whiteColor;
	[[tv wrapInScrollView:NSMakeSize(NSWidth(self.frame) + 2, heightOutput)] placeIn:self x:-1 y:0];
	return tv;
}

/// Helper method to create input field with help button showing regex examples
- (NSTextField *)inputAndExamples:(NSInteger)row x:(CGFloat)x delegate:(id<NSTextFieldDelegate>)delegate {
	CGFloat yOffset = heightHowTo + PAD_L + row * heightRow;
	NSTextField *input = [[[NSView inputField:@"" width:0] placeIn:self x:x yTop:yOffset]
						  sizeToRight:PAD_S + HEIGHT_BUTTON]; // width of the helpButton
	input.delegate = delegate;
	
	NSInteger tag = 700 + row;
	NSArray<NSString *> *examples = [self examplesFor:tag];
	if (examples.count > 0) {
		[[[[NSView helpButton] action:@selector(didClickExamplesButton:) target:self]
		  tooltip:NSLocalizedString(@"Click here to show examples", nil)]
		 placeIn:self xRight:0 yTop:yOffset].tag = tag;
		
		input.placeholderString = [examples firstObject];
	}
	return input;
}

/// Example to be displayed in help button
- (NSArray<NSString *> *)examplesFor:(NSInteger)tag {
	switch (tag) {
		case 700: return @[ // entries
			@"<dt[ >].*?<\\/dd>",
		];
		case 701: return @[ // link
			@"href=\"([^\"]*)\"",
		];
		case 702: return @[ // title
			@"title=\"([^\"]*)\"",
			@">([^\\s<]*?)<\\/span>"
		];
		case 703: return @[ // description
			@"<dd[^>]*>(.*?)<\\/dd>",
		];
		case 704: return @[ // date matcher
			@"(\\d{2}.\\d{2}.\\d{4})",
		];
		case 705: return @[ // date format
			@"dd.MM.yyyy",
			@"dd. MMM yyyy",
			@"yyyy-MM-dd'T'HH:mm:ssZZZZZ",
		];
		default: break;
	}
	return @[];
}

- (void)didClickExamplesButton:(NSButton*)sender {
	NSString *examples = [[self examplesFor:sender.tag] componentsJoinedByString:@"\n"];
	
	// TODO: clickable entries
	self.popoverText.stringValue = [NSString stringWithFormat:@"%@", examples];
	
	NSSize newSize = self.popoverText.fittingSize; // width is limited by the textfield's preferred width
	newSize.width += 2 * self.popoverText.frame.origin.x; // the padding
	newSize.height += 2 * self.popoverText.frame.origin.y;
	
	// apply fitting size and display
	self.infoPopover.contentSize = newSize;
	[self.infoPopover showRelativeToRect:NSZeroRect ofView:sender preferredEdge:NSRectEdgeMinY];
}

@end
