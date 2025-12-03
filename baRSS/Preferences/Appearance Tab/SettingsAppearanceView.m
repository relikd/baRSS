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
	self = [super initWithFrame:NSMakeRect(0, 0, 320, 327)];
	// Insert matrix header (icons above checkbox matrix)
	ColumnIcon(self, X__, RSSImageSettingsGlobal);
	ColumnIcon(self, _X_, RSSImageSettingsGroup);
	ColumnIcon(self, __X, RSSImageSettingsFeed);
	// Generate checkbox matrix
	self.y = PAD_WIN + IconSize + PAD_S;
	[[self entry:NSLocalizedString(@"Tint menu bar icon on unread", nil)
			  c1:Pref_globalTintMenuIcon c2:nil c3:nil]
	 tooltip:NSLocalizedString(@"If active, a color will indicate if there are unread articles.", nil)];
	
	[[self entry:NSLocalizedString(@"Update all feeds", nil)
			  c1:Pref_globalUpdateAll c2:nil c3:nil]
	 tooltip:NSLocalizedString(@"Show a button in status bar menu to reload all feeds. This will force fetch new online content regardless of next-update timer.", nil)];
	
	[[self entry:NSLocalizedString(@"Open all unread", nil)
			  c1:Pref_globalOpenUnread c2:Pref_groupOpenUnread c3:Pref_feedOpenUnread]
	 tooltip:NSLocalizedString(@"Show a button to open unread articles. (globally / per group / per feed)\n\nIf you hold down option key, this will become an “open a few” unread articles button.", nil)];
	
	[[self entry:NSLocalizedString(@"Mark all read", nil)
			  c1:Pref_globalMarkRead c2:Pref_groupMarkRead c3:Pref_feedMarkRead]
	 tooltip:NSLocalizedString(@"Show a button to mark articles read. (globally / per group / per feed)", nil)];
	
	[[self entry:NSLocalizedString(@"Mark all unread", nil)
			  c1:Pref_globalMarkUnread c2:Pref_groupMarkUnread c3:Pref_feedMarkUnread]
	 tooltip:NSLocalizedString(@"Show a button to mark articles unread. (globally / per group / per feed)\n\nYou can hold down option key and click on an article to toggle that item (un-)read.", nil)];
	
	[[self entry:NSLocalizedString(@"Number of unread articles", nil)
			  c1:Pref_globalUnreadCount c2:Pref_groupUnreadCount c3:Pref_feedUnreadCount]
	 tooltip:NSLocalizedString(@"Show count of unread articles in parenthesis. (on menu bar icon / on group folder / on feed folder)", nil)];
	
	[[self entry:NSLocalizedString(@"Indicator for unread articles", nil)
			  c1:nil c2:Pref_groupUnreadIndicator c3:Pref_feedUnreadIndicator]
	 tooltip:NSLocalizedString(@"Show blue dot on menu items with unread articles. (on group & feed folder / on article entry)", nil)];
	
	[[self entry:NSLocalizedString(@"Show only unread", nil)
			  c1:nil c2:Pref_groupUnreadOnly c3:Pref_feedUnreadOnly]
	 tooltip:NSLocalizedString(@"Hide articles which have been read. (hide group & feed folders / hide articles inside of feed folder)", nil)];
	
	[[self entry:NSLocalizedString(@"Truncate article title", nil)
			  c1:nil c2:nil c3:Pref_feedTruncateTitle]
	 tooltip:NSLocalizedString(@"Truncate article title after 60 characters. If a title is longer than that, show an ellipsis character “…” instead.", nil)];
	
	[[self entry:NSLocalizedString(@"Limit number of articles", nil)
			  c1:nil c2:nil c3:Pref_feedLimitArticles]
	 tooltip:NSLocalizedString(@"Display at most 40 articles in feed menu. Remaining articles will be hidden from view but are still there. Unread count may be confusing as it will also count unread and hidden articles.", nil)];
	return self;
}

/// Helper method for matrix table header icons
static inline void ColumnIcon(id this, CGFloat x, const NSImageName img) {
	[[NSView imageView:img size:IconSize] placeIn:this x:x yTop:PAD_WIN];
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
