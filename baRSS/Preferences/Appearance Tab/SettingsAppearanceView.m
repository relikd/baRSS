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

#import "SettingsAppearanceView.h"
#import "NSView+Ext.h"
#import "DrawImage.h"
#import "UserPrefs.h"

@interface SettingsAppearanceView()
@property (assign) NSUInteger row;
@end


/***/ static const CGFloat IconSize = 18;
/***/ static const CGFloat colWidth = (IconSize + PAD_M); // checkbox column width


@implementation SettingsAppearanceView

- (instancetype)init {
	self = [super initWithFrame: NSZeroRect];
	self.row = 0;
	// Insert matrix header (the three icons)
	[self head:0 tooltip:NSLocalizedString(@"Show in menu bar", nil) class:[SettingsIconGlobal class]];
	[self head:1 tooltip:NSLocalizedString(@"Show in group menu", nil) class:[SettingsIconGroup class]];
	[self head:2 tooltip:NSLocalizedString(@"Show in feed menu", nil) class:[RSSIcon class]];
	// Generate checkbox matrix (checkbox state, X: default ON, O: default OFF, blank: hidden)
	[self entry:"X  " label:NSLocalizedString(@"Tint menu bar icon on unread", nil)];
	[self entry:"X  " label:NSLocalizedString(@"Update all feeds", nil)];
	[self entry:"XXX" label:NSLocalizedString(@"Open all unread", nil)];
	[self entry:"XXX" label:NSLocalizedString(@"Mark all read", nil)];
	[self entry:"XXX" label:NSLocalizedString(@"Mark all unread", nil)];
	[self entry:"XXX" label:NSLocalizedString(@"Number of unread items", nil)];
	[self entry:"  X" label:NSLocalizedString(@"Tick mark unread items", nil)];
	[[self entry:"  O" label:NSLocalizedString(@"Short article names", nil)] tooltip:NSLocalizedString(@"Truncate article title after 60 characters", nil)];
	[[self entry:"  O" label:NSLocalizedString(@"Limit number of articles", nil)] tooltip:NSLocalizedString(@"Display at most 40 articles in feed menu", nil)];
	return self;
}

/// Helper method for matrix table header icons
- (void)head:(int)x tooltip:(NSString*)ttip class:(Class)cls {
	[[[[cls alloc] initWithFrame:NSMakeRect(0, 0, IconSize, IconSize)] tooltip:ttip] placeIn:self x:PAD_WIN + x * colWidth yTop:PAD_WIN];
}

/// Create new entry with 1-3 checkboxes and a descriptive label
- (NSTextField*)entry:(char*)m label:(NSString*)text {
	static const char* scope[] = { "global", "group", "feed" };
	static const char* ident[] = { "TintMenuBarIcon", "UpdateAll", "OpenUnread", "MarkRead", "MarkUnread", "UnreadCount", "TickMark", "ShortNames", "LimitArticles" };
	CGFloat y = PAD_WIN + IconSize + PAD_S + self.row * (PAD_S + HEIGHT_LABEL);
	
	// Add checkboxes: row 0 - 8, col 0 - 2
	for (NSUInteger col = 0; col < 3; col++) {
		NSString *key = [NSString stringWithFormat:@"%s%s", scope[col], ident[self.row]];
		BOOL state;
		switch (m[col]) {
			case 'X': state = [UserPrefs defaultYES:key]; break;
			case 'O': state = [UserPrefs defaultNO: key]; break;
			default: continue; // ignore blanks
		}
		NSButton *check = [[NSView checkbox:state] placeIn:self x:PAD_WIN + col * colWidth + 2 yTop:y + 2]; // 2px checkbox offset
		check.identifier = key;
		check.accessibilityLabel = [text stringByAppendingFormat:@" (%s)", scope[col]]; // TODO: localize: global, group, feed
	}
	self.row += 1;
	// Add label
	return [[[NSView label:text] placeIn:self x:PAD_WIN + 3 * colWidth yTop:y] sizeToRight:PAD_WIN];
}

@end
