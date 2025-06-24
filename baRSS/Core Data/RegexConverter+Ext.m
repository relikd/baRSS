#import "RegexConverter+Ext.h"

@implementation RegexConverter (Ext)

/// Create new instance
+ (instancetype)newInContext:(NSManagedObjectContext*)moc {
	return [[RegexConverter alloc] initWithEntity:[RegexConverter entity] insertIntoManagedObjectContext:moc];
}

/// Set @c entry attribute but only if value differs.
- (void)setEntryIfChanged:(nullable NSString*)pattern {
	if (pattern.length == 0) {
		if (self.entry.length > 0)
			self.entry = nil; // nullify empty strings
	} else if (![self.entry isEqualToString: pattern]) {
		self.entry = pattern;
	}
}

/// Set @c href attribute but only if value differs.
- (void)setHrefIfChanged:(nullable NSString*)pattern {
	if (pattern.length == 0) {
		if (self.href.length > 0)
			self.href = nil; // nullify empty strings
	} else if (![self.href isEqualToString: pattern]) {
		self.href = pattern;
	}
}

/// Set @c title attribute but only if value differs.
- (void)setTitleIfChanged:(nullable NSString*)pattern {
	if (pattern.length == 0) {
		if (self.title.length > 0)
			self.title = nil; // nullify empty strings
	} else if (![self.title isEqualToString: pattern]) {
		self.title = pattern;
	}
}

/// Set @c desc attribute but only if value differs.
- (void)setDescIfChanged:(nullable NSString*)pattern {
	if (pattern.length == 0) {
		if (self.desc.length > 0)
			self.desc = nil; // nullify empty strings
	} else if (![self.desc isEqualToString: pattern]) {
		self.desc = pattern;
	}
}

/// Set @c date attribute but only if value differs.
- (void)setDateIfChanged:(nullable NSString*)pattern {
	if (pattern.length == 0) {
		if (self.date.length > 0)
			self.date = nil; // nullify empty strings
	} else if (![self.date isEqualToString: pattern]) {
		self.date = pattern;
	}
}

/// Set @c dateFormat attribute but only if value differs.
- (void)setDateFormatIfChanged:(nullable NSString*)pattern {
	if (pattern.length == 0) {
		if (self.dateFormat.length > 0)
			self.dateFormat = nil; // nullify empty strings
	} else if (![self.dateFormat isEqualToString: pattern]) {
		self.dateFormat = pattern;
	}
}

@end
