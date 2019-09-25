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

#import "URLScheme.h"
#import "AppHook.h" // barss:open/preferences
#import "Preferences.h" // barss:open/preferences
#import "UpdateScheduler.h" // feed:http://URL
#import "StoreCoordinator.h" // barss:config/fixcache
#import "OpmlFile.h" // barss:backup
#import "NSURL+Ext.h" // barss:backup
#import "NSDate+Ext.h" // barss:backup

@implementation URLScheme

/// Handles open URL requests. Scheme may start with @c feed: or @c barss:
+ (void)withURL:(NSString*)url {
	NSString *scheme = [[[NSURL URLWithString:url] scheme] lowercaseString];
	url = [url substringFromIndex:scheme.length + 1]; // + ':'
	url = [url stringByTrimmingCharactersInSet:[NSCharacterSet characterSetWithCharactersInString:@"/"]];
	
	if ([scheme isEqualToString:@"feed"])       [[URLScheme new] handleSchemeFeed:url];
	else if ([scheme isEqualToString:@"barss"]) [[URLScheme new] handleSchemeConfig:url];
}

/**
 @c feed: URL scheme. Used for feed subscriptions.
 @note E.g., @c feed://https://feeds.feedburner.com/simpledesktops
 */
- (void)handleSchemeFeed:(NSString*)url {
	[UpdateScheduler autoDownloadAndParseURL:url];
}

/**
 @c barss: URL scheme. Used for configuring the app.
       @textblock
 barss:open/preferences[/0-4]
 barss:config/fixcache[/silent]
 barss:backup[/show]
       @/textblock
 */
- (void)handleSchemeConfig:(NSString*)url {
	NSArray<NSString*> *comp = url.pathComponents;
	NSString *action = comp.firstObject;
	if (!action) return;
	NSArray<NSString*> *params = [comp subarrayWithRange:NSMakeRange(1, comp.count - 1)];
	if ([action isEqualToString:@"open"])         [self handleActionOpen:params];
	else if ([action isEqualToString:@"config"])  [self handleActionConfig:params];
	else if ([action isEqualToString:@"backup"])  [self handleActionBackup:params];
}

/// @c barss:open/preferences[/0-4]
- (void)handleActionOpen:(NSArray<NSString*>*)params {
	if ([params.firstObject isEqualToString:@"preferences"]) {
		NSDecimalNumber *num = [NSDecimalNumber decimalNumberWithString:params.lastObject];
		[[(AppHook*)NSApp openPreferences] selectTab:num.unsignedIntegerValue];
	}
}

/// @c barss:config/fixcache[/silent]
- (void)handleActionConfig:(NSArray<NSString*>*)params {
	if ([params.firstObject isEqualToString:@"fixcache"]) {
		[StoreCoordinator cleanupAndShowAlert:![params.lastObject isEqualToString:@"silent"]];
	}
}

/// @c barss:backup[/show]
- (void)handleActionBackup:(NSArray<NSString*>*)params {
	NSURL *baseURL = [NSURL backupPathURL];
	[baseURL mkdir]; // non destructive make dir
	NSURL *dest = [baseURL file:[@"feeds_" stringByAppendingString:[NSDate dayStringISO8601]] ext:@"opml"];
	NSURL *sym = [baseURL file:@"feeds_latest" ext:@"opml"];
	[sym remove]; // remove old sym link, otherwise won't be updated
	[[NSFileManager defaultManager] createSymbolicLinkAtURL:sym withDestinationURL:[NSURL URLWithString:dest.lastPathComponent] error:nil];
	[[OpmlFileExport withDelegate:nil] writeOPMLFile:dest withOptions:OpmlFileExportOptionFullBackup];
	if ([params.firstObject isEqualToString:@"show"]) {
		[[NSWorkspace sharedWorkspace] activateFileViewerSelectingURLs:@[dest]];
	}
}

@end
