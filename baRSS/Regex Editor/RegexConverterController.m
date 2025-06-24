#import "RegexConverterController.h"
#import "RegexConverterView.h"
#import "RegexConverter+Ext.h"
#import "RegexConverterModal.h"
#import "RegexFeed.h"
#import "Feed+Ext.h"
#import "NSURLRequest+Ext.h"


// ################################################################
// #
// #  MARK: - RegexConverterController -
// #
// ################################################################

@interface RegexConverterController() <NSWindowDelegate>
@property (strong) RegexConverter *converter;
@property (strong) RegexConverterModal *modalSheet;
@property (strong) IBOutlet RegexConverterView *view; // override

@property (strong) NSString *theData; // not "copy" because generated in initializer
@end

@implementation RegexConverterController
@dynamic view;

/// Dedicated initializer
+ (instancetype)withData:(NSData *)data andConverter:(RegexConverter*)converter {
	RegexConverterController *diag = [self new];
	diag.theData = data ? [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding]: @"";
	diag.converter = converter;
	return diag;
}

- (RegexConverterModal *)getModalSheet {
	if (!self.modalSheet) {
		self.modalSheet = [[RegexConverterModal alloc] initWithView:self.view];
		self.modalSheet.delegate = self;
	}
	return self.modalSheet;
}

- (void)loadView {
	self.view = [[RegexConverterView alloc] initWithController:self];
	[self populateTextFields:self.converter];
	[self updateOutput:self.theData];
}

/// Pre-fill UI control field values with @c RegexConverter properties.
- (void)populateTextFields:(RegexConverter*)converter {
	if (converter) {
		self.view.entry.objectValue = converter.entry;
		self.view.href.objectValue = converter.href;
		self.view.title.objectValue = converter.title;
		self.view.desc.objectValue = converter.desc;
		self.view.date.objectValue = converter.date;
		self.view.dateFormat.objectValue = converter.dateFormat;
	}
}

#pragma mark - Update CoreData

- (void)applyChanges:(Feed *)feed {
	BOOL shouldDelete = self.view.entry.stringValue.length == 0;
	
	if (shouldDelete) {
		if (feed.regex) {
			[feed.managedObjectContext deleteObject:feed.regex];
		}
		return;
	}
	
	if (!feed.regex) {
		feed.regex = [RegexConverter newInContext:feed.managedObjectContext];
	}
	
	[feed.regex setEntryIfChanged:self.view.entry.stringValue];
	[feed.regex setHrefIfChanged:self.view.href.stringValue];
	[feed.regex setTitleIfChanged:self.view.title.stringValue];
	[feed.regex setDescIfChanged:self.view.desc.stringValue];
	[feed.regex setDateIfChanged:self.view.date.stringValue];
	[feed.regex setDateFormatIfChanged:self.view.dateFormat.stringValue];
}

#pragma mark - NSTextField Delegate

- (RegexFeed*)regexParser {
	RegexFeed *tmp = [RegexFeed new];
	tmp.rxEntry = self.view.entry.stringValue;
	tmp.rxHref = self.view.href.stringValue;
	tmp.rxTitle = self.view.title.stringValue;
	tmp.rxDesc = self.view.desc.stringValue;
	tmp.rxDate = self.view.date.stringValue;
	tmp.dateFormat = self.view.dateFormat.stringValue;
	return tmp;
}

- (void)controlTextDidEndEditing:(NSNotification*)obj {
	if (self.view.entry.stringValue.length == 0) {
		[self updateOutput:self.theData];
		return;
	}
	
	NSError *err = nil;
	NSArray<RegexFeedEntry*> *matches = [[self regexParser] process:self.theData error:&err];
	if (err) {
		[self updateOutput:[NSString stringWithFormat:@"%@\n––––\n%@",
							err.localizedDescription, err.localizedRecoverySuggestion]];
		return;
	}
	
	NSMutableString *rv = [NSMutableString new];
	for (RegexFeedEntry *entry in matches) {
		[rv appendFormat:@"%@\n\n$_href: %@\n$_title: %@\n$_date: %@ -> %@\n$_description: %@\n\n----------\n\n",
		 entry.rawMatch, entry.href, entry.title, entry.dateString, entry.date, entry.desc];
	}
	
	[self updateOutput:rv];
}

- (void)updateOutput:(NSString *)text {
	[self.view.output.textStorage setAttributedString:[[NSAttributedString alloc] initWithString:text]];
}

@end
