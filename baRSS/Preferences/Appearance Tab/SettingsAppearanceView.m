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
#import "Constants.h" // column icons
#import "UserPrefs.h" // preference constants & UserPrefsBool()

@interface SettingsAppearanceView()
@property (assign) CGFloat y;
@end

/***/ static CGFloat const IconSize = 18;
/***/ static CGFloat const colWidth = (IconSize + PAD_M); // checkbox column width
/***/ static CGFloat const X__ = PAD_WIN + 0 * colWidth;
/***/ static CGFloat const _X_ = PAD_WIN + 1 * colWidth;
/***/ static CGFloat const __X = PAD_WIN + 2 * colWidth;

@implementation SettingsAppearanceView

- (instancetype)init {
	self = [super initWithFrame: NSZeroRect];
	// Insert matrix header (icons above checkbox matrix)
	ColumnIcon(self, X__, RSSImageSettingsGlobal, NSLocalizedString(@"Show in menu bar", nil));
	ColumnIcon(self, _X_, RSSImageSettingsGroup, NSLocalizedString(@"Show in group menu", nil));
	ColumnIcon(self, __X, RSSImageSettingsFeed, NSLocalizedString(@"Show in feed menu", nil));
	// Generate checkbox matrix
	self.y = PAD_WIN + IconSize + PAD_S;
	[self entry:NSLocalizedString(@"Tint menu bar icon on unread", nil) c1:Pref_globalTintMenuIcon c2:nil c3:nil];
	[self entry:NSLocalizedString(@"Update all feeds", nil) c1:Pref_globalUpdateAll c2:nil c3:nil];
	[self entry:NSLocalizedString(@"Open all unread", nil) c1:Pref_globalOpenUnread c2:Pref_groupOpenUnread c3:Pref_feedOpenUnread];
	[self entry:NSLocalizedString(@"Mark all read", nil) c1:Pref_globalMarkRead c2:Pref_groupMarkRead c3:Pref_feedMarkRead];
	[self entry:NSLocalizedString(@"Mark all unread", nil) c1:Pref_globalMarkUnread c2:Pref_groupMarkUnread c3:Pref_feedMarkUnread];
	[self entry:NSLocalizedString(@"Number of unread articles", nil) c1:Pref_globalUnreadCount c2:Pref_groupUnreadCount c3:Pref_feedUnreadCount];
	[self entry:NSLocalizedString(@"Indicator for unread articles", nil) c1:nil c2:Pref_groupUnreadIndicator c3:Pref_feedUnreadIndicator];
	[[self entry:NSLocalizedString(@"Truncate article title", nil) c1:nil c2:nil c3:Pref_feedTruncateTitle]
	 tooltip:NSLocalizedString(@"Truncate article title after 60 characters", nil)];
	[[self entry:NSLocalizedString(@"Limit number of articles", nil) c1:nil c2:nil c3:Pref_feedLimitArticles]
	 tooltip:NSLocalizedString(@"Display at most 40 articles in feed menu", nil)];
	return self;
}

/// Helper method for matrix table header icons
static inline void ColumnIcon(id this, CGFloat x, const NSImageName img, NSString *ttip) {
	[[[NSView imageView:img size:IconSize] placeIn:this x:x yTop:PAD_WIN] tooltip:ttip];
}

/// Helper method for generating a checkbox
static inline NSButton* Checkbox(id this, CGFloat x, CGFloat y, NSString *key) {
	NSButton *check = [[NSView checkbox: UserPrefsBool(key)] placeIn:this x:x yTop:y];
	check.identifier = key;
	return check;
}

/// Create new entry with 1-3 checkboxes and a descriptive label
- (NSTextField*)entry:(NSString*)label c1:(NSString*)pref1 c2:(NSString*)pref2 c3:(NSString*)pref3 {
	CGFloat y = self.y;
	self.y += (PAD_S + HEIGHT_LABEL);
	// TODO: localize: global, group, feed
	if (pref1) Checkbox(self, X__ + 2, y + 2, pref1).accessibilityLabel = [label stringByAppendingString:@" (global)"];
	if (pref2) Checkbox(self, _X_ + 2, y + 2, pref2).accessibilityLabel = [label stringByAppendingString:@" (group)"];
	if (pref3) Checkbox(self, __X + 2, y + 2, pref3).accessibilityLabel = [label stringByAppendingString:@" (feed)"];
	return [[[NSView label:label] placeIn:self x:PAD_WIN + 3 * colWidth yTop:y] sizeToRight:PAD_WIN];
}

@end
