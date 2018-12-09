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
#import "Feed+Ext.h"
#import "FeedMeta+Ext.h"
#import "FeedGroup+Ext.h"


#pragma mark - ModalEditDialog -


@interface ModalEditDialog()
@property (strong) FeedGroup *feedGroup;
@property (strong) ModalSheet *modalSheet;
@end

@implementation ModalEditDialog
/// Dedicated initializer for @c ModalEditDialog subclasses. Ensures @c .feedGroup property is set.
+ (instancetype)modalWith:(FeedGroup*)group {
	ModalEditDialog *diag = [self new];
	diag.feedGroup = group;
	return diag;
}
/// @return New @c ModalSheet with its subclass @c .view property as dialog content.
- (ModalSheet *)getModalSheet {
	if (!self.modalSheet)
		self.modalSheet = [ModalSheet modalWithView:self.view];
	return self.modalSheet;
}
/// This method should be overridden by subclasses. Used to save changes to persistent store.
- (void)applyChangesToCoreDataObject {
	NSLog(@"[%@] is missing method: -(void)applyChangesToCoreDataObject", [self class]);
	NSAssert(NO, @"Override required!");
}
@end


#pragma mark - ModalFeedEdit -


@interface ModalFeedEdit()
@property (weak) IBOutlet NSTextField *url;
@property (weak) IBOutlet NSTextField *name;
@property (weak) IBOutlet NSTextField *refreshNum;
@property (weak) IBOutlet NSPopUpButton *refreshUnit;
@property (weak) IBOutlet NSProgressIndicator *spinnerURL;
@property (weak) IBOutlet NSProgressIndicator *spinnerName;
@property (weak) IBOutlet NSButton *warningIndicator;
@property (weak) IBOutlet NSPopover *warningPopover;

@property (copy) NSString *previousURL; // check if changed and avoid multiple download
@property (copy) NSString *httpDate;
@property (copy) NSString *httpEtag;
@property (strong) NSError *feedError; // download error or xml parser error
@property (strong) RSParsedFeed *feedResult; // parsed result
@property (assign) BOOL didDownloadFeed; // check if feed articles need update
@end

@implementation ModalFeedEdit

/// Init feed edit dialog with default values.
- (void)viewDidLoad {
	[super viewDidLoad];
	self.previousURL = @"";
	self.refreshNum.intValue = 30;
	[self populateTextFields:self.feedGroup];
}

/**
 Pre-fill UI control field values with @c FeedGroup properties.
 */
- (void)populateTextFields:(FeedGroup*)fg {
	if (!fg || [fg hasChanges]) return; // hasChanges is true only if newly created
	self.name.objectValue = fg.name;
	self.url.objectValue = fg.feed.meta.url;
	self.previousURL = self.url.stringValue;
	self.refreshNum.intValue = fg.feed.meta.refreshNum;
	NSInteger unit = (NSInteger)fg.feed.meta.refreshUnit;
	if (unit < 0 || unit > self.refreshUnit.numberOfItems - 1)
		unit = self.refreshUnit.numberOfItems - 1;
	[self.refreshUnit selectItemAtIndex:unit];
}

#pragma mark - Edit Feed Data

/**
 Use UI control field values to update the represented core data object. Also parse new articles if applicable.
 Set @c scheduled to a new date if refresh interval was changed.
 */
- (void)applyChangesToCoreDataObject {
	FeedMeta *meta = self.feedGroup.feed.meta;
	BOOL intervalChanged = [meta setURL:self.previousURL refresh:self.refreshNum.intValue unit:(int16_t)self.refreshUnit.indexOfSelectedItem];
	if (intervalChanged)
		[meta calculateAndSetScheduled]; // updateTimer will be scheduled once preferences is closed
	[self.feedGroup setName:self.name.stringValue andRefreshString:[meta readableRefreshString]];
	if (self.didDownloadFeed) {
		[meta setEtag:self.httpEtag modified:self.httpDate];
		[self.feedGroup.feed updateWithRSS:self.feedResult postUnreadCountChange:YES];
	}
}

/**
 Prepare UI (nullify @c result, @c error and start @c ProgressIndicator) and perform HTTP request.
 Articles will be parsed and stored in class variables.
 This should avoid unnecessary core data operations if user decides to cancel the edit.
 The save operation will only be executed if user clicks on the 'OK' button.
 */
- (void)downloadRSS {
	[self.modalSheet setDoneEnabled:NO];
	// Assuming the user has not changed title since the last fetch.
	// Reset to "" because after download it will be pre-filled with new feed title
	if ([self.name.stringValue isEqualToString:self.feedResult.title]) {
		self.name.stringValue = @"";
	}
	self.feedResult = nil;
	self.feedError = nil;
	self.httpEtag = nil;
	self.httpDate = nil;
	self.didDownloadFeed = NO;
	[self.spinnerURL startAnimation:nil];
	[self.spinnerName startAnimation:nil];
	
	[FeedDownload newFeed:self.previousURL block:^(RSParsedFeed *result, NSError *error, NSHTTPURLResponse* response) {
		dispatch_async(dispatch_get_main_queue(), ^{
			if (self.modalSheet.closeInitiated)
				return;
			self.didDownloadFeed = YES;
			self.feedResult = result;
			self.feedError = error; // MAIN THREAD!: warning indicator .hidden is bound to feedError
			self.httpEtag = [response allHeaderFields][@"Etag"];
			self.httpDate = [response allHeaderFields][@"Date"]; // @"Expires", @"Last-Modified"
			[self updateTextFieldURL:response.URL.absoluteString andTitle:result.title];
			// TODO: add icon download
			// TODO: play error sound?
			[self.spinnerURL stopAnimation:nil];
			[self.spinnerName stopAnimation:nil];
			[self.modalSheet setDoneEnabled:YES];
		});
	}];
}

/// Set UI TextField values to downloaded values. Title will be updated if TextField is empty. URL on redirect.
- (void)updateTextFieldURL:(NSString*)responseURL andTitle:(NSString*)feedTitle {
	// If URL was redirected (e.g., https redirect), replace original text field value with new one
	if (responseURL.length > 0 && ![responseURL isEqualToString:self.previousURL]) {
		self.previousURL = responseURL;
		self.url.stringValue = responseURL;
	}
	// Copy feed title to text field. (only if user hasn't set anything else yet)
	if ([self.name.stringValue isEqualToString:@""] && feedTitle.length > 0) {
		self.name.stringValue = feedTitle; // no damage to replace an empty string
	}
}

#pragma mark - NSTextField Delegate

/// Helper method to check whether url was modified since last download.
- (BOOL)urlHasChanged {
	return ![self.previousURL isEqualToString:self.url.stringValue];
}

/// Hide warning button if an error was present but the user changed the url since.
- (void)controlTextDidChange:(NSNotification *)obj {
	if (obj.object == self.url) {
		self.warningIndicator.hidden = (!self.feedError || [self urlHasChanged]);
	}
}

/// Whenever the user finished entering the url (return key or focus change) perform a download request.
- (void)controlTextDidEndEditing:(NSNotification *)obj {
	if (obj.object == self.url && [self urlHasChanged]) {
		if (self.modalSheet.closeInitiated)
			return;
		self.previousURL = self.url.stringValue;
		[self downloadRSS];
	}
}

/// Warning button next to url text field. Will be visible if an error occurs during download.
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


#pragma mark - ModalGroupEdit -


@implementation ModalGroupEdit
/// Init view and set group name if edeting an already existing object.
- (void)viewDidLoad {
	[super viewDidLoad];
	if (self.feedGroup && ![self.feedGroup hasChanges]) // hasChanges is true only if newly created
		((NSTextField*)self.view).objectValue = self.feedGroup.name;
}
/// Set one single @c NSTextField as entire view. Populate with default value and placeholder.
- (void)loadView {
	NSTextField *tf = [NSTextField textFieldWithString:NSLocalizedString(@"New Group", nil)];
	tf.placeholderString = NSLocalizedString(@"New Group", nil);
	tf.autoresizingMask = NSViewWidthSizable | NSViewMinYMargin;
	self.view = tf;
}
/// Edit of group finished. Save changes to core data object and perform save operation on delegate.
- (void)applyChangesToCoreDataObject {
	NSString *name = ((NSTextField*)self.view).stringValue;
	if (![self.feedGroup.name isEqualToString:name])
		self.feedGroup.name = name;
}
@end


#pragma mark - StrictUIntFormatter -


@interface StrictUIntFormatter : NSFormatter
@end

@implementation StrictUIntFormatter
/// Display object as integer formatted string.
- (NSString *)stringForObjectValue:(id)obj {
	return [NSString stringWithFormat:@"%d", [[NSString stringWithFormat:@"%@", obj] intValue]];
}
/// Parse any pasted input as integer.
- (BOOL)getObjectValue:(out id  _Nullable __autoreleasing *)obj forString:(NSString *)string errorDescription:(out NSString *__autoreleasing  _Nullable *)error {
	*obj = [[NSNumber numberWithInt:[string intValue]] stringValue];
	return YES;
}
/// Only digits, no other character allowed
- (BOOL)isPartialStringValid:(NSString *__autoreleasing  _Nonnull *)partialStringPtr proposedSelectedRange:(NSRangePointer)proposedSelRangePtr originalString:(NSString *)origString originalSelectedRange:(NSRange)origSelRange errorDescription:(NSString *__autoreleasing  _Nullable *)error {
	for (NSUInteger i = 0; i < [*partialStringPtr length]; i++) {
		unichar c = [*partialStringPtr characterAtIndex:i];
		if (c < '0' || c > '9')
			return NO;
	}
	return YES;
}
@end
