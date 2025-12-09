#import "ModalFeedEditView.h"
#import "ModalFeedEdit.h"
#import "NSView+Ext.h"
#import "Constants.h"


@implementation ModalFeedEditView

- (instancetype)initWithController:(ModalFeedEdit*)controller {
	NSArray *lbls = @[NSLocalizedString(@"URL", nil),
					  NSLocalizedString(@"Name", nil),
					  NSLocalizedString(@"Refresh", nil)];
	NSView *labels = [NSView labelColumn:lbls rowHeight:HEIGHT_INPUTFIELD padding:PAD_S];
	
	
	self = [super initWithFrame:NSMakeRect(0, 0, 320, NSHeight(labels.frame))];
	self.autoresizingMask = NSViewWidthSizable | NSViewHeightSizable;
	
	CGFloat x = NSWidth(labels.frame) + PAD_S;
	static CGFloat const rowHeight = PAD_S + HEIGHT_INPUTFIELD;
	[labels placeIn:self x:0 yTop:0];
	
	// 1. row
	self.url = [[[NSView inputField:@"https://example.org/feed.rss" width:0] placeIn:self x:x yTop:0] sizeToRight:PAD_S + 18];
	self.spinnerURL = [[NSView activitySpinner] placeIn:self xRight:1 yTop:2.5];
	self.favicon = [[[NSView imageView:nil size:18] tooltip:NSLocalizedString(@"Favicon", nil)] placeIn:self xRight:0 yTop:1.5];
	self.warningButton = [[[[NSView buttonIcon:NSImageNameCaution size:18]
							action:@selector(didClickWarningButton:) target:nil] // up the responder chain
						   tooltip:NSLocalizedString(@"Click here to show failure reason", nil)]
						  placeIn:self xRight:0 yTop:1.5];
	// 2. row
	self.name = [[[NSView inputField:NSLocalizedString(@"Example Title", nil) width:0] placeIn:self x:x yTop:rowHeight] sizeToRight:PAD_S + 18];
	self.spinnerName = [[NSView activitySpinner] placeIn:self xRight:1 yTop:rowHeight + 2.5];
	// 3. row
	self.refreshNum = [[NSView integerField:30 width:85] placeIn:self x:x yTop:2*rowHeight];
	self.refreshUnit = [[NSView popupButton:120] placeIn:self x:NSMaxX(self.refreshNum.frame) + PAD_M yTop:2*rowHeight];
	self.regexConverterButton = [[[[NSView buttonIcon:RSSImageRegexIcon size:19]
								   action:@selector(openRegexConverter) target:controller]
								  tooltip:NSLocalizedString(@"Regex converter", nil)]
								 placeIn:self xRight:0 yTop:2*rowHeight + 1];
	
	// initial state
	self.url.accessibilityLabel = lbls[0];
	self.name.accessibilityLabel = lbls[1];
	self.refreshNum.accessibilityLabel = NSLocalizedString(@"Refresh interval", nil);
	self.url.delegate = controller;
	self.warningButton.hidden = YES;
	self.regexConverterButton.hidden = YES;
	[self prepareWarningPopover];
	return self;
}

/// Prepare popover controller to display errors during download
- (void)prepareWarningPopover {
	self.warningPopover = [NSView popover: NSMakeSize(300, 100)];
	NSView *content = self.warningPopover.contentViewController.view;
	// User visible error description text (after click on warning button)
	self.warningText = [[[[[NSView label:@""] selectable] sizableWidthAndHeight]
						multiline:NSMakeSize(292, 96)] placeIn:content x:4 y:2];
	// Reload button is only visible on 5xx server error (right of ––––)
	self.warningReload = [[[[NSView buttonIcon:NSImageNameRefreshTemplate size:16] placeIn:content x:35 yTop:21]
						   tooltip:NSLocalizedString(@"Retry download (⌘R)", nil)]
						  action:@selector(reloadData) target:nil]; // up the responder chain
}

@end
