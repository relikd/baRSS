#import "NSFetchRequest+Ext.h"
#import "NSError+Ext.h"

@implementation NSFetchRequest (Ext)

/// Perform fetch and return result. If an error occurs, print it to the console.
- (NSArray*)fetchAllRows:(NSManagedObjectContext*)moc {
	NSError *err;
	NSArray *fetchResults = [moc executeFetchRequest:self error:&err];
	[err inCaseLog:"Fetch request failed"];
	//NSLog(@"%@ ==> %@", self, fetchResults); // debugging
	return fetchResults;
}

/// Set @c resultType to @c NSManagedObjectIDResultType and return list of object ids.
- (NSArray<NSManagedObjectID*>*)fetchIDs:(NSManagedObjectContext*)moc {
	self.includesPropertyValues = NO;
	self.resultType = NSManagedObjectIDResultType;
	return [self fetchAllRows:moc];
}

/// Same as @c fetchFirst: but with dictionary return type
- (NSDictionary*)fetchFirstDict:(NSManagedObjectContext*)moc {
	return [self fetchFirst:moc];
}

/// Set @c limit to @c 1 and fetch first object. May return object type or @c NSDictionary if @c resultType @c = @c NSManagedObjectIDResultType.
- (id)fetchFirst:(NSManagedObjectContext*)moc {
	self.fetchLimit = 1;
	return [[self fetchAllRows:moc] firstObject];
}

/// Convenient method to return the number of rows that match the request.
- (NSUInteger)fetchCount:(NSManagedObjectContext*)moc {
	return [moc countForFetchRequest:self error:nil];
}

#pragma mark - Selecting, Filtering, Sorting

/**
 Set @c self.propertiesToFetch = @c cols and @c self.resultType = @c NSDictionaryResultType.
 @return @c self (e.g., method chaining)
 */
- (instancetype)select:(NSArray<NSString*>*)cols {
	self.propertiesToFetch = cols;
	self.resultType = NSDictionaryResultType;
	return self;
}

/**
 Set @c self.predicate = [NSPredicate predicateWithFormat: @c format ]
 @return @c self (e.g., method chaining)
 */
- (instancetype)where:(NSString*)format, ... {
	va_list arguments;
	va_start(arguments, format);
	self.predicate = [NSPredicate predicateWithFormat:format arguments:arguments];
	va_end(arguments);
	return self;
}

/**
 Add new [NSSortDescriptor sortDescriptorWithKey: @c key ascending:YES] to @c self.sortDescriptors.
 @return @c self (e.g., method chaining)
 */
- (instancetype)sortASC:(NSString*)key {
	[self addSortingKey:key asc:YES];
	return self;
}

/**
 Add new [NSSortDescriptor sortDescriptorWithKey: @c key ascending:NO] to @c self.sortDescriptors.
 @return @c self (e.g., method chaining)
 */
- (instancetype)sortDESC:(NSString*)key {
	[self addSortingKey:key asc:NO];
	return self;
}

/**
 Add new [NSExpression expressionForFunction: @c fn arguments: [NSExpression expressionForKeyPath: @c keyPath ]] to @c self.propertiesToFetch.
 Also set @c self.includesPropertyValues @c = @c NO and @c self.resultType @c = @c NSDictionaryResultType.
 @return @c self (e.g., method chaining)
 */
- (instancetype)addFunctionExpression:(NSString*)fn onKeyPath:(NSString*)keyPath name:(NSString*)name type:(NSAttributeType)type {
	[self addExpression:[NSExpression expressionForFunction:fn arguments:@[[NSExpression expressionForKeyPath:keyPath]]] name:name type:type];
	return self;
}

#pragma mark - Helper

/// Add @c NSSortDescriptor to existing list of @c sortDescriptors.
- (void)addSortingKey:(NSString*)key asc:(BOOL)flag {
	NSSortDescriptor *sd = [NSSortDescriptor sortDescriptorWithKey:key ascending:flag];
	if (!self.sortDescriptors) {
		self.sortDescriptors = @[ sd ];
	} else {
		self.sortDescriptors = [self.sortDescriptors arrayByAddingObject:sd];
	}
}

/// Add @c NSExpressionDescription to existing list of @c propertiesToFetch.
- (void)addExpression:(NSExpression*)exp name:(NSString*)name type:(NSAttributeType)type {
	self.includesPropertyValues = NO;
	self.resultType = NSDictionaryResultType;
	NSExpressionDescription *expDesc = [[NSExpressionDescription alloc] init];
	[expDesc setName:name];
	[expDesc setExpression:exp];
	[expDesc setExpressionResultType:type];
	if (!self.propertiesToFetch) {
		self.propertiesToFetch = @[ expDesc ];
	} else {
		self.propertiesToFetch = [self.propertiesToFetch arrayByAddingObject:expDesc];
	}
}

@end
