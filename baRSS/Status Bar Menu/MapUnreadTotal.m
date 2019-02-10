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
		UnreadTotal *sum = [UnreadTotal new];
		_map = [NSMutableDictionary dictionaryWithCapacity:data.count];
		_map[@""] = sum;
		
		for (NSDictionary *d in data) {
			NSUInteger u = [d[@"unread"] unsignedIntegerValue];
			NSUInteger t = [d[@"total"] unsignedIntegerValue];
			sum.unread += u;
			sum.total += t;
			
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
