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

#import "NSURL+Ext.h"
#import "UserPrefs.h" // appName in +faviconsCacheURL
#import "NSError+Ext.h"

@implementation NSURL (Ext)

//  ---------------------------------------------------------------
// |  MARK: - Generators
//  ---------------------------------------------------------------

/// @return Directory URL pointing to "Application Support/baRSS". Does @b not create directory!
+ (NSURL*)applicationSupportURL {
	static NSURL *path = nil;
	static dispatch_once_t onceToken;
	dispatch_once(&onceToken, ^{
		path = [[NSFileManager defaultManager] URLForDirectory:NSApplicationSupportDirectory inDomain:NSUserDomainMask appropriateForURL:nil create:YES error:nil];
		path = [path URLByAppendingPathComponent:[UserPrefs appName] isDirectory:YES];
	});
	return path;
}

/// @return Directory URL pointing to "Application Support/baRSS/favicons". Does @b not create directory!
+ (NSURL*)faviconsCacheURL {
	return [[self applicationSupportURL] URLByAppendingPathComponent:@"favicons" isDirectory:YES];
}

/// @return Directory URL pointing to "Application Support/baRSS/backup". Does @b not create directory!
+ (NSURL*)backupPathURL {
	return [[self applicationSupportURL] URLByAppendingPathComponent:@"backup" isDirectory:YES];
}

//  ---------------------------------------------------------------
// |  MARK: - File Traversal
//  ---------------------------------------------------------------

/// @return @c YES if and only if item exists at URL and item matches @c dir flag
- (BOOL)existsAndIsDir:(BOOL)dir {
	BOOL d;
	return self.path && [[NSFileManager defaultManager] fileExistsAtPath:self.path isDirectory:&d] && d == dir;
}

/// @return @c NSURL copy with appended directory path
- (NSURL*)subdir:(NSString*)dirname {
	return [self URLByAppendingPathComponent:dirname isDirectory:YES];
}

/// @return @c NSURL copy with appended file path and extension
- (NSURL*)file:(NSString*)filename ext:(nullable NSString*)ext {
	NSURL *u = [self URLByAppendingPathComponent:filename isDirectory:NO];
	return ext.length > 0 ? [u URLByAppendingPathExtension:ext] : u;
}

//  ---------------------------------------------------------------
// |  MARK: - File Manipulation
//  ---------------------------------------------------------------

/**
 Create directory at URL. If directory exists, this method does nothing.
 @return @c YES if dir created successfully. @c NO if dir already exists or an error occured.
 */
- (BOOL)mkdir {
	if ([self existsAndIsDir:YES]) return NO;
	NSError *err;
	[[NSFileManager defaultManager] createDirectoryAtURL:self withIntermediateDirectories:YES attributes:nil error:&err];
	return ![err inCasePresent:NSApp];
}

/// Delete file or folder at URL. If item does not exist, this method does nothing.
- (void)remove {
#ifdef DEBUG
	BOOL success =
#endif
	[[NSFileManager defaultManager] removeItemAtURL:self error:nil];
#ifdef DEBUG
	if (success) printf("DEL %s\n", self.absoluteString.UTF8String);
#endif
}

/// Move file to destination (by replacing any existing file)
- (void)moveTo:(NSURL*)destination {
	[[NSFileManager defaultManager] removeItemAtURL:destination error:nil];
	[[NSFileManager defaultManager] moveItemAtURL:self toURL:destination error:nil];
#ifdef DEBUG
	printf("MOVE %s\n", self.absoluteString.UTF8String);
	printf(" ↳ %s\n", destination.absoluteString.UTF8String);
#endif
}

@end
