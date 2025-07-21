#import "MapUnreadTotal.h"

@interface MapUnreadTotal()
@property (strong) NSMutableDictionary<NSString*, UnreadTotal*> *map;
@end

@implementation MapUnreadTotal

- (NSString *)description { return _map.description; }
- (UnreadTotal*)objectForKeyedSubscript:(NSString*)key { return _map[key]; }
- (void)setObject:(UnreadTotal*)obj forKeyedSubscript:(NSString*)key { _map[key] = obj; }

/// Perform core data fetch and sum unread counts per @c Feed. Aggregate counts that are grouped in @c FeedGroup.
- (instancetype)initWithCoreData:(NSArray<NSDictionary*>*)data {
	self = [super init];
	if (self) {
		_map = [NSMutableDictionary dictionaryWithCapacity:data.count + 1];
		_map[@""] = [UnreadTotal new];
		
		for (NSDictionary *d in data) {
			NSUInteger u = [d[@"unread"] unsignedIntegerValue];
			NSUInteger t = [d[@"total"] unsignedIntegerValue];
			
			for (UnreadTotal *uct in [self itemsForPath:d[@"indexPath"] create:YES]) {
				uct.unread += u;
				uct.total += t;
			}
		}
	}
	return self;
}

/// @return All group items and deepest item of @c path. If @c flag @c = @c YES non-existing items will be created.
- (NSArray<UnreadTotal*>*)itemsForPath:(NSString*)path create:(BOOL)flag {
	NSMutableArray<UnreadTotal*> *arr = [NSMutableArray array];
	NSMutableString *key = [NSMutableString string];
	[arr addObject:_map[@""]];
	for (NSString *idx in [path componentsSeparatedByString:@"."]) {
		if (key.length > 0)
			[key appendString:@"."];
		[key appendString:idx];
		
		UnreadTotal *a = _map[key];
		if (!a) {
			if (!flag) continue; // skip item creation if flag = NO
			a = [UnreadTotal new];
			_map[key] = a;
		}
		[arr addObject:a];
	}
	return arr;
}

/// Set new values for item at @c path. Updating all group items as well.
- (void)updateAllCounts:(UnreadTotal*)updated forPath:(NSString*)path {
	UnreadTotal *previous = _map[path];
	NSUInteger diffU = (updated.unread - previous.unread);
	NSUInteger diffT = (updated.total - previous.total);
	for (UnreadTotal *uct in [self itemsForPath:path create:NO]) {
		uct.unread += diffU;
		uct.total += diffT;
	}
}

@end


@implementation UnreadTotal
- (NSString *)description { return [NSString stringWithFormat:@"<unread: %lu, total: %lu>", _unread, _total]; }
@end
