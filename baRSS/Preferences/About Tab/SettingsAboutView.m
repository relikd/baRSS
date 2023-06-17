#import "SettingsAboutView.h"
#import "NSView+Ext.h"

@implementation SettingsAboutView

- (instancetype)init {
	self = [super initWithFrame:NSMakeRect(0, 0, 320, 327)];
	NSDictionary *info = [[NSBundle mainBundle] infoDictionary];
	NSString *version = [NSString stringWithFormat:NSLocalizedString(@"Version %@", nil), info[@"CFBundleShortVersionString"]];
#if DEBUG // append build number, e.g., '0.9.4 (9906)'
	version = [version stringByAppendingFormat:@" (%@)", info[@"CFBundleVersion"]];
#endif
	
	// Application icon image (top-centered)
	NSImageView *logo = [[NSView imageView:NSImageNameApplicationIcon size:64] placeIn:self x:CENTER yTop:PAD_M];
	// Add app name
	NSTextField *lblN = [[[[NSView label:APP_NAME] large] bold] placeIn:self x:CENTER yTop: YFromTop(logo) + PAD_M];
	// Add version info
	NSTextField *lblV = [[[[NSView label:version] small] selectable] placeIn:self x:CENTER yTop: YFromTop(lblN) + PAD_S];
	
	// Add rtf document
	NSTextView *tv = [[NSTextView new] sizableWidthAndHeight];
	tv.textContainerInset = NSMakeSize(0, 15);
	tv.alignment = NSTextAlignmentCenter;
	tv.editable = NO; // but selectable
	[tv.textStorage setAttributedString:[self rtfDocument]];
	[self wrapContent:tv inScrollView:NSMakeRect(-1, 20, NSWidth(self.frame) + 2, NSMinY(lblV.frame) - PAD_M - 20)];
	return self;
}

/// Construct attributed string by concatenating snippets of text.
- (NSMutableAttributedString*)rtfDocument {
	NSMutableAttributedString *mas = [NSMutableAttributedString new];
	[mas beginEditing];
	[self str:mas add:@"Programming\n" bold:YES];
	[self str:mas add:@"Oleg Geier\n" bold:NO];
	[self str:mas add:@"\nSource Code Available\n" bold:YES];
	[self str:mas add:@"github.com" link:@"https://github.com/relikd/baRSS"];
	[self str:mas add:@" (MIT License)\n" bold:NO];
	[self str:mas add:@"\nLibraries\n" bold:YES];
	[self str:mas add:@"RSXML2" link:@"https://github.com/relikd/RSXML2"];
	[self str:mas add:@" (MIT License)\n" bold:NO];
	[self str:mas add:@"QLOPML" link:@"https://github.com/relikd/QLOPML"];
	[self str:mas add:@" (MIT License)\n" bold:NO];
	[self str:mas add:@"\n\n\nOptions\n" bold:YES];
	[self str:mas add:@"Fix Cache\n" link:@"barss:config/fixcache"];
	[self str:mas add:@"Backup now\n" link:@"barss:backup/show"];
	[mas endEditing];
	return mas;
}

/// Helper method to insert attributed (bold) text
- (void)str:(NSMutableAttributedString*)parent add:(NSString*)text bold:(BOOL)flag {
	NSFont *font = [NSFont systemFontOfSize:NSFont.systemFontSize weight:(flag ? NSFontWeightMedium : NSFontWeightLight)];
	NSDictionary *style = @{ NSFontAttributeName: font, NSForegroundColorAttributeName: [NSColor controlTextColor] };
	[parent appendAttributedString:[[NSAttributedString alloc] initWithString:NonLocalized(text) attributes:style]];
}

/// Helper method to insert attributed hyperlink text
- (void)str:(NSMutableAttributedString*)parent add:(NSString*)text link:(NSString*)url {
	[self str:parent add:text bold:NO];
	[parent addAttribute:NSLinkAttributeName value:url range:NSMakeRange(parent.length - text.length, text.length)];
}

__attribute__((annotate("returns_localized_nsstring")))
static inline NSString *NonLocalized(NSString *s) { return s; }

@end
