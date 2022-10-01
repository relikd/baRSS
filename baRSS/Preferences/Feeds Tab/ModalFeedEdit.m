@import RSXML2;
#import "ModalFeedEdit.h"
#import "ModalFeedEditView.h"
#import "RefreshStatisticsView.h"
#import "Constants.h"
#import "FeedDownload.h"
#import "FaviconDownload.h"
#import "Feed+Ext.h"
#import "FeedMeta+Ext.h"
#import "FeedGroup+Ext.h"
#import "NSView+Ext.h"
#import "NSDate+Ext.h"
#import "NSURL+Ext.h"

// ################################################################
// #
// #  MARK: - ModalEditDialog -
// #
// ################################################################

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

// ################################################################
// #
// #  MARK: - ModalFeedEdit -
// #
// ################################################################

@interface ModalFeedEdit() <FeedDownloadDelegate, RefreshIntervalButtonDelegate, FaviconDownloadDelegate>
@property (strong) IBOutlet ModalFeedEditView *view; // override

@property (copy) NSString *previousURL; // check if changed and avoid multiple download
@property (strong) NSURL *faviconFile;
@property (strong) FeedDownload *memFeed;
@property (weak) FaviconDownload *memIcon;
@property (strong) RefreshStatisticsView *statisticsView;
@end

@implementation ModalFeedEdit
@dynamic view;

/// Init feed edit dialog with default values.
- (void)loadView {
	self.view = [[ModalFeedEditView alloc] initWithController:self];
	self.previousURL = @"";
	self.view.refreshNum.intValue = 30;
	[NSDate populateUnitsMenu:self.view.refreshUnit selected:TimeUnitMinutes];
	[self populateTextFields:self.feedGroup];
}

/// Pre-fill UI control field values with @c FeedGroup properties.
- (void)populateTextFields:(FeedGroup*)fg {
	if (!fg || [fg hasChanges]) return; // hasChanges is true only if newly created
	self.view.name.objectValue = fg.name; // user given feed title
	self.view.name.placeholderString = fg.feed.title; // actual feed title
	self.view.url.objectValue = fg.feed.meta.url;
	self.previousURL = self.view.url.stringValue;
	self.view.favicon.image = [fg.feed iconImage16];
	[NSDate setInterval:fg.feed.meta.refresh forPopup:self.view.refreshUnit andField:self.view.refreshNum animate:NO];
	[self statsForCoreDataObject];
}

- (void)dealloc {
	[self.faviconFile remove]; // Delete temporary favicon (if still exists)
}

#pragma mark - Edit Feed Data

/**
 Use UI control field values to update the represented core data object. Also parse new articles if applicable.
 Set @c scheduled to a new date if refresh interval was changed.
 */
- (void)applyChangesToCoreDataObject {
	Feed *f = self.feedGroup.feed;
	Interval intv = [NSDate intervalForPopup:self.view.refreshUnit andField:self.view.refreshNum];
	[self.feedGroup setNameIfChanged:self.view.name.stringValue];
	[f.meta setRefreshIfChanged:intv];
	if (self.memFeed) {
		[self.memFeed copyValuesTo:f ignoreError:YES];
		[f setNewIcon:self.faviconFile]; // only if downloaded anything (nil deletes icon!)
		self.faviconFile = nil;
	}
}

/// Cancel any running download task and free volatile variables
- (void)cancelDownloads {
	[self.memFeed cancel];  self.memFeed = nil;
	[self.memIcon cancel];  self.memIcon = nil;
	[self.faviconFile remove];  self.faviconFile = nil;
}

/**
 Prepare UI (nullify results and start @c ProgressIndicator ).
 Also disable 'Done' button during download and re-enable after download is finished.
 */
- (void)downloadRSS {
	[self cancelDownloads];
	[self.modalSheet setDoneEnabled:NO]; // prevent user from closing the dialog during download
	[self.view.spinnerURL startAnimation:nil];
	[self.view.spinnerName startAnimation:nil];
	self.view.favicon.image = nil;
	self.view.warningButton.hidden = YES;
	// User didn't change title since last fetch. Will be pre-filled with new title after download
	if ([self.view.name.stringValue isEqualToString:self.view.name.placeholderString]) {
		self.view.name.stringValue = @"";
		self.view.name.placeholderString = NSLocalizedString(@"Loading …", nil);
	}
	self.previousURL = self.view.url.stringValue;
	self.memFeed = [[FeedDownload withURL:self.previousURL] startWithDelegate:self];
}

/**
 If entered URL happens to be a normal webpage, @c RSXML will parse all suitable feed links.
 Present this list to the user and let her decide which one it should be.
 
 @return Either URL string or @c nil if user canceled the selection.
 */
- (NSString*)feedDownload:(FeedDownload*)sender selectFeedFromList:(NSArray<RSHTMLMetadataFeedLink*>*)list {
	NSMenu *menu = [[NSMenu alloc] initWithTitle:NSLocalizedString(@"Choose feed menu", nil)];
	menu.autoenablesItems = NO;
	for (RSHTMLMetadataFeedLink *fl in list) {
		[menu addItemWithTitle:fl.title action:nil keyEquivalent:@""];
	}
	NSPoint belowURL = NSMakePoint(0, NSHeight(self.view.url.frame));
	if ([menu popUpMenuPositioningItem:nil atLocation:belowURL inView:self.view.url]) {
		NSInteger idx = [menu indexOfItem:menu.highlightedItem];
		if (idx < 0) idx = 0; // User hit enter without selection. Assume first item, because PopUpMenu did return YES!
		return [list objectAtIndex:(NSUInteger)idx].link;
	}
	return nil; // user selection canceled
}

/// If URL was redirected, replace original text field value with new one. (e.g., https redirect)
- (void)feedDownload:(FeedDownload*)sender urlRedirected:(NSString*)newURL {
	if (!sender.error) {
		// If the url has changed and there is an error:
		// This probably means the feed URL was resolved, but the successive download returned 5xx error.
		// Presumably to prevent site crawlers accessing many pages in quick succession. (delay of 1s does help)
		// By not setting previousURL, a second hit on the 'Done' button will retry the resolved URL again.
		self.previousURL = newURL;
	}
	self.view.url.stringValue = newURL;
}

/// Update UI TextFields with downloaded values. Title updated if TextField is empty, URL if redirect.
- (void)feedDownloadDidFinish:(FeedDownload*)sender {
	// Stop spinner for name field but keep running for URL until favicon downloaded
	[self.view.spinnerName stopAnimation:nil];
	NSString *newTitle = sender.xmlfeed.title;
	self.view.name.placeholderString = newTitle;
	if (newTitle.length > 0 && self.view.name.stringValue.length == 0) {
		self.view.name.stringValue = newTitle; // only if default title wasn't changed
	}
	// TODO: user preference to automatically select refresh interval (selection: None,min,max,avg,median)
	[self statsForDownloadObject:sender.xmlfeed.articles];
	BOOL hasError = (sender.error != nil);
	self.view.favicon.hidden = hasError;
	self.view.warningButton.hidden = !hasError;
	// Start favicon download
	if (hasError)
		[self downloadComplete];
	else
		self.memIcon = [[sender faviconDownload] startWithDelegate:self];
}

/**
 The last step of the download process.
 Stop spinning animation, set favivon image (right of url bar), and re-enable 'Done' button.
 */
- (void)faviconDownload:(FaviconDownload*)sender didFinish:(nullable NSURL*)path {
	// Create image from favicon temporary file location or default icon if no favicon exists.
	NSImage *img;
	if (path) {
		NSData* data = [[NSData alloc] initWithContentsOfURL:path];
		img = [[NSImage alloc] initWithData:data];
	} else {
		img = [NSImage imageNamed:RSSImageDefaultRSSIcon];
	}
	self.view.favicon.image = img;
	self.faviconFile = path;
	[self downloadComplete];
}

/// Called regardless of favicon download.
- (void)downloadComplete {
	[self.view.spinnerURL stopAnimation:nil];
	[self.modalSheet setDoneEnabled:YES];
}

#pragma mark - Feed Statistics

/// Perform statistics on newly downloaded feed item
- (void)statsForDownloadObject:(NSArray<RSParsedArticle*>*)articles {
	NSMutableArray<NSDate*> *arr = [NSMutableArray arrayWithCapacity:articles.count];
	for (RSParsedArticle *a in articles) {
		NSDate *d = a.datePublished;
		if (!d) d = a.dateModified;
		if (!d) continue;
		[arr addObject:d];
	}
	[self appendViewWithFeedStatistics:arr count:articles.count];
}

/// Perform statistics on stored core data object
- (void)statsForCoreDataObject {
	NSArray<FeedArticle*> *articles = [self.feedGroup.feed sortedArticles];
	[self appendViewWithFeedStatistics:[articles valueForKeyPath:@"published"] count:articles.count];
}

/// Generate statistics UI with buttons to quickly select refresh unit and duration.
- (void)appendViewWithFeedStatistics:(NSArray*)dates count:(NSUInteger)count {
	CGFloat prevHeight = 0.f;
	if (self.statisticsView != nil) {
		prevHeight = NSHeight(self.statisticsView.frame) + PAD_L;
		[self.statisticsView removeFromSuperview];
		self.statisticsView = nil;
	}
	
	NSDictionary *stats = [NSDate refreshIntervalStatistics:dates];
	RefreshStatisticsView *rsv = [[RefreshStatisticsView alloc] initWithRefreshInterval:stats articleCount:count callback:self];
	[[self getModalSheet] extendContentViewBy:NSHeight(rsv.frame) + PAD_L - prevHeight];
	self.statisticsView = [rsv placeIn:self.view x:CENTER y:0];
}

/// Callback method @c RefreshStatisticsView
- (void)refreshIntervalButtonClicked:(NSButton *)sender {
	[NSDate setInterval:(Interval)sender.tag forPopup:self.view.refreshUnit andField:self.view.refreshNum animate:YES];
}


#pragma mark - NSTextField Delegate


/// Window delegate will be only called on button 'Done'.
- (BOOL)windowShouldClose:(ModalSheet*)sender {
	if (sender.didTapCancel) {
		[self cancelDownloads];
	} else if (![self.previousURL isEqualToString:self.view.url.stringValue]) { // 'Done' button
		[[NSNotificationCenter defaultCenter] postNotificationName:NSControlTextDidEndEditingNotification object:self.view.url];
		return NO;
	}
	return YES;
}

/// Whenever the user finished entering the url (return key or focus change) perform a download request.
- (void)controlTextDidEndEditing:(NSNotification*)obj {
	if (obj.object == self.view.url && !self.modalSheet.didTapCancel) {
		if (![self.previousURL isEqualToString:self.view.url.stringValue]) {
			[self downloadRSS];
		}
	}
}

/// Warning button next to url text field. Will be visible if an error occurs during download.
- (void)didClickWarningButton:(NSButton*)sender {
	NSError *err = self.memFeed.error;
	if (!err) return;
	
	// show reload button if server is temporarily offline (any 5xx server error)
	BOOL serverError = (err.code == NSURLErrorBadServerResponse && err.domain == NSURLErrorDomain);
	self.view.warningReload.hidden = !serverError;
	
	// set error description as text
	if (serverError)
		self.view.warningText.stringValue = [NSString stringWithFormat:@"%@\n––––\n%@", err.localizedDescription, err.localizedRecoverySuggestion];
	else
		self.view.warningText.objectValue = err.localizedDescription;
	NSSize newSize = self.view.warningText.fittingSize; // width is limited by the textfield's preferred width
	newSize.width += 2 * self.view.warningText.frame.origin.x; // the padding
	newSize.height += 2 * self.view.warningText.frame.origin.y;
	
	// apply fitting size and display
	self.view.warningPopover.contentSize = newSize;
	[self.view.warningPopover showRelativeToRect:NSZeroRect ofView:sender preferredEdge:NSRectEdgeMinY];
}

/// Either hit by Cmd+R or reload button inside warning popover error description
- (void)reloadData {
	[self downloadRSS];
}

@end

// ################################################################
// #
// #  MARK: - ModalGroupEdit -
// #
// ################################################################

@implementation ModalGroupEdit
/// Init view and set group name if edeting an already existing object.
- (void)viewDidLoad {
	[super viewDidLoad];
	if (self.feedGroup && ![self.feedGroup hasChanges]) // hasChanges is true only if newly created
		((NSTextField*)self.view).objectValue = self.feedGroup.name;
}
/// Set one single @c NSTextField as entire view. Populate with default value and placeholder.
- (void)loadView {
	self.view = [[NSView inputField:NSLocalizedString(@"New Group Name", nil) width:0] sizeToRight:0];
}
/// Edit of group finished. Save changes to core data object and perform save operation on delegate.
- (void)applyChangesToCoreDataObject {
	[self.feedGroup setNameIfChanged:((NSTextField*)self.view).stringValue];
}
@end
