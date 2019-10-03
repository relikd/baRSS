//
//  The MIT License (MIT)
//  Copyright (c) 2019 Oleg Geier
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

#import "SettingsAboutView.h"
#import "NSView+Ext.h"

@implementation SettingsAboutView

- (instancetype)init {
	self = [super initWithFrame: NSZeroRect];
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
	[self str:mas add:@"Oleg Geier\n\n" bold:NO];
	[self str:mas add:@"Source Code Available\n" bold:YES];
	[self str:mas add:@"github.com" link:@"https://github.com/relikd/baRSS"];
	[self str:mas add:@" (MIT License)\nor " bold:NO];
	[self str:mas add:@"gitlab.com" link:@"https://gitlab.com/relikd/baRSS"];
	[self str:mas add:@" (MIT License)\n\n" bold:NO];
	[self str:mas add:@"3rd-Party Libraries\n" bold:YES];
	[self str:mas add:@"RSXML2" link:@"https://github.com/relikd/RSXML2"];
	[self str:mas add:@" (MIT License)" bold:NO];
	[self str:mas add:@"\n\n\n\nOptions\n" bold:YES];
	[self str:mas add:@"Fix Cache\n" link:@"barss:config/fixcache"];
	[self str:mas add:@"Backup now\n" link:@"barss:backup/show"];
	[mas endEditing];
	return mas;
}

/// Helper method to insert attributed (bold) text
- (void)str:(NSMutableAttributedString*)parent add:(NSString*)text bold:(BOOL)flag {
	NSFont *font = [NSFont systemFontOfSize:NSFont.systemFontSize weight:(flag ? NSFontWeightMedium : NSFontWeightLight)];
	[parent appendAttributedString:[[NSAttributedString alloc] initWithString:NonLocalized(text) attributes:@{ NSFontAttributeName : font }]];
}

/// Helper method to insert attributed hyperlink text
- (void)str:(NSMutableAttributedString*)parent add:(NSString*)text link:(NSString*)url {
	[self str:parent add:text bold:NO];
	[parent addAttribute:NSLinkAttributeName value:url range:NSMakeRange(parent.length - text.length, text.length)];
}

__attribute__((annotate("returns_localized_nsstring")))
static inline NSString *NonLocalized(NSString *s) { return s; }

@end
