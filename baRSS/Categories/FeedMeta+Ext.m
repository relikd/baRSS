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

#import "FeedMeta+Ext.h"

@implementation FeedMeta (Ext)

/// Increment @c errorCount and set new @c scheduled date (2^N minutes, max. 5.7 days).
- (void)setErrorAndPostponeSchedule {
	if (self.errorCount < 0)
		self.errorCount = 0;
	int16_t n = self.errorCount + 1; // always increment errorCount (can be used to indicate bad feeds)
	NSTimeInterval retryWaitTime = pow(2, (n > 13 ? 13 : n)) * 60; // 2^N (between: 2 minutes and 5.7 days)
	self.errorCount = n;
	self.scheduled = [NSDate dateWithTimeIntervalSinceNow:retryWaitTime];
	// TODO: remove logging
	NSLog(@"ERROR: Feed download failed: %@ (errorCount: %d)", self.url, n);
}

/// Calculate date from @c refreshNum and @c refreshUnit and set as next scheduled feed update.
- (void)calculateAndSetScheduled {
	NSTimeInterval interval = [self timeInterval]; // 0 if refresh = 0 (update deactivated)
	self.scheduled = (interval <= 0 ? nil : [[NSDate date] dateByAddingTimeInterval:interval]);
}

/// Set etag and modified attributes. @note Only values that differ will be updated.
- (void)setEtag:(NSString*)etag modified:(NSString*)modified {
	if (![self.etag isEqualToString:etag])         self.etag = etag;
	if (![self.modified isEqualToString:modified]) self.modified = modified;
}

/// Read header field "Etag" and "Date" and set @c .etag and @c .modified.
- (void)setEtagAndModified:(NSHTTPURLResponse*)http {
	NSDictionary *header = [http allHeaderFields];
	[self setEtag:header[@"Etag"] modified:header[@"Date"]]; // @"Expires", @"Last-Modified"
}

/**
 Set download url and refresh interval (popup button selection). @note Only values that differ will be updated.

 @return @c YES if refresh interval has changed
 */
- (BOOL)setURL:(NSString*)url refresh:(int32_t)refresh unit:(RefreshUnitType)unit {
	BOOL intervalChanged = (self.refreshNum != refresh || self.refreshUnit != unit);
	if (![self.url isEqualToString:url]) self.url = url;
	if (self.refreshNum != refresh)      self.refreshNum = refresh;
	if (self.refreshUnit != unit)        self.refreshUnit = unit;
	return intervalChanged;
}

/// @return Time interval respecting the selected unit. E.g., returns @c 180 for @c '3m'
- (NSTimeInterval)timeInterval {
	static const int unit[] = {1, 60, 3600, 86400, 604800}; // smhdw
	return self.refreshNum * unit[self.refreshUnit % 5];
}

/// @return Formatted string for update interval ( e.g., @c 30m or @c 12h )
- (NSString*)readableRefreshString {
	return [NSString stringWithFormat:@"%d%c", self.refreshNum, [@"smhdw" characterAtIndex:self.refreshUnit % 5]];
}

@end
