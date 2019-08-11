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
#import "StoreCoordinator.h"

@implementation UserPrefs

#pragma mark - User Preferences Plist

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

/// @return Return @c defaultInt if key is not set. Otherwise, return user defaults property from plist.
+ (NSInteger)defaultInt:(NSInteger)defaultInt forKey:(NSString*)key {
	NSInteger ret = [[NSUserDefaults standardUserDefaults] integerForKey:key];
	if (ret > 0) return ret;
	return defaultInt;
}

/// @return User configured custom browser. Or @c nil if not set yet. (which will fallback to default browser)
+ (NSString*)getHttpApplication {
	return [[NSUserDefaults standardUserDefaults] stringForKey:@"defaultHttpApplication"];
}

/// Store custom browser bundle id to user defaults.
+ (void)setHttpApplication:(NSString*)bundleID {
	[[NSUserDefaults standardUserDefaults] setObject:bundleID forKey:@"defaultHttpApplication"];
}

/**
 Open web links in default browser or a browser the user selected in the preferences.
 
 @param urls A list of @c NSURL objects that will be opened immediatelly in bulk.
 @return @c YES if @c urls are opened successfully. @c NO on error.
 */
+ (BOOL)openURLsWithPreferredBrowser:(NSArray<NSURL*>*)urls {
	if (urls.count == 0) return NO;
	return [[NSWorkspace sharedWorkspace] openURLs:urls withAppBundleIdentifier:[self getHttpApplication] options:NSWorkspaceLaunchDefault additionalEventParamDescriptor:nil launchIdentifiers:nil];
}


#pragma mark - Hidden Plist Properties -


/// @return The limit on how many links should be opened at the same time, if user holds the option key.
/// Default: @c 10
+ (NSUInteger)openFewLinksLimit {
	return (NSUInteger)[self defaultInt:10 forKey:@"openFewLinksLimit"];
}

/// @return The limit on when to truncate article titles (Short names setting must be active).
/// Default: @c 60
+ (NSUInteger)shortArticleNamesLimit {
	return (NSUInteger)[self defaultInt:60 forKey:@"shortArticleNamesLimit"];
}

/// @return The maximum number of articles displayed per feed (Limit articles setting must be active).
/// Default: @c 40
+ (NSUInteger)articlesInMenuLimit {
	return (NSUInteger)[self defaultInt:40 forKey:@"articlesInMenuLimit"];
}


#pragma mark - Application Info Plist


/// @return The application name, e.g., 'baRSS' or 'baRSS Beta'
+ (NSString*)appName {
	return [[NSBundle mainBundle] infoDictionary][(NSString*)kCFBundleNameKey];
}

/// @return The application version number, e.g., '0.9.4'
+ (NSString*)appVersion {
	return [[NSBundle mainBundle] infoDictionary][@"CFBundleShortVersionString"];
}

/// @return The application version number including build number, e.g., '0.9.4 (9906)'
+ (NSString*)appVersionWithBuildNo {
	NSString *buildNo = [[NSBundle mainBundle] infoDictionary][@"CFBundleVersion"];
	return [[self appVersion] stringByAppendingFormat:@" (%@)", buildNo];
}


#pragma mark - Core Data Properties -


/// Helper method that retrieves and transforms option value to int
+ (int)dbIntForKey:(NSString*)key defaultsTo:(int)otherwise {
	NSString *str = [StoreCoordinator optionForKey:key];
	if (!str) return otherwise;
	int num = [NSDecimalNumber decimalNumberWithString:str].intValue;
	return isnan(num) ? otherwise : num;
}

/// Check whether the database was just initialized (first install)
+ (BOOL)dbIsUnusedInitalState {
	return [StoreCoordinator optionForKey:@"db-version"] == nil;
}

/// Check whether the stored database version is up to date
+ (BOOL)dbIsCurrentFileVersion {
	return [self dbIntForKey:@"db-version" defaultsTo:-1] == dbFileVersion;
}

/// Write current database version to core data
+ (void)dbUpdateFileVersion {
	[StoreCoordinator setOption:@"db-version" value:[NSString stringWithFormat:@"%d", dbFileVersion]];
}

/// Check whether the stored application version is up to date
+ (BOOL)dbIsCurrentAppVersion {
	return [[StoreCoordinator optionForKey:@"app-version"] isEqualToString:[self appVersion]];
}

/// Write current application version to core data
+ (void)dbUpdateAppVersion {
	[StoreCoordinator setOption:@"app-version" value:[self appVersion]];
}

@end
