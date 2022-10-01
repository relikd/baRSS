@import Cocoa;

NS_ASSUME_NONNULL_BEGIN

@interface UnreadTotal : NSObject
@property (nonatomic, assign) NSUInteger unread;
@property (nonatomic, assign) NSUInteger total;
@end


@interface MapUnreadTotal : NSObject
- (instancetype)init NS_UNAVAILABLE;
- (instancetype)initWithCoreData:(NSArray<NSDictionary*>*)data NS_DESIGNATED_INITIALIZER;

- (NSArray<UnreadTotal*>*)itemsForPath:(NSString*)path create:(BOOL)flag;
- (void)updateAllCounts:(UnreadTotal*)updated forPath:(NSString*)path;

// Keyed subscription
- (UnreadTotal*)objectForKeyedSubscript:(NSString*)key;
- (void)setObject:(UnreadTotal*)obj forKeyedSubscript:(NSString*)key;
@end

NS_ASSUME_NONNULL_END
