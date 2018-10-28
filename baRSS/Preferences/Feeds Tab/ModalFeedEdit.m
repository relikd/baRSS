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

#import "ModalFeedEdit.h"
#import "FeedDownload.h"
#import "StoreCoordinator.h"

@interface ModalFeedEdit()
@property (weak) IBOutlet NSTextField *url;
@property (weak) IBOutlet NSTextField *name;
@property (weak) IBOutlet NSTextField *refreshNum;
@property (weak) IBOutlet NSPopUpButton *refreshUnit;
@property (weak) IBOutlet NSProgressIndicator *spinnerURL;
@property (weak) IBOutlet NSProgressIndicator *spinnerName;
@property (weak) IBOutlet NSButton *warningIndicator;
@property (weak) IBOutlet NSPopover *warningPopover;

@property (copy) NSString *previousURL;
@property (copy) NSString *httpDate;
@property (copy) NSString *httpEtag;
@property (strong) NSError *feedError;
@property (strong) RSParsedFeed *feedResult;

@property (assign) BOOL shouldSaveObject;
@property (assign) BOOL shouldDeletePrevArticles;
@property (assign) BOOL objectNeedsSaving;
@property (assign) BOOL objectIsModified;
@end

@implementation ModalFeedEdit
@synthesize delegate;

- (void)viewDidLoad {
	[super viewDidLoad];
	self.previousURL = @"";
	self.refreshNum.intValue = 30;
	self.shouldSaveObject = NO;
	self.shouldDeletePrevArticles = NO;
	self.objectNeedsSaving = NO;
	self.objectIsModified = NO;
	
	FeedConfig *fc = [self feedConfigOrNil];
	if (fc) {
		self.url.objectValue = fc.url;
		self.name.objectValue = fc.name;
		self.refreshNum.intValue = fc.refreshNum;
		NSInteger unitIndex = fc.refreshUnit;
		if (unitIndex < 0 || unitIndex > self.refreshUnit.numberOfItems - 1)
			unitIndex = self.refreshUnit.numberOfItems - 1;
		[self.refreshUnit selectItemAtIndex:unitIndex];
		
		self.previousURL = self.url.stringValue;
	}
}

- (void)dealloc {
	if (self.shouldSaveObject) {
		if (self.objectNeedsSaving)
			[self updateRepresentedObject];
		FeedConfig *item = [self feedConfigOrNil];
		NSUndoManager *um = item.managedObjectContext.undoManager;
		[um endUndoGrouping];
		if (!self.objectIsModified) {
			[um disableUndoRegistration];
			[um undoNestedGroup];
			[um enableUndoRegistration];
		} else {
			[self.delegate modalDidUpdateFeedConfig:item];
		}
	}
}

- (void)updateRepresentedObject {
	FeedConfig *item = [self feedConfigOrNil];
	if (!item)
		return;
	if (!self.shouldSaveObject) // first call to this method
		[item.managedObjectContext.undoManager beginUndoGrouping];
	self.shouldSaveObject = YES;
	self.objectNeedsSaving = NO; // after this method it is saved
	
	// if's to prevent unnecessary undo groups if nothing has changed
	if (![item.name isEqualToString: self.name.stringValue])
		item.name = self.name.stringValue;
	if (![item.url isEqualToString:self.url.stringValue])
		item.url = self.url.stringValue;
	if (item.refreshNum != self.refreshNum.intValue)
		item.refreshNum = self.refreshNum.intValue;
	if (item.refreshUnit != self.refreshUnit.indexOfSelectedItem)
		item.refreshUnit = (int16_t)self.refreshUnit.indexOfSelectedItem;
	
	if (self.shouldDeletePrevArticles) {
		[StoreCoordinator overwriteConfig:item withFeed:self.feedResult];
		[item.managedObjectContext performBlockAndWait:^{
			// TODO: move to separate function and add icon download
			if (!item.meta) {
				item.meta = [[FeedMeta alloc] initWithEntity:FeedMeta.entity insertIntoManagedObjectContext:item.managedObjectContext];
			}
			item.meta.httpEtag = self.httpEtag;
			item.meta.httpModified = self.httpDate;
		}];
	}
	if ([item.managedObjectContext hasChanges]) {
		self.objectIsModified = YES;
		[item calculateAndSetScheduled];
		[item.managedObjectContext performBlockAndWait:^{
			[item.managedObjectContext refreshObject:item mergeChanges:YES];
		}];
	}
}

- (FeedConfig*)feedConfigOrNil {
	if ([self.representedObject isKindOfClass:[FeedConfig class]])
		return self.representedObject;
	return nil;
}

- (BOOL)urlHasChanged {
	return ![self.previousURL isEqualToString:self.url.stringValue];
}

- (void)controlTextDidChange:(NSNotification *)obj {
	if (obj.object == self.url) {
		self.warningIndicator.hidden = (!self.feedError || [self urlHasChanged]);
	}
}

- (void)controlTextDidEndEditing:(NSNotification *)obj {
	if (obj.object == self.url && [self urlHasChanged]) {
		self.shouldDeletePrevArticles = YES;
		self.previousURL = self.url.stringValue;
		self.feedResult = nil;
		self.feedError = nil;
		[self.spinnerURL startAnimation:nil];
		[self.spinnerName startAnimation:nil];
		[FeedDownload newFeed:self.previousURL block:^(RSParsedFeed *result, NSError *error, NSHTTPURLResponse* response) {
			self.feedResult = result;
			self.httpDate = [response allHeaderFields][@"Date"]; // @"Expires", @"Last-Modified"
			self.httpEtag = [response allHeaderFields][@"Etag"];
			dispatch_async(dispatch_get_main_queue(), ^{
				if (response && ![response.URL.absoluteString isEqualToString:self.url.stringValue]) {
					// URL was redirected, so replace original text field value with new one
					self.url.stringValue = response.URL.absoluteString;
					self.previousURL = self.url.stringValue;
				}
				// TODO: play error sound?
				self.feedError = error; // warning indicator .hidden is bound to feedError
				self.objectNeedsSaving = YES; // stays YES if this block runs after updateRepresentedObject:
				[self setTitleFromFeed];
				[self.spinnerURL stopAnimation:nil];
				[self.spinnerName stopAnimation:nil];
			});
		}];
	}
}

- (void)setTitleFromFeed {
	if ([self.name.stringValue isEqualToString:@""]) {
		self.name.objectValue = self.feedResult.title;
	}
}

- (IBAction)didClickWarningButton:(NSButton*)sender {
	if (!self.feedError)
		return;
	
	NSString *str = self.feedError.localizedDescription;
	NSTextField *tf = self.warningPopover.contentViewController.view.subviews.firstObject;
	tf.maximumNumberOfLines = 7;
	tf.objectValue = str;
	
	NSSize newSize = tf.fittingSize; // width is limited by the textfield's preferred width
	newSize.width += 2 * tf.frame.origin.x; // the padding
	newSize.height += 2 * tf.frame.origin.y;
	
	[self.warningPopover showRelativeToRect:sender.bounds ofView:sender preferredEdge:NSRectEdgeMinY];
	[self.warningPopover setContentSize:newSize];
}

@end


#pragma mark - ModalGroupEdit

@implementation ModalGroupEdit
@synthesize delegate;
- (void)viewDidLoad {
	[super viewDidLoad];
	if ([self.representedObject isKindOfClass:[FeedConfig class]]) {
		FeedConfig *fc = self.representedObject;
		((NSTextField*)self.view).objectValue = fc.name;
	}
}
- (void)loadView {
	NSTextField *tf = [NSTextField textFieldWithString:NSLocalizedString(@"New Group", nil)];
	tf.placeholderString = NSLocalizedString(@"New Group", nil);
	tf.autoresizingMask = NSViewWidthSizable | NSViewMinYMargin;
	self.view = tf;
}
- (void)updateRepresentedObject {
	if ([self.representedObject isKindOfClass:[FeedConfig class]]) {
		FeedConfig *item = self.representedObject;
		NSString *name = ((NSTextField*)self.view).stringValue;
		if (![item.name isEqualToString: name]) {
			item.name = name;
			[item.managedObjectContext performBlockAndWait:^{
				[item.managedObjectContext refreshObject:item mergeChanges:YES];
			}];
			[self.delegate modalDidUpdateFeedConfig:item];
		}
	}
}
@end


#pragma mark - StrictUIntFormatter


@interface StrictUIntFormatter : NSFormatter
@end

@implementation StrictUIntFormatter
- (NSString *)stringForObjectValue:(id)obj {
	return [NSString stringWithFormat:@"%d", [[NSString stringWithFormat:@"%@", obj] intValue]];
}
- (BOOL)getObjectValue:(out id  _Nullable __autoreleasing *)obj forString:(NSString *)string errorDescription:(out NSString *__autoreleasing  _Nullable *)error {
	*obj = [[NSNumber numberWithInt:[string intValue]] stringValue];
	return YES;
}
- (BOOL)isPartialStringValid:(NSString *__autoreleasing  _Nonnull *)partialStringPtr proposedSelectedRange:(NSRangePointer)proposedSelRangePtr originalString:(NSString *)origString originalSelectedRange:(NSRange)origSelRange errorDescription:(NSString *__autoreleasing  _Nullable *)error {
	for (NSUInteger i = 0; i < [*partialStringPtr length]; i++) {
		unichar c = [*partialStringPtr characterAtIndex:i];
		if (c < '0' || c > '9')
			return NO;
	}
	return YES;
}
@end
