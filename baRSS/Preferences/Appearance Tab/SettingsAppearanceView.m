#import "SettingsAppearanceView.h"
#import "NSView+Ext.h"
#import "Constants.h" // column icons
#import "UserPrefs.h" // preference constants & UserPrefsBool()
#import "DrawImage.h" // DrawSeparator

@interface FlippedView : NSView @end
@implementation FlippedView
- (BOOL)isFlipped { return YES; }
@end


@interface SettingsAppearanceView()
@property (assign) CGFloat y;
@property (assign) NSView *content;
@property (strong) NSMutableArray<NSString*> *columns;
@end

/***/ static CGFloat const IconSize = 18;
/***/ static CGFloat const colWidth = (IconSize + PAD_M); // checkbox column width
/***/ static CGFloat const X___ = PAD_WIN + 0 * colWidth;
/***/ static CGFloat const _X__ = PAD_WIN + 1 * colWidth;
/***/ static CGFloat const __X_ = PAD_WIN + 2 * colWidth;
/***/ static CGFloat const ___X = PAD_WIN + 3 * colWidth;
/***/ static CGFloat const lbl_start = PAD_WIN + 4 * colWidth;

@implementation SettingsAppearanceView

- (instancetype)init {
	self = [super initWithFrame:NSMakeRect(0, 0, 320, 327)];
	self.y = PAD_WIN;
	// stupidly complex UI generation just because you cant top-align `.documentView`
	NSScrollView *scroll = [[[FlippedView new] wrapInScrollView:self.frame.size] placeIn:self x:0 y:0];
	self.content = [[[NSView alloc] initWithFrame:scroll.documentView.frame] placeIn:scroll.documentView x:0 y:0];
	
	[self note:NSLocalizedString(@"Hover over the options for additional explanations and usage tips.", nil)];
	
	
	// Menu Buttons
	
	[self section:NSLocalizedString(@"Menu buttons", nil)];
	[self columns:@[
		RSSImageSettingsGlobalMenu, NSLocalizedString(@"Main menu", nil),
		RSSImageSettingsGroup, NSLocalizedString(@"Group menu", nil),
		RSSImageSettingsFeed, NSLocalizedString(@"Feed menu", nil),
	]];
	
	[self entry:NSLocalizedString(@"“Show hidden feeds”", nil)
		   help:NSLocalizedString(@"Show button to quickly toggle whether hidden articles should be shown. See option “Show only unread”.", nil)
			tip:NSLocalizedString(@"You can hold down option-key before opening the main menu to temporarily show hidden entries.", nil)
			 c1:Pref_globalToggleHidden c2:nil c3:nil c4:nil];
	
	[self entry:NSLocalizedString(@"“Update all feeds”", nil)
		   help:NSLocalizedString(@"Show button to reload all feeds. This will force fetch new online content regardless of next-update timer.", nil)
			tip:nil
			 c1:Pref_globalUpdateAll c2:nil c3:nil c4:nil];
	
	[self entry:NSLocalizedString(@"“Open all unread”", nil)
		   help:NSLocalizedString(@"Show button to open unread articles.", nil)
			tip:nil
			 c1:Pref_globalOpenUnread c2:Pref_groupOpenUnread c3:Pref_feedOpenUnread c4:nil];
	
	[self entry:NSLocalizedString(@"“Mark all read”", nil)
		   help:NSLocalizedString(@"Show button to mark articles read.", nil)
			tip:nil
			 c1:Pref_globalMarkRead c2:Pref_groupMarkRead c3:Pref_feedMarkRead c4:nil];
	
	[self entry:NSLocalizedString(@"“Mark all unread”", nil)
		   help:NSLocalizedString(@"Show button to mark articles unread.", nil)
			tip:NSLocalizedString(@"You can hold down option-key and click on an article to toggle that item (un-)read.", nil)
			 c1:Pref_globalMarkUnread c2:Pref_groupMarkUnread c3:Pref_feedMarkUnread c4:nil];
	
//	self.y += PAD_M;
	[self intInput:Pref_openFewLinksLimit
			  unit:NSLocalizedString(@"%ld unread", nil)
			 label:NSLocalizedString(@"“Open a few unread” ⌥", nil)
			  help:NSLocalizedString(@"If you hold down option-key, the “Open all unread” button becomes an “Open a few unread” button.", nil)];
	
//	self.y += PAD_M;
//	[self note:NSLocalizedString(@"Hold down option-key and click on an article to toggle that item (un-)read.", nil)];
	
	
	// Display options
	
	[self section:NSLocalizedString(@"Display options", nil)];
	[self columns:@[
		RSSImageSettingsGlobalIcon, NSLocalizedString(@"Menu bar icon", nil),
		RSSImageSettingsGroup, NSLocalizedString(@"Group menu item", nil),
		RSSImageSettingsFeed, NSLocalizedString(@"Feed menu item", nil),
		RSSImageSettingsArticle, NSLocalizedString(@"Article menu item", nil),
	]];
	
	[self entry:NSLocalizedString(@"Number of unread articles", nil)
		   help:NSLocalizedString(@"Show count of unread articles in parenthesis.", nil)
			tip:nil
			 c1:Pref_globalUnreadCount c2:Pref_groupUnreadCount c3:Pref_feedUnreadCount c4:nil];
	
	[self entry:NSLocalizedString(@"Color for unread articles", nil)
		   help:NSLocalizedString(@"Show color marker on menu items with unread articles.", nil)
			tip:nil
			 c1:Pref_globalTintMenuIcon c2:Pref_groupUnreadIndicator c3:Pref_feedUnreadIndicator c4:Pref_articleUnreadIndicator];
	
	[self entry:NSLocalizedString(@"Show only unread", nil)
		   help:NSLocalizedString(@"Hide articles which have been read.", nil)
			tip:nil
			 c1:nil c2:Pref_groupUnreadOnly c3:Pref_feedUnreadOnly c4:Pref_articleUnreadOnly];
	
//	self.y += PAD_M;
//	[self note:NSLocalizedString(@"Hold down option-key before opening the main menu to temporarily show hidden feeds.", nil)];
	
	
	// Other UI elements
	
	[self section:NSLocalizedString(@"Article display", nil)];
	
	[self intInput:Pref_articleCountLimit
			  unit:NSLocalizedString(@"%ld entries", nil)
			 label:NSLocalizedString(@"Limit number of articles", nil)
			  help:NSLocalizedString(@"Display at most X articles in feed menu. Remaining articles will be hidden from view but are still there. Unread count may be confusing because hidden articles are counted too.", nil)];
	
	[self intInput:Pref_articleTitleLimit
			  unit:NSLocalizedString(@"%ld chars", nil)
			 label:NSLocalizedString(@"Truncate article title", nil)
			  help:NSLocalizedString(@"Truncate article title after X characters. If a title is longer than that, show an ellipsis character “…”.", nil)];
	
	[self intInput:Pref_articleTooltipLimit
			  unit:NSLocalizedString(@"%ld chars", nil)
			 label:NSLocalizedString(@"Truncate article tooltip", nil)
			  help:NSLocalizedString(@"Truncate article tooltip after X characters. This tooltip shows the whole article content (if provided by the server).", nil)];
	
	self.y += PAD_WIN;
	
	// sest final view size
	[[self.content sizableWidth] setFrameSize:NSMakeSize(NSWidth(self.content.frame), self.y)];
	[[scroll.documentView sizableWidth] setFrame:self.content.frame];
	return self;
}


// MARK: - Section Header


- (void)section:(NSString*)title {
	self.y += PAD_L;
	NSTextField *label = [[[NSView label:title] placeIn:self.content x:PAD_WIN yTop:self.y] large];
//	[[DrawSeparator withSize:NSMakeSize(lbl_start - PAD_S, NSHeight(label.frame))] placeIn:self.content x:0 yTop:self.y]
//		.invert = YES;
	[[[DrawSeparator withSize:NSMakeSize(100, NSHeight(label.frame))] placeIn:self.content x:NSMaxX(label.frame) + PAD_S yTop:self.y] sizeToRight:0];
	self.y += NSHeight(label.frame) + PAD_M;
}


// MARK: - Column Icons


/// Helper method for matrix table header icons
- (void)columns:(NSArray<NSString*>*)columns {
	self.columns = [NSMutableArray arrayWithCapacity:4];
	for (NSUInteger i = 0; i < columns.count / 2; i++) {
		NSString *img = columns[i*2];
		NSString *ttip = columns[i*2 + 1];
		[[[NSView imageView:img size:IconSize] tooltip:ttip]
		 placeIn:self.content x:PAD_WIN + i * colWidth yTop:self.y]
			.accessibilityLabel = NSLocalizedString(@"Column header:", nil);
		[self.columns addObject:ttip ? ttip : @""];
	}
	self.y += HEIGHT_INPUTFIELD + PAD_S;
}


// MARK: - Notes


- (void)note:(NSString*)text {
	NSTextField *lbl = [[[NSView label:text] multiline:NSMakeSize(320 - 2*PAD_WIN, 7 * HEIGHT_LABEL)] gray];
	NSSize bestSize = [lbl sizeThatFits:lbl.frame.size];
	[lbl setFrameSize:bestSize];
	[[lbl placeIn:self.content x:PAD_WIN yTop:self.y] sizeToRight:PAD_WIN];
	self.y += NSHeight(lbl.frame);
}


// MARK: - Checkboxes

/// Helper method for generating a checkbox
static inline NSButton* Checkbox(SettingsAppearanceView *self, CGFloat x, NSString *key) {
	NSButton *check = [[NSView checkbox:UserPrefsBool(key)] placeIn:self.content x:x+2 yTop:self.y+2];
	check.identifier = key;
	return check;
}

/// Create new entry with 1-3 checkboxes and a descriptive label
- (NSTextField*)entry:(NSString*)label help:(NSString*)ttip tip:(NSString*)extraTip
				   c1:(NSString*)pref1 c2:(NSString*)pref2 c3:(NSString*)pref3 c4:(NSString*)pref4
{
	if (pref1) Checkbox(self, X___, pref1).accessibilityLabel = [NSString stringWithFormat:@"%@: %@", _columns[0], label];
	if (pref2) Checkbox(self, _X__, pref2).accessibilityLabel = [NSString stringWithFormat:@"%@: %@", _columns[1], label];
	if (pref3) Checkbox(self, __X_, pref3).accessibilityLabel = [NSString stringWithFormat:@"%@: %@", _columns[2], label];
	if (pref4) Checkbox(self, ___X, pref4).accessibilityLabel = [NSString stringWithFormat:@"%@: %@", _columns[3], label];
	if (extraTip != nil) {
		label = [label stringByAppendingString:@" 💡"];
		ttip = [ttip stringByAppendingFormat:@"\n\n💡 Tip: %@", extraTip];
	}
	NSTextField *lbl = [[[[NSView label:label] tooltip:ttip] placeIn:self.content x:lbl_start yTop:self.y] sizeToRight:PAD_WIN];
	self.y += (PAD_S + HEIGHT_LABEL);
	return lbl;
}


// MARK: - Int Input Field


/// Create input field for integer numbers
- (NSTextField*)intInput:(NSString*)pref unit:(NSString*)unit label:(NSString*)label help:(NSString*)ttip {
	// input field
	NSTextField *rv = [[NSView integerField:@"" unit:unit width:3 * colWidth + IconSize] placeIn:self.content x:PAD_WIN yTop:self.y];
	rv.placeholderString = NSLocalizedString(@"no limit", nil);
	// sadly, setting `accessibilityLabel` will break VoiceOver on empty input.
	// keep disabled so VoceOver will read the placeholder string if empty.
	rv.accessibilityLabel = label;
	rv.identifier = pref;
	rv.delegate = self;
	NSInteger val = UserPrefsInt(pref);
	if (val >= 0) {
		rv.stringValue = [NSString stringWithFormat:@"%ld", val];
	} else {
		rv.accessibilityValueDescription = rv.placeholderString;
	}
	// label
	[[[[NSView label:label] tooltip:ttip] placeIn:self.content x:lbl_start yTop:self.y + (HEIGHT_INPUTFIELD - HEIGHT_LABEL) / 2] sizeToRight:PAD_WIN];
	self.y += HEIGHT_INPUTFIELD + PAD_S;
	return rv;
}

- (void)controlTextDidEndEditing:(NSNotification *)obj {
	NSTextField *sender = obj.object;
	NSString *pref = sender.identifier;
	
	NSInteger newVal = sender.integerValue;
	BOOL isEmpty = newVal == 0 && sender.stringValue.length == 0;
	sender.accessibilityValueDescription = isEmpty ? sender.placeholderString : nil;
	UserPrefsSetInt(pref, isEmpty ? -1 : newVal);
	
	BOOL hitReturn = [[obj.userInfo valueForKey:NSTextMovementUserInfoKey] integerValue] == NSTextMovementReturn;
	if (hitReturn) {
		// Allow to deselect NSTextField (when pressing enter to confirm change)
		[self.window performSelector:@selector(makeFirstResponder:) withObject:nil afterDelay:0];
	}
}

// Allow to deselect all NSTextFields (via tab focus cycling)
// Also: opens view with no NSTextField selected.
- (BOOL)acceptsFirstResponder {
	return YES;
}

// Allow to deselect all NSTextFields (by clicking outside / somewhere on the window)
- (void)mouseDown:(NSEvent *)event {
	[self.window performSelector:@selector(makeFirstResponder:) withObject:nil afterDelay:0];
	// perform selector because otherwise it will raise an issue of different QoS levels
}

@end
