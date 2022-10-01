@import Cocoa;

/// Log error message and prepend calling class and calling method.
#define NSLogCaller(desc) { NSLog(@"%@:%@ %@", [self class], NSStringFromSelector(_cmd), desc); }

NS_ASSUME_NONNULL_BEGIN

@interface NSError (Ext)
// Generators
+ (instancetype)statusCode:(NSInteger)code reason:(nullable NSString*)reason;
+ (instancetype)feedURLNotFound:(NSURL*)url;
+ (instancetype)canceledByUser;
//+ (instancetype)formattingError:(NSString*)description;
// User notification
- (BOOL)inCaseLog:(nullable const char*)title;
- (BOOL)inCasePresent:(NSApplication*)app;
@end

NS_ASSUME_NONNULL_END
