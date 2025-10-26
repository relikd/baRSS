#import "SettingsGeneralView.h"
#import "SettingsGeneral.h"
#import "NSView+Ext.h"

@implementation SettingsGeneralView

- (instancetype)initWithController:(SettingsGeneral*)controller {
	self = [super initWithFrame:NSMakeRect(0, 0, 320, 327)];
	
	// Change default feed reader application
	NSTextField *l1 = [[NSView label:NSLocalizedString(@"Default feed reader:", nil)] placeIn:self x:PAD_WIN yTop:PAD_WIN + 3];
	NSButton *help = [[[NSView helpButton] action:@selector(clickHowToDefaults:) target:controller] placeIn:self xRight:PAD_WIN yTop:PAD_WIN];
	self.defaultReader = [[[[NSView label:@""] bold] placeIn:self x:NSMaxX(l1.frame) + PAD_S yTop:PAD_WIN + 3] sizeToRight:NSWidth(help.frame) + PAD_WIN];
	
	// Popup button 'Open URLs with:'
	CGFloat y = YFromTop(help) + PAD_M;
	NSTextField *l2 = [[NSView label:NSLocalizedString(@"Open URLs with:", nil)] placeIn:self x:PAD_WIN yTop:y + 1];
	self.popupHttpApplication = [[[[NSView popupButton:0] placeIn:self x:NSMaxX(l2.frame) + PAD_S yTop:y] sizeToRight:PAD_WIN]
								 action:@selector(changeHttpApplication:) target:controller];
	
	// Notification type
	y = YFromTop(self.popupHttpApplication) + PAD_M;
	NSTextField *l3 = [[NSView label:NSLocalizedString(@"Notifications:", nil)] placeIn:self x:PAD_WIN yTop:y + 1];
	self.popupNotificationType = [[[[NSView popupButton:0] placeIn:self x:NSMaxX(l3.frame) + PAD_S yTop:y] sizeToRight:PAD_WIN]
								  action:@selector(changeNotificationType:) target:controller];
	
	// Notification help text
	y = YFromTop(self.popupNotificationType) + PAD_M;
	self.notificationHelp = [[[[[NSView label:@""] gray]
							   multiline:NSMakeSize(320 - 2*PAD_WIN, HEIGHT_LABEL * 5)]
							  placeIn:self x:PAD_WIN yTop:y] sizeToRight:PAD_WIN];
	return self;
}

@end
