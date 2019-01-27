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

@implementation FeedMeta (Ext)

#pragma mark - HTTP response

/// Increment @c errorCount and set new @c scheduled date (2^N minutes, max. 5.7 days).
- (void)setErrorAndPostponeSchedule {
	if (self.errorCount < 0)
		self.errorCount = 0;
	int16_t n = self.errorCount + 1; // always increment errorCount (can be used to indicate bad feeds)
	// TODO: remove logging
	NSLog(@"ERROR: Feed download failed: %@ (errorCount: %d)", self.url, n);
	if ([self.scheduled timeIntervalSinceNow] > 30) // forced, early update. Scheduled is still in the futute.
		return; // Keep error counter low. Not enough time has passed (e.g., temporary server outage)
	NSTimeInterval retryWaitTime = pow(2, (n > 13 ? 13 : n)) * 60; // 2^N (between: 2 minutes and 5.7 days)
	self.errorCount = n;
	[self scheduleNow:retryWaitTime];
}

- (void)setSucessfulWithResponse:(NSHTTPURLResponse*)response {
	self.errorCount = 0; // reset counter
	NSDictionary *header = [response allHeaderFields];
	[self setEtag:header[@"Etag"] modified:header[@"Date"]]; // @"Expires", @"Last-Modified"
	[self scheduleNow:self.refresh];
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
 Set @c refresh and calculate new @c scheduled date.

 @return @c YES if refresh interval has changed
 */
- (BOOL)setRefreshAndSchedule:(int32_t)refresh {
	if (self.refresh != refresh) {
		self.refresh = refresh;
		[self scheduleNow:self.refresh];
		return YES;
	}
	return NO;
}

/// Set next scheduled feed update or @c nil if @c refresh @c <= @c 0.
- (void)scheduleNow:(NSTimeInterval)future {
	if (self.refresh <= 0) { // update deactivated; manually update with force update all
		if (self.scheduled != nil) // already nil? Avoid unnecessary core data edits
			self.scheduled = nil;
	} else {
		self.scheduled = [NSDate dateWithTimeIntervalSinceNow:future];
	}
}

@end
