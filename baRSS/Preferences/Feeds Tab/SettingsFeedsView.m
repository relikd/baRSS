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

#import "SettingsFeedsView.h"
#import "StoreCoordinator.h"
#import "FeedGroup+Ext.h"
#import "FeedMeta+Ext.h"
#import "DrawImage.h"
#import "SettingsFeeds.h"
#import "NSDate+Ext.h"
#import "NSView+Ext.h"


@interface SettingsFeedsView()
@property (weak) SettingsFeeds *controller;
@end

@implementation SettingsFeedsView

- (instancetype)initWithController:(SettingsFeeds*)delegate {
	self = [super initWithFrame:NSZeroRect];
	if (self) {
		self.controller = delegate; // make sure its first
		self.outline = [self generateOutlineView]; // uses self.controller
		[self wrapContent:self.outline inScrollView:NSMakeRect(0, 20, NSWidth(self.frame), NSHeight(self.frame) - 20)];
		self.outline.menu = [self generateCommandsMenu];
		[self.outline.menu.itemArray makeObjectsPerformSelector:@selector(setTarget:) withObject:delegate];
		CGFloat x = [self generateButtons]; // uses self.controller and self.outline
		// Setup status text field ('Next update in X min.' or 'Updating X feeds ...')
		self.status = [[[[[[NSView label:@""] small] gray] textCenter] placeIn:self x:x + PAD_L y:3.5] sizeToRight:PAD_L];
		self.spinner = [[NSView activitySpinner] placeIn:self xRight:2 y:2];
	}
	return self;
}

/**
 Setup @c self.outline
 @note Requires @c self.controller
 */
- (NSOutlineView*)generateOutlineView {
	// Generate outline view
	NSOutlineView *o = [[NSOutlineView alloc] init];
	o.columnAutoresizingStyle = NSTableViewFirstColumnOnlyAutoresizingStyle;
	o.usesAlternatingRowBackgroundColors = YES;
	o.allowsMultipleSelection = YES;
	o.allowsColumnReordering = NO;
	o.allowsColumnSelection = NO;
	o.allowsEmptySelection = YES;
	//o.intercellSpacing = NSMakeSize(3, 2);
	o.rowHeight = 18;
	
	[self setOutlineColumns:o];
	
	// Setup action and bindings
	SettingsFeeds *sf = self.controller;
	o.delegate = sf;
	o.dataSource = sf;
	o.target = sf;
	o.doubleAction = @selector(doubleClickOutlineView:);
	
	[o bind:NSContentBinding toObject:sf.dataStore withKeyPath:@"arrangedObjects" options:nil]; // @{NSAlwaysPresentsApplicationModalAlertsBindingOption:@YES}
	[o bind:NSSelectionIndexPathsBinding toObject:sf.dataStore withKeyPath:@"selectionIndexPaths" options:nil];
	return o;
}

/// Generate table columns 'Name' and 'Refresh'
- (void)setOutlineColumns:(NSOutlineView*)outline {
	NSTableColumn *colName = [[NSTableColumn alloc] initWithIdentifier:CustomCellName];
	colName.title = NSLocalizedString(@"Name", nil);
	colName.width = 10000;
	colName.maxWidth = 10000;
	colName.resizingMask = NSTableColumnAutoresizingMask;
	[outline addTableColumn:colName];
	
	NSTableColumn *colRefresh = [[NSTableColumn alloc] initWithIdentifier:CustomCellRefresh];
	colRefresh.title = NSLocalizedString(@"Refresh", nil);
	colRefresh.width = 60;
	colRefresh.resizingMask = NSTableColumnNoResizing;
	[outline addTableColumn:colRefresh];
	
	for (NSTableColumn *col in outline.tableColumns) {
		col.headerCell.title = [NSString stringWithFormat:@" %@", col.title];
		NSDictionary *attr = @{ NSFontAttributeName: [NSFont systemFontOfSize:NSFont.smallSystemFontSize weight:NSFontWeightMedium] };
		col.headerCell.attributedStringValue = [[NSAttributedString alloc] initWithString:col.title attributes:attr];
	}
	outline.outlineTableColumn = colName;
}

/// Setup right click menu (also used for hotkeys).
- (NSMenu*)generateCommandsMenu {
	NSMenu *m = [[NSMenu alloc] initWithTitle:@""];
	[m addItemWithTitle:NSLocalizedString(@"Edit Item", nil) action:@selector(editSelectedItem) keyEquivalent:[NSString stringWithFormat:@"%c", NSCarriageReturnCharacter]].keyEquivalentModifierMask = 0;
	[m addItemWithTitle:NSLocalizedString(@"Delete Item(s)", nil) action:@selector(remove:) keyEquivalent:[NSString stringWithFormat:@"%c", NSBackspaceCharacter]];
	[m addItem:[NSMenuItem separatorItem]]; // index: 2
	[m addItemWithTitle:NSLocalizedString(@"New Feed", nil) action:@selector(addFeed) keyEquivalent:@"n"];
	[m addItemWithTitle:NSLocalizedString(@"New Group", nil) action:@selector(addGroup) keyEquivalent:@"g"];
	[m addItemWithTitle:NSLocalizedString(@"New Separator", nil) action:@selector(addSeparator) keyEquivalent:@""];
	[m addItem:[NSMenuItem separatorItem]]; // index: 6
	[m addItemWithTitle:NSLocalizedString(@"Import Feeds …", nil) action:@selector(openImportDialog) keyEquivalent:@""];
	[m addItemWithTitle:NSLocalizedString(@"Export Feeds …", nil) action:@selector(openExportDialog) keyEquivalent:@""];
	[m addItem:[NSMenuItem separatorItem]]; // index: 9
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wundeclared-selector"
	[m addItemWithTitle:NSLocalizedString(@"Undo", nil) action:@selector(undo:) keyEquivalent:@"z"];
	[m addItemWithTitle:NSLocalizedString(@"Redo", nil) action:@selector(redo:) keyEquivalent:@"Z"];
#pragma clang diagnostic pop
	return m;
}

/**
 Setup the bottom button bar. (e.g., add, remove, edit, export, import, etc.)
 @note Requires @c self.controller and @c self.outline
 
 @return Max x-value of last button frame
 */
- (CGFloat)generateButtons {
	NSButton *add = [[NSView buttonImageSquare:NSImageNameAddTemplate] tooltip:NSLocalizedString(@"Add new item", nil)];
	NSButton *del = [[NSView buttonImageSquare:NSImageNameRemoveTemplate] tooltip:NSLocalizedString(@"Delete selected items", nil)];
	NSButton *share = [[NSView buttonImageSquare:NSImageNameShareTemplate] tooltip:NSLocalizedString(@"Import or export data", nil)];
	
	[self button:add copyActions:3 to:5];
	[self button:del copyActions:1 to:1];
	[self button:share copyActions:7 to:8]; // TODO: Add menus for online sync? email export? etc.
	
	[add placeIn:self x:0 y:0];
	[del placeIn:self x:24 y:0];
	[share placeIn:self x:2 * 24 + PAD_L y:0];
	
	NSTreeController *tc = self.controller.dataStore;
	[add bind:NSEnabledBinding toObject:tc withKeyPath:@"canInsert" options:nil];
	[del bind:NSEnabledBinding toObject:tc withKeyPath:@"canRemove" options:nil];
	return NSMaxX(share.frame);
}

/**
 Duplicate right click menu actions to button
 @note Requires @c self.outline
*/
- (void)button:(NSButton*)btn copyActions:(NSInteger)start to:(NSInteger)end {
	if (start < 0 || start > end || end >= self.outline.menu.numberOfItems) {
		NSAssert(NO, @"Invalid index, can't copy command menu items.");
		return;
	}
	if (start == end) {
		// copy menu item action to button action
		NSMenuItem *source = [self.outline.menu itemAtIndex:start];
		[btn action:source.action target:source.target];
		btn.keyEquivalent = source.keyEquivalent;
		btn.keyEquivalentModifierMask = source.keyEquivalentModifierMask;
	} else {
		// create drop down menu with all options
		btn.menu = [[NSMenu alloc] initWithTitle:@""];
		[btn action:@selector(openButtonMenu:) target:self];
		for (NSInteger i = start; i <= end; i++) {
			[btn.menu addItem:[[self.outline.menu itemAtIndex:i] copy]];
		}
	}
}

/// Show drop down menu even for left click.
- (void)openButtonMenu:(NSButton*)sender {
	//[NSMenu popUpContextMenu:sender.menu withEvent:[NSApp currentEvent] forView:sender];
	[sender.menu popUpMenuPositioningItem:nil atLocation:NSMakePoint(0, NSHeight(sender.frame)) inView:sender];
}

@end


#pragma mark - Custom Outline View Cells -


/**
 First outline view column, with textfield and feed icon
 */
@implementation NameColumnCell
/// Identifier for cell with @c .imageView (feed icon) and @c .textField (feed title)
NSUserInterfaceItemIdentifier const CustomCellName = @"NameColumnCell";

- (instancetype)initWithFrame:(NSRect)frameRect {
	self = [super initWithFrame:frameRect];
	self.identifier = CustomCellName;
	self.imageView = [[NSView imageView:nil size:16] placeIn:self x:1 yTop:1];
	self.imageView.accessibilityLabel = NSLocalizedString(@"Feed icon", nil);
	self.textField = [[[NSView label:@""] placeIn:self x:25 yTop:0] sizeToRight:0];
	self.textField.accessibilityLabel = NSLocalizedString(@"Feed title", nil);
	return self;
}

- (void)setObjectValue:(FeedGroup*)fg {
	self.textField.objectValue = fg.name;
	self.imageView.image = fg.iconImage16;
}

@end


/**
 Second outline view column, either refresh string or empty
 */
@implementation RefreshColumnCell
/// Identifier for cell with @c .textField (refresh string or empty)
NSUserInterfaceItemIdentifier const CustomCellRefresh = @"RefreshColumnCell";

- (instancetype)initWithFrame:(NSRect)frameRect {
	self = [super initWithFrame:frameRect];
	self.identifier = CustomCellRefresh;
	self.textField = [[[[NSView label:@""] textRight] placeIn:self x:0 yTop:0] sizeToRight:0];
	self.textField.accessibilityTitle = @" "; // otherwise groups and separators will say 'text'
	return self;
}

- (void)setObjectValue:(FeedGroup*)fg {
	NSString *str = @"";
	if (fg.type == FEED) {
		int32_t refresh = fg.feed.meta.refresh;
		str = (refresh <= 0 ? @"∞" : [NSDate intStringForInterval:refresh]); // ∞ ƒ Ø
	}
	self.textField.objectValue = str;
	self.textField.textColor = (str.length > 1 ? [NSColor controlTextColor] : [NSColor disabledControlTextColor]);
	self.textField.accessibilityLabel = (str.length > 1 ? NSLocalizedString(@"Refresh interval", nil) : nil);
}

@end


/**
 First outline view column, separator line
 */
@implementation SeparatorColumnCell
/// Identifier for cell with line separator
NSUserInterfaceItemIdentifier const CustomCellSeparator = @"SeparatorColumnCell";

- (instancetype)initWithFrame:(NSRect)frameRect {
	self = [super initWithFrame:frameRect];
	self.identifier = CustomCellSeparator;
	[[[[DrawSeparator alloc] initWithFrame:self.frame] placeIn:self x:0 y:0] sizableWidthAndHeight];
	return self;
}

- (void)setObjectValue:(FeedGroup*)fg { /* do nothing */ }

@end
