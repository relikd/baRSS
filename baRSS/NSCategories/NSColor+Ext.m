//
//  The MIT License (MIT)
//  Copyright (c) 2020 Oleg Geier
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
			color = UserPrefsColor(Pref_colorStatusIconTint, [NSColor controlAccentColor]);
		} else {
			color = UserPrefsColor(Pref_colorStatusIconTint, [NSColor systemBlueColor]);
		}
	});
	return color;
}

@end
