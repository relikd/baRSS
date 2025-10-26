#import "UserPrefs.h"
#import "NSString+Ext.h" // hexColor

/// Helper method for @c UserPrefsInit()
static inline void defaultsAppend(NSMutableDictionary *defs, id value, NSArray<NSString*>* keys) {
	for (NSString *key in keys)
		[defs setObject:value forKey:key];
}

/// Helper method calls @c (standardUserDefaults)registerDefaults:
void UserPrefsInit(void) {
	NSMutableDictionary *defs = [NSMutableDictionary dictionary];
	defaultsAppend(defs, @YES, @[
		Pref_globalTintMenuIcon,
		Pref_globalUpdateAll,
		Pref_globalOpenUnread,  Pref_groupOpenUnread,  Pref_feedOpenUnread,
		Pref_globalMarkRead,    Pref_groupMarkRead,    Pref_feedMarkRead,
		Pref_globalMarkUnread,  Pref_groupMarkUnread,  Pref_feedMarkUnread,
		Pref_globalUnreadCount, Pref_groupUnreadCount, Pref_feedUnreadCount,
		Pref_feedUnreadIndicator
	]);
	defaultsAppend(defs, @NO, @[
		Pref_globalUnreadOnly,  Pref_groupUnreadOnly,  Pref_feedUnreadOnly,
		Pref_groupUnreadIndicator,
		Pref_feedTruncateTitle,
		Pref_feedLimitArticles
	]);
	// Display limits & truncation  ( defaults write de.relikd.baRSS {KEY} -int 10 )
	[defs setObject:[NSNumber numberWithUnsignedInteger:10] forKey:Pref_openFewLinksLimit];
	[defs setObject:[NSNumber numberWithUnsignedInteger:60] forKey:Pref_shortArticleNamesLimit];
	[defs setObject:[NSNumber numberWithUnsignedInteger:40] forKey:Pref_articlesInMenuLimit];
	[defs setObject:[NSNumber numberWithUnsignedInteger:1] forKey:Pref_prefSelectedTab]; // feed tab
	[[NSUserDefaults standardUserDefaults] registerDefaults:defs];
}

/// @return User set value. If it wasn't modified or couldn't be parsed return @c defaultColor
NSColor* UserPrefsColor(NSString *key, NSColor *defaultColor) {
	NSString *colorStr = [[NSUserDefaults standardUserDefaults] stringForKey:key];
	if (colorStr) {
		NSColor *color = [colorStr hexColor];
		if (color) return color;
		NSLog(@"Error reading defaults '%@'. Hex color '%@' is invalid. It should be of the form #RBG or #RRGGBB.", key, colorStr);
		[[NSUserDefaults standardUserDefaults] removeObjectForKey:key];
	}
	return defaultColor;
}

/// Convert stored notification type string into enum
NotificationType UserPrefsNotificationType(void) {
	NSString *typ = UserPrefsString(Pref_notificationType);
	if ([typ isEqualToString:@"article"]) return NotificationTypePerArticle;
	if ([typ isEqualToString:@"feed"])    return NotificationTypePerFeed;
	if ([typ isEqualToString:@"global"])  return NotificationTypeGlobal;
	return NotificationTypeDisabled;
}

/// Convert enum type to storable string
NSString* NotificationTypeToString(NotificationType typ) {
	switch (typ) {
		case NotificationTypeDisabled:   return nil;
		case NotificationTypePerArticle: return @"article";
		case NotificationTypePerFeed:    return @"feed";
		case NotificationTypeGlobal:     return @"global";
	}
}
