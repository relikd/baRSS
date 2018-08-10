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
#import "NewsController.h"
#import "FeedConfig+CoreDataProperties.h"

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
@property (strong) NSError *feedError;
@property (strong) NSDictionary *feedResult;

@property (assign) BOOL shouldEvaluate;
@property (assign) BOOL lateEvaluation;
@end

@implementation ModalFeedEdit

- (void)viewDidLoad {
	[super viewDidLoad];
	self.previousURL = @"";
	self.refreshNum.intValue = 30;
	self.shouldEvaluate = NO;
	
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
	FeedConfig *item = [self feedConfigOrNil];
	if (self.shouldEvaluate && self.lateEvaluation && item) {
		if (!item.name || [item.name isEqualToString:@""]) {
			[self setTitleFromFeed];
			if (![item.name isEqualToString: self.name.stringValue]) // only if result isnt empty as well
				item.name = self.name.stringValue;
			[item.managedObjectContext refreshAllObjects];
		}
		
	}
}

- (void)updateRepresentedObject {
	FeedConfig *item = [self feedConfigOrNil];
	if (item) {
		// if's to prevent unnecessary undo groups if nothing has changed
		if (![item.name isEqualToString: self.name.stringValue])
			item.name = self.name.stringValue;
		if (![item.url isEqualToString:self.url.stringValue])
			item.url = self.url.stringValue;
		if (item.refreshNum != self.refreshNum.intValue)
			item.refreshNum = self.refreshNum.intValue;
		if (item.refreshUnit != self.refreshUnit.indexOfSelectedItem)
			item.refreshUnit = (int16_t)self.refreshUnit.indexOfSelectedItem;
		
		self.shouldEvaluate = YES;
		self.lateEvaluation = NO;
		// TODO: append feed result
		NSLog(@"here i want to set it");
		[item.managedObjectContext refreshAllObjects];
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
		self.previousURL = self.url.stringValue;
		self.feedResult = nil;
		NSLog(@"setting result to nil");
		self.feedError = nil;
		[self.spinnerURL startAnimation:nil];
		[self.spinnerName startAnimation:nil];
		[NewsController downloadFeed:self.previousURL withBlock:^(NSDictionary *result, NSError *error) {
			self.feedResult = result;
			NSLog(@"got results back");
			self.feedError = error; // warning indicator .hidden is bound to feedError
			// TODO: play error sound?
			dispatch_async(dispatch_get_main_queue(), ^{
				self.lateEvaluation = YES; // stays YES if this block runs after updateRepresentedObject:
				[self setTitleFromFeed];
				[self.spinnerURL stopAnimation:nil];
				[self.spinnerName stopAnimation:nil];
			});
		}];
	}
	// http://feeds.feedburner.com/simpledesktops
}

- (void)setTitleFromFeed {
	if ([self.name.stringValue isEqualToString:@""]) {
		self.name.objectValue = self.feedResult[@"feed"][@"title"];
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
- (void)viewDidLoad {
	[super viewDidLoad];
	if ([self.representedObject isKindOfClass:[FeedConfig class]]) {
		FeedConfig *fc = self.representedObject;
		((NSTextField*)self.view).objectValue = fc.name;
	}
}
- (void)loadView {
	NSTextField *tf = [NSTextField textFieldWithString:@"New Group"];
	tf.placeholderString = @"New Group";
	tf.autoresizingMask = NSViewWidthSizable | NSViewMinYMargin;
	self.view = tf;
}
- (void)updateRepresentedObject {
	if ([self.representedObject isKindOfClass:[FeedConfig class]]) {
		FeedConfig *item = self.representedObject;
		NSString *name = ((NSTextField*)self.view).stringValue;
		if (![item.name isEqualToString: name]) {
			item.name = name;
			[item.managedObjectContext refreshAllObjects];
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