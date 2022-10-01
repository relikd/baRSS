#import "NSURL+Ext.h"
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
		path = [path URLByAppendingPathComponent:APP_NAME isDirectory:YES];
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
#if DEBUG && ENV_LOG_FILES
	BOOL success =
#endif
	[[NSFileManager defaultManager] removeItemAtURL:self error:nil];
#if DEBUG && ENV_LOG_FILES
	if (success) printf("DEL %s\n", self.absoluteString.UTF8String);
#endif
}

/// Move file to destination (by replacing any existing file)
- (void)moveTo:(NSURL*)destination {
	[[NSFileManager defaultManager] removeItemAtURL:destination error:nil];
	[[NSFileManager defaultManager] moveItemAtURL:self toURL:destination error:nil];
#if DEBUG && ENV_LOG_FILES
	printf("MOVE %s\n", self.absoluteString.UTF8String);
	printf(" ↳ %s\n", destination.absoluteString.UTF8String);
#endif
}

@end
