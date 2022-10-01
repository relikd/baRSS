@import Cocoa;
#import "FeedMeta+CoreDataClass.h"

static int32_t const kDefaultFeedRefreshInterval = 30 * 60;

NS_ASSUME_NONNULL_BEGIN

@interface FeedMeta (Ext)
+ (instancetype)newMetaInContext:(NSManagedObjectContext*)moc;
// HTTP response
- (void)setErrorAndPostponeSchedule;
- (void)setSucessfulWithResponse:(NSHTTPURLResponse*)response;
// Setter
- (void)setUrlIfChanged:(NSString*)url;
- (void)setRefreshIfChanged:(int32_t)refresh;
- (void)scheduleNow:(NSTimeInterval)future;
@end

NS_ASSUME_NONNULL_END
