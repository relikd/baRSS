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
#import "Feed+Ext.h"
#import "FeedGroup+Ext.h"

/// smhdw: [1, 60, 3600, 86400, 604800]
static const int32_t RefreshUnitValues[] = {1, 60, 3600, 86400, 604800}; // smhdw

@implementation FeedMeta (Ext)

#pragma mark - Getter

/// Check whether update interval is disabled by user (refresh interval is 0).
- (BOOL)refreshIntervalDisabled {
	return (self.refreshNum <= 0);
}

/// @return Time interval respecting the selected unit. E.g., returns @c 180 for @c '3m'
- (int32_t)refreshInterval {
	return self.refreshNum * RefreshUnitValues[self.refreshUnit % 5];
}

/// @return Formatted string for update interval ( e.g., @c 30m or @c 12h )
- (NSString*)readableRefreshString {
	if (self.refreshIntervalDisabled)
		return @"∞"; // ∞ ƒ Ø
	return [NSString stringWithFormat:@"%d%c", self.refreshNum, [@"smhdw" characterAtIndex:self.refreshUnit % 5]];
}

#pragma mark - HTTP response

/// Increment @c errorCount and set new @c scheduled date (2^N minutes, max. 5.7 days).
- (void)setErrorAndPostponeSchedule {
	if (self.errorCount < 0)
		self.errorCount = 0;
	int16_t n = self.errorCount + 1; // always increment errorCount (can be used to indicate bad feeds)
	NSTimeInterval retryWaitTime = pow(2, (n > 13 ? 13 : n)) * 60; // 2^N (between: 2 minutes and 5.7 days)
	self.errorCount = n;
	[self scheduleNow:retryWaitTime];
	// TODO: remove logging
	NSLog(@"ERROR: Feed download failed: %@ (errorCount: %d)", self.url, n);
}

- (void)setSucessfulWithResponse:(NSHTTPURLResponse*)response {
	self.errorCount = 0; // reset counter
	NSDictionary *header = [response allHeaderFields];
	[self setEtag:header[@"Etag"] modified:header[@"Date"]]; // @"Expires", @"Last-Modified"
	[self scheduleNow:[self refreshInterval]];
}

#pragma mark - Setter

/// Set @c url attribute but only if value differs.
- (void)setUrlIfChanged:(NSString*)url {
	if (![self.url isEqualToString:url]) self.url = url;
}

/// Set @c etag and @c modified attributes. Only values that differ will be updated.
- (void)setEtag:(NSString*)etag modified:(NSString*)modified {
	if (![self.etag isEqualToString:etag])         self.etag = etag;
	if (![self.modified isEqualToString:modified]) self.modified = modified;
}

/**
 Set @c refresh and @c unit from popup button selection. Only values that differ will be updated.
 Also, calculate and set new @c scheduled date and update FeedGroup @c refreshStr (if changed).

 @return @c YES if refresh interval has changed
 */
- (BOOL)setRefresh:(int32_t)refresh unit:(RefreshUnitType)unit {
	BOOL intervalChanged = (self.refreshNum != refresh || self.refreshUnit != unit);
	if (self.refreshNum != refresh) self.refreshNum = refresh;
	if (self.refreshUnit != unit)   self.refreshUnit = unit;
	
	if (intervalChanged) {
		[self scheduleNow:[self refreshInterval]];
		NSString *str = [self readableRefreshString];
		if (![self.feed.group.refreshStr isEqualToString:str])
			self.feed.group.refreshStr = str;
	}
	return intervalChanged;
}

/**
 Set properties @c refreshNum and @c refreshUnit to highest possible (integer-dividable-)unit.
 Only values that differ will be updated.
 Also, calculate and set new @c scheduled date and update FeedGroup @c refreshStr (if changed).
 
 @return @c YES if refresh interval has changed
 */
- (BOOL)setRefreshAndUnitFromInterval:(int32_t)interval {
	for (RefreshUnitType i = 4; i >= 0; i--) { // start with weeks
		if (interval % RefreshUnitValues[i] == 0) { // find first unit that is dividable
			return [self setRefresh:abs(interval) / RefreshUnitValues[i] unit:i];
		}
	}
	return NO; // since loop didn't return, no value was changed
}

/// Calculate date from @c refreshNum and @c refreshUnit and set as next scheduled feed update.
- (void)scheduleNow:(NSTimeInterval)future {
	if (self.refreshIntervalDisabled) { // update deactivated; manually update with force update all
		if (self.scheduled != nil) // already nil? Avoid unnecessary core data edits
			self.scheduled = nil;
	} else {
		self.scheduled = [NSDate dateWithTimeIntervalSinceNow:future];
	}
}

@end
