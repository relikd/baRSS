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

@implementation UserPrefs

/// @return @c YES if key is not set. Otherwise, return user defaults property from plist.
+ (BOOL)defaultYES:(NSString*)key {
	if ([[NSUserDefaults standardUserDefaults] objectForKey:key] == NULL) {
		return YES;
	}
	return [[NSUserDefaults standardUserDefaults] boolForKey:key];
}

/// @return @c NO if key is not set. Otherwise, return user defaults property from plist.
+ (BOOL)defaultNO:(NSString*)key {
	return [[NSUserDefaults standardUserDefaults] boolForKey:key];
}

/// @return User configured custom browser. Or @c nil if not set yet. (which will fallback to default browser)
+ (NSString*)getHttpApplication {
	return [[NSUserDefaults standardUserDefaults] stringForKey:@"defaultHttpApplication"];
}

/// Store custom browser bundle id to user defaults.
+ (void)setHttpApplication:(NSString*)bundleID {
	[[NSUserDefaults standardUserDefaults] setObject:bundleID forKey:@"defaultHttpApplication"];
}

@end
