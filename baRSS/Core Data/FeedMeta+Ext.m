#import "FeedMeta+Ext.h"
#import "Feed+Ext.h"
#import "FeedGroup+Ext.h"

@implementation FeedMeta (Ext)

/// Create new instance with default @c refresh interval and set @c scheduled to distant past.
+ (instancetype)newMetaInContext:(NSManagedObjectContext*)moc {
	FeedMeta *meta = [[FeedMeta alloc] initWithEntity:FeedMeta.entity insertIntoManagedObjectContext:moc];
	meta.refresh = kDefaultFeedRefreshInterval;
	meta.scheduled = [NSDate distantPast]; // will cause update to refresh as soon as possible
	return meta;
}

#pragma mark - HTTP response

/// Increment @c errorCount and set new @c scheduled date (2^N minutes, max. 5.7 days).
- (void)setErrorAndPostponeSchedule {
	if (self.errorCount < 0)
		self.errorCount = 0;
	int16_t n = self.errorCount + 1; // always increment errorCount (can be used to indicate bad feeds)
#ifdef DEBUG
	NSLog(@"ERROR: Feed download failed: %@ (errorCount: %d)", self.url, n);
#endif
	if ([self.scheduled timeIntervalSinceNow] > 30) // forced, early update. Scheduled is still in the futute.
		return; // Keep error counter low. Not enough time has passed (e.g., temporary server outage)
	NSTimeInterval retryWaitTime = pow(2, (n > 13 ? 13 : n)) * 60; // 2^N (between: 2 minutes and 5.7 days)
	self.errorCount = n;
	[self scheduleNow:retryWaitTime];
}

/// Copy Etag & Last-Modified headers and update URL (if not 304). Then schedule new update date. Will reset errorCount to @c 0
- (void)setSucessfulWithResponse:(NSHTTPURLResponse*)response {
	self.errorCount = 0; // reset counter
	NSDictionary *header = [response allHeaderFields];
	if (response.statusCode != 304) { // not all servers set etag / modified when returning 304
		[self setEtag:header[@"Etag"] modified:header[@"Last-Modified"]];
		[self setUrlIfChanged:response.URL.absoluteString];
	}
	[self scheduleNow:self.refresh];
}

#pragma mark - Setter

/// Set @c url attribute but only if value differs.
- (void)setUrlIfChanged:(NSString*)url {
	if (![self.url isEqualToString:url]) self.url = url;
}

/// Set @c refresh attribute but only if value differs.
- (void)setRefreshIfChanged:(int32_t)refresh {
	if (self.refresh != refresh) self.refresh = refresh;
}

/// Set @c etag and @c modified attributes. Only values that differ will be updated.
- (void)setEtag:(NSString*)etag modified:(NSString*)modified {
	if (![self.etag isEqualToString:etag])         self.etag = etag;
	if (![self.modified isEqualToString:modified]) self.modified = modified;
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
