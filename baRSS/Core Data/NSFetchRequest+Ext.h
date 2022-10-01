@import Cocoa;

NS_ASSUME_NONNULL_BEGIN

@interface NSFetchRequest<ResultType> (Ext)
// Perform core data request and fetch data
- (NSArray<ResultType>*)fetchAllRows:(NSManagedObjectContext*)moc;
- (NSArray<NSManagedObjectID*>*)fetchIDs:(NSManagedObjectContext*)moc;
- (NSDictionary*)fetchFirstDict:(NSManagedObjectContext*)moc; // limit 1
- (ResultType)fetchFirst:(NSManagedObjectContext*)moc; // limit 1
- (NSUInteger)fetchCount:(NSManagedObjectContext*)moc;

// Selecting, filtering, sorting results
- (instancetype)select:(NSArray<NSString*>*)cols; // sets .propertiesToFetch
- (instancetype)where:(NSString*)format, ...; // sets .predicate
- (instancetype)sortASC:(NSString*)key; // add .sortDescriptors -> ascending:YES
- (instancetype)sortDESC:(NSString*)key; // add .sortDescriptors -> ascending:NO
- (instancetype)addFunctionExpression:(NSString*)fn onKeyPath:(NSString*)keyPath name:(NSString*)name type:(NSAttributeType)type; // add .propertiesToFetch -> (expressionForFunction:@[expressionForKeyPath:])
@end

NS_ASSUME_NONNULL_END
