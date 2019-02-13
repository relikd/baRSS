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
#import "Statistics.h"
#import "NSDate+Ext.h"


#pragma mark - ModalEditDialog -


@interface ModalEditDialog() <NSWindowDelegate>
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
	if (!self.modalSheet) {
		self.modalSheet = [[ModalSheet alloc] initWithView:self.view];
		self.modalSheet.delegate = self;
	}
	return self.modalSheet;
}
/// This method should be overridden by subclasses. Used to save changes to persistent store.
- (void)applyChangesToCoreDataObject {
	NSLog(@"[%@] is missing method: -(void)applyChangesToCoreDataObject", [self class]);
	NSAssert(NO, @"Override required!");
}
@end


#pragma mark - ModalFeedEdit -


@interface ModalFeedEdit() <RefreshIntervalButtonDelegate>
@property (weak) IBOutlet NSTextField *url;
@property (weak) IBOutlet NSTextField *name;
@property (weak) IBOutlet NSTextField *refreshNum;
@property (weak) IBOutlet NSPopUpButton *refreshUnit;
@property (weak) IBOutlet NSProgressIndicator *spinnerURL;
@property (weak) IBOutlet NSProgressIndicator *spinnerName;
@property (weak) IBOutlet NSButton *warningIndicator;
@property (weak) IBOutlet NSPopover *warningPopover;
@property (strong) NSView *statisticsView;

@property (copy) NSString *previousURL; // check if changed and avoid multiple download
@property (copy) NSString *httpDate;
@property (copy) NSString *httpEtag;
@property (copy) NSString *faviconURL;
@property (strong) NSImage *favicon;
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
	[NSDate populateUnitsMenu:self.refreshUnit selected:TimeUnitMinutes];
	self.warningIndicator.image = nil;
	[self.warningIndicator.cell setHighlightsBy:NSNoCellMask];
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
	self.warningIndicator.image = [fg.feed iconImage16];
	[NSDate setInterval:fg.feed.meta.refresh forPopup:self.refreshUnit andField:self.refreshNum animate:NO];
	[self statsForCoreDataObject];
}

#pragma mark - Edit Feed Data

/**
 Use UI control field values to update the represented core data object. Also parse new articles if applicable.
 Set @c scheduled to a new date if refresh interval was changed.
 */
- (void)applyChangesToCoreDataObject {
	Feed *feed = self.feedGroup.feed;
	[self.feedGroup setNameIfChanged:self.name.stringValue];
	FeedMeta *meta = feed.meta;
	[meta setUrlIfChanged:self.previousURL];
	[meta setRefreshAndSchedule:[NSDate intervalForPopup:self.refreshUnit andField:self.refreshNum]];
	// updateTimer will be scheduled once preferences is closed
	if (self.didDownloadFeed) {
		[meta setEtag:self.httpEtag modified:self.httpDate];
		[feed updateWithRSS:self.feedResult postUnreadCountChange:YES];
		[feed setIconImage:self.favicon];
	}
}

/**
 Prepare UI (nullify @c result, @c error and start @c ProgressIndicator).
 Also disable 'Done' button during download and re-enable after all downloads are finished.
 */
- (void)preDownload {
	[self.modalSheet setDoneEnabled:NO]; // prevent user from closing the dialog during download
	[self.spinnerURL startAnimation:nil];
	[self.spinnerName startAnimation:nil];
	self.warningIndicator.image = nil;
	self.didDownloadFeed = NO;
	// Assuming the user has not changed title since the last fetch.
	// Reset to "" because after download it will be pre-filled with new feed title
	if ([self.name.stringValue isEqualToString:self.feedResult.title]) {
		self.name.stringValue = @"";
	}
	self.feedResult = nil;
	self.feedError = nil;
	self.httpEtag = nil;
	self.httpDate = nil;
	self.favicon = nil;
	self.faviconURL = nil;
}

/**
 All properties will be parsed and stored in class variables.
 This should avoid unnecessary core data operations if user decides to cancel the edit.
 The save operation will only be executed if user clicks on the 'OK' button.
 */
- (void)downloadRSS {
	if (self.modalSheet.didCloseAndCancel)
		return;
	[self preDownload];
	[FeedDownload newFeed:self.previousURL askUser:^NSString *(RSHTMLMetadata *meta) {
		self.faviconURL = [FeedDownload faviconUrlForMetadata:meta]; // we can re-use favicon url if we find one
		return [self letUserChooseXmlUrlFromList:meta.feedLinks];
	} block:^(RSParsedFeed *result, NSError *error, NSHTTPURLResponse* response) {
		if (self.modalSheet.didCloseAndCancel)
			return;
		self.didDownloadFeed = YES;
		self.feedResult = result;
		self.feedError = error;
		self.httpEtag = [response allHeaderFields][@"Etag"];
		self.httpDate = [response allHeaderFields][@"Date"]; // @"Expires", @"Last-Modified"
		[self postDownload:response.URL.absoluteString];
	}];
}

/**
 If entered URL happens to be a normal webpage, @c RSXML will parse all suitable feed links.
 Present this list to the user and let her decide which one it should be.
 
 @return Either URL string or @c nil if user canceled the selection.
 */
- (NSString*)letUserChooseXmlUrlFromList:(NSArray<RSHTMLMetadataFeedLink*> *)list {
	if (list.count == 1) // nothing to choose
		return list.firstObject.link;
	NSMenu *menu = [[NSMenu alloc] initWithTitle:NSLocalizedString(@"Choose feed menu", nil)];
	menu.autoenablesItems = NO;
	for (RSHTMLMetadataFeedLink *fl in list) {
		[menu addItemWithTitle:fl.title action:nil keyEquivalent:@""];
	}
	NSPoint belowURL = NSMakePoint(0,self.url.frame.size.height);
	if ([menu popUpMenuPositioningItem:nil atLocation:belowURL inView:self.url]) {
		NSInteger idx = [menu indexOfItem:menu.highlightedItem];
		if (idx < 0) idx = 0; // User hit enter without selection. Assume first item, because PopUpMenu did return YES!
		return [list objectAtIndex:(NSUInteger)idx].link;
	}
	return nil; // user selection canceled
}

/**
 Update UI TextFields with downloaded values.
 Title will be updated if TextField is empty. URL on redirect.
 Finally begin favicon download and return control to user (enable 'Done' button).
 */
- (void)postDownload:(NSString*)responseURL {
	if (self.modalSheet.didCloseAndCancel)
		return;
	// 1. Stop spinner animation for name field. (keep spinner for URL running until favicon downloaded)
	[self.spinnerName stopAnimation:nil];
	// 2. If URL was redirected, replace original text field value with new one. (e.g., https redirect)
	if (responseURL.length > 0 && ![responseURL isEqualToString:self.previousURL]) {
		self.previousURL = responseURL;
		self.url.stringValue = responseURL;
	}
	// 3. Copy parsed feed title to text field. (only if user hasn't set anything else yet)
	NSString *parsedTitle = self.feedResult.title;
	if (parsedTitle.length > 0 && [self.name.stringValue isEqualToString:@""]) {
		self.name.stringValue = parsedTitle; // no damage to replace an empty string
	}
	// TODO: user preference to automatically select refresh interval (selection: None,min,max,avg,median)
	[self statsForDownloadObject];
	// 4. Continue with favicon download (or finish with error)
	if (self.feedError) {
		[self finishDownloadWithFavicon:[NSImage imageNamed:NSImageNameCaution]];
	} else {
		if (!self.faviconURL)
			self.faviconURL = self.feedResult.link;
		if (self.faviconURL.length == 0)
			self.faviconURL = responseURL;
		[FeedDownload downloadFavicon:self.faviconURL finished:^(NSImage * _Nullable img) {
			if (self.modalSheet.didCloseAndCancel)
				return;
			self.favicon = img;
			[self finishDownloadWithFavicon:img];
		}];
	}
}

/**
 The last step of the download process.
 Stop spinning animation set favivon image preview (right of url bar) and re-enable 'Done' button.
 */
- (void)finishDownloadWithFavicon:(NSImage*)img {
	if (self.modalSheet.didCloseAndCancel)
		return;
	[self.warningIndicator.cell setHighlightsBy: (self.feedError ? NSContentsCellMask : NSNoCellMask)];
	self.warningIndicator.image = img;
	[self.spinnerURL stopAnimation:nil];
	[self.modalSheet setDoneEnabled:YES];
}

#pragma mark - Feed Statistics

/// Perform statistics on newly downloaded feed item
- (void)statsForDownloadObject {
	NSMutableArray<NSDate*> *arr = [NSMutableArray arrayWithCapacity:self.feedResult.articles.count];
	for (RSParsedArticle *a in self.feedResult.articles) {
		NSDate *d = a.datePublished;
		if (!d) d = a.dateModified;
		if (!d) continue;
		[arr addObject:d];
	}
	[self appendViewWithFeedStatistics:arr count:self.feedResult.articles.count];
}

/// Perform statistics on stored core data object
- (void)statsForCoreDataObject {
	NSArray<FeedArticle*> *articles = [self.feedGroup.feed sortedArticles];
	[self appendViewWithFeedStatistics:[articles valueForKeyPath:@"published"] count:articles.count];
}

/// Generate statistics UI with buttons to quickly select refresh unit and duration.
- (void)appendViewWithFeedStatistics:(NSArray*)dates count:(NSUInteger)count {
	static const CGFloat statsPadding = 15.f;
	CGFloat prevHeight = 0.f;
	if (self.statisticsView != nil) {
		prevHeight = self.statisticsView.frame.size.height + statsPadding;
		[self.statisticsView removeFromSuperview];
		self.statisticsView = nil;
	}
	NSDictionary *stats = [Statistics refreshInterval:dates];
	NSView *v = [Statistics viewForRefreshInterval:stats articleCount:count callback:self];
	[[self getModalSheet] extendContentViewBy:v.frame.size.height + statsPadding - prevHeight];
	[v setFrameOrigin:NSMakePoint(0.5f*(NSWidth(self.view.frame) - NSWidth(v.frame)), 0)];
	[self.view addSubview:v];
	self.statisticsView = v;
}

/// Callback method for @c Statistics @c +viewForRefreshInterval:articleCount:callback:
- (void)refreshIntervalButtonClicked:(NSButton *)sender {
	[NSDate setInterval:(Interval)sender.tag forPopup:self.refreshUnit andField:self.refreshNum animate:YES];
}


#pragma mark - NSTextField Delegate


/// Window delegate will be only called on button 'Done'.
- (BOOL)windowShouldClose:(NSWindow *)sender {
	if (![self.previousURL isEqualToString:self.url.stringValue]) {
		[[NSNotificationCenter defaultCenter] postNotificationName:NSControlTextDidEndEditingNotification object:self.url];
		return NO;
	}
	return YES;
}

/// Whenever the user finished entering the url (return key or focus change) perform a download request.
- (void)controlTextDidEndEditing:(NSNotification *)obj {
	if (obj.object == self.url) {
		if (![self.previousURL isEqualToString:self.url.stringValue]) {
			self.previousURL = self.url.stringValue;
			[self downloadRSS];
		}
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
	[self.feedGroup setNameIfChanged:((NSTextField*)self.view).stringValue];
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
