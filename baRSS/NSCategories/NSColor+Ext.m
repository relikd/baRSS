#import "NSColor+Ext.h"
#import "UserPrefs.h"

@implementation NSColor (Ext)

+ (instancetype)rssOrange {
	static NSColor *color;
	static dispatch_once_t onceToken;
	dispatch_once(&onceToken, ^{
		color = [NSColor colorWithCalibratedRed:251/255.f green:163/255.f blue:58/255.f alpha:1.f]; // #FBA33A
	});
	return color;
}

+ (instancetype)menuBarIconColor {
	static NSColor *color;
	static dispatch_once_t onceToken;
	dispatch_once(&onceToken, ^{
		if (@available(macOS 10.14, *)) {
			color = UserPrefsColor(Pref_colorStatusIconTint, [NSColor controlAccentColor]);
		} else {
			color = UserPrefsColor(Pref_colorStatusIconTint, [self rssOrange]);
		}
	});
	return color;
}

+ (instancetype)unreadIndicatorColor {
	static NSColor *color;
	static dispatch_once_t onceToken;
	dispatch_once(&onceToken, ^{
		if (@available(macOS 10.14, *)) {
			color = UserPrefsColor(Pref_colorUnreadIndicator, [NSColor controlAccentColor]);
		} else {
			color = UserPrefsColor(Pref_colorUnreadIndicator, [NSColor systemBlueColor]);
		}
	});
	return color;
}

@end
