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
