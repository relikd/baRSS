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
	ColumnIcon(self, X__, RSSImageSettingsGlobalMenu);
	ColumnIcon(self, _X_, RSSImageSettingsGroup);
	ColumnIcon(self, __X, RSSImageSettingsFeed);
	// Generate checkbox matrix
	self.y = PAD_WIN + IconSize + PAD_S;
	[self entry:NSLocalizedString(@"Tint menu bar icon on unread", nil)
		   help:NSLocalizedString(@"If active, a color will indicate if there are unread articles.", nil)
			tip:nil
			 c1:Pref_globalTintMenuIcon c1tt:NSLocalizedString(@"menu bar icon", nil)
			 c2:nil c2tt:nil
			 c3:nil c3tt:nil];
	
	[self entry:NSLocalizedString(@"Update all feeds", nil)
		   help:NSLocalizedString(@"Show button in main menu to reload all feeds. This will force fetch new online content regardless of next-update timer.", nil)
			tip:nil
			 c1:Pref_globalUpdateAll c1tt:NSLocalizedString(@"in main menu", nil)
			 c2:nil c2tt:nil
			 c3:nil c3tt:nil];
	
	[self entry:NSLocalizedString(@"Toggle “Show hidden articles”", nil)
		   help:NSLocalizedString(@"Show button in main menu to quickly toggle whether hidden articles should be shown. See option “Show only unread”.", nil)
			tip:nil
			 c1:Pref_globalToggleHidden c1tt:NSLocalizedString(@"in main menu", nil)
			 c2:nil c2tt:nil
			 c3:nil c3tt:nil];
	
	[self entry:NSLocalizedString(@"Open all unread", nil)
		   help:NSLocalizedString(@"Show button to open unread articles.", nil)
			tip:NSLocalizedString(@"If you hold down option-key, this will become an “open a few” unread articles button.", nil)
			 c1:Pref_globalOpenUnread c1tt: NSLocalizedString(@"in main menu", nil)
			 c2:Pref_groupOpenUnread c2tt: NSLocalizedString(@"in group menu", nil)
			 c3:Pref_feedOpenUnread c3tt: NSLocalizedString(@"in feed menu", nil)];
	
	[self entry:NSLocalizedString(@"Mark all read", nil)
		   help:NSLocalizedString(@"Show button to mark articles read.", nil)
			tip:nil
			 c1:Pref_globalMarkRead c1tt: NSLocalizedString(@"in main menu", nil)
			 c2:Pref_groupMarkRead c2tt: NSLocalizedString(@"in group menu", nil)
			 c3:Pref_feedMarkRead c3tt: NSLocalizedString(@"in feed menu", nil)];
	
	[self entry:NSLocalizedString(@"Mark all unread", nil)
		   help:NSLocalizedString(@"Show button to mark articles unread.", nil)
			tip:NSLocalizedString(@"You can hold down option-key and click on an article to toggle that item (un-)read.", nil)
			 c1:Pref_globalMarkUnread c1tt: NSLocalizedString(@"in main menu", nil)
			 c2:Pref_groupMarkUnread c2tt: NSLocalizedString(@"in group menu", nil)
			 c3:Pref_feedMarkUnread c3tt: NSLocalizedString(@"in feed menu", nil)];
	
	[self entry:NSLocalizedString(@"Number of unread articles", nil)
		   help:NSLocalizedString(@"Show count of unread articles in parenthesis.", nil)
			tip:nil
			 c1:Pref_globalUnreadCount c1tt:NSLocalizedString(@"on menu bar icon", nil)
			 c2:Pref_groupUnreadCount c2tt:NSLocalizedString(@"on group folder", nil)
			 c3:Pref_feedUnreadCount c3tt:NSLocalizedString(@"on feed folder", nil)];
	
	[self entry:NSLocalizedString(@"Indicator for unread articles", nil)
		   help:NSLocalizedString(@"Show blue dot on menu items with unread articles.", nil)
			tip:nil
			 c1:nil c1tt:nil
			 c2:Pref_groupUnreadIndicator c2tt:NSLocalizedString(@"on group & feed folder", nil)
			 c3:Pref_feedUnreadIndicator c3tt:NSLocalizedString(@"on article entry", nil)];
	
	[self entry:NSLocalizedString(@"Show only unread", nil)
		   help:NSLocalizedString(@"Hide articles which have been read.", nil)
			tip:NSLocalizedString(@"You can hold down option-key before opening the main menu to temporarily disable this setting.", nil)
			 c1:nil c1tt:nil
			 c2:Pref_groupUnreadOnly c2tt:NSLocalizedString(@"hide group & feed folders with 0 unread articles", nil)
			 c3:Pref_feedUnreadOnly c3tt:NSLocalizedString(@"hide articles inside of feed folder", nil)];
	
	[self entry:NSLocalizedString(@"Truncate article title", nil)
		   help:NSLocalizedString(@"Truncate article title after 60 characters. If a title is longer than that, show an ellipsis character “…” instead.", nil)
			tip:nil
			 c1:nil c1tt:nil
			 c2:nil c2tt:nil
			 c3:Pref_feedTruncateTitle c3tt:NSLocalizedString(@"article title", nil)];
	
	[self entry:NSLocalizedString(@"Limit number of articles", nil)
		   help:NSLocalizedString(@"Display at most 40 articles in feed menu. Remaining articles will be hidden from view but are still there. Unread count may be confusing as it will also count unread and hidden articles.", nil)
			tip:nil
			 c1:nil c1tt:nil
			 c2:nil c2tt:nil
			 c3:Pref_feedLimitArticles c3tt:NSLocalizedString(@"in feed menu", nil)];
	
	[[[[[NSView label:@"Note: you can hover over all options to display explanatory tooltips."]
		multiline:NSMakeSize(100, 2 * HEIGHT_LABEL)] gray]
	  placeIn:self x:PAD_WIN yTop:self.y + PAD_L] sizeToRight:PAD_WIN];
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
- (NSTextField*)entry:(NSString*)label help:(NSString*)ttip tip:(NSString*)extraTip
				   c1:(NSString*)pref1 c1tt:(NSString*)ttip1
				   c2:(NSString*)pref2 c2tt:(NSString*)ttip2
				   c3:(NSString*)pref3 c3tt:(NSString*)ttip3
{
	CGFloat y = self.y;
	self.y += (PAD_S + HEIGHT_LABEL);
	// TODO: localize: global, group, feed
	if (pref1) [Checkbox(self, X__ + 2, y + 2, pref1) tooltip:ttip1].accessibilityLabel = [label stringByAppendingString:@" (global)"];
	if (pref2) [Checkbox(self, _X_ + 2, y + 2, pref2) tooltip:ttip2].accessibilityLabel = [label stringByAppendingString:@" (group)"];
	if (pref3) [Checkbox(self, __X + 2, y + 2, pref3) tooltip:ttip3].accessibilityLabel = [label stringByAppendingString:@" (feed)"];
	if (extraTip != nil) {
		label = [label stringByAppendingString:@" *"];
		ttip = [ttip stringByAppendingFormat:@"\n\n* Tip: %@", extraTip];
	}
	return [[[[NSView label:label] placeIn:self x:PAD_WIN + 3 * colWidth yTop:y] sizeToRight:PAD_WIN] tooltip:ttip];
}

@end
