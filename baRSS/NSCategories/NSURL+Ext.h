@import Cocoa;

#define ENV_LOG_FILES 0

NS_ASSUME_NONNULL_BEGIN

@interface NSURL (Ext)
// Generators
+ (NSURL*)applicationSupportURL;
+ (NSURL*)faviconsCacheURL;
+ (NSURL*)backupPathURL;
// File Traversal
- (BOOL)existsAndIsDir:(BOOL)dir;
- (NSURL*)subdir:(NSString*)dirname;
- (NSURL*)file:(NSString*)filename ext:(nullable NSString*)ext;
// File Manipulation
- (BOOL)mkdir;
- (void)remove;
- (void)moveTo:(NSURL*)destination;
@end

NS_ASSUME_NONNULL_END
