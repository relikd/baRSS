//
//  The MIT License (MIT)
//  Copyright (c) 2018 Oleg Geier
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
	defaultsAppend(defs, @YES, @[Pref_globalTintMenuIcon,
								 Pref_globalUpdateAll,
								 Pref_globalOpenUnread,  Pref_groupOpenUnread,  Pref_feedOpenUnread,
								 Pref_globalMarkRead,    Pref_groupMarkRead,    Pref_feedMarkRead,
								 Pref_globalMarkUnread,  Pref_groupMarkUnread,  Pref_feedMarkUnread,
								 Pref_globalUnreadCount, Pref_groupUnreadCount, Pref_feedUnreadCount,
								 Pref_feedUnreadIndicator]);
	defaultsAppend(defs, @NO, @[Pref_feedTruncateTitle,
								Pref_feedLimitArticles]);
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
