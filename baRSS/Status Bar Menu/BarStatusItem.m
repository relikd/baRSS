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

#import "BarStatusItem.h"
#import "Constants.h"
#import "FeedDownload.h"
#import "StoreCoordinator.h"
#import "UserPrefs.h"
#import "BarMenu.h"
#import "AppHook.h"
#import "NSView+Ext.h"

@interface BarStatusItem()
@property (strong) BarMenu *barMenu;
@property (strong) NSStatusItem *statusItem;
@property (assign) NSInteger unreadCountTotal;
@property (weak) NSMenuItem *updateAllItem;
@end

@implementation BarStatusItem

- (NSMenu *)mainMenu { return _statusItem.menu; }

- (instancetype)init {
	self = [super init];
	// Show icon & prefetch unread count
	self.statusItem = [NSStatusBar.systemStatusBar statusItemWithLength:NSVariableStatusItemLength];
	self.statusItem.highlightMode = YES;
	self.unreadCountTotal = 0;
	self.statusItem.image = [NSImage imageNamed:RSSImageMenuBarIconActive];
	self.statusItem.image.template = YES;
	// Add empty menu (will be populated once opened)
	self.statusItem.menu = [[NSMenu alloc] initWithTitle:@"M"];
	[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(mainMenuWillOpen) name:NSMenuDidBeginTrackingNotification object:self.statusItem.menu];
	[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(mainMenuDidClose) name:NSMenuDidEndTrackingNotification object:self.statusItem.menu];
	// Some icon unread count notification callback methods
	[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(networkChanged:) name:kNotificationNetworkStatusChanged object:nil];
	[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(unreadCountChanged:) name:kNotificationTotalUnreadCountChanged object:nil];
	[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(unreadCountReset:) name:kNotificationTotalUnreadCountReset object:nil];
	return self;
}

- (void)dealloc {
	[[NSNotificationCenter defaultCenter] removeObserver:self];
}


#pragma mark - Notification Center Callback Methods

/// Fired when network conditions change.
- (void)networkChanged:(NSNotification*)notify {
	BOOL available = [[notify object] boolValue];
	self.updateAllItem.enabled = available;
	[self updateBarIcon];
}

/// Fired when a single feed has been updated. Object contains relative unread count change.
- (void)unreadCountChanged:(NSNotification*)notify {
	[self setUnreadCountRelative:[[notify object] integerValue]];
}

/**
 If notification has @c object use this object to set unread count directly.
 If @c object is @c nil perform core data fetch on total unread count and update icon.
 */
- (void)unreadCountReset:(NSNotification*)notify {
	if (notify.object) // set unread count directly
		[self setUnreadCountAbsolute:[[notify object] unsignedIntegerValue]];
	else
		[self asyncReloadUnreadCount];
}


#pragma mark - Helper

/// Assign total unread count value directly.
- (void)setUnreadCountAbsolute:(NSUInteger)count {
	_unreadCountTotal = (NSInteger)count;
	[self updateBarIcon];
}

/// Assign new value by adding @c count to total unread count (may be negative).
- (void)setUnreadCountRelative:(NSInteger)count {
	_unreadCountTotal += count;
	[self updateBarIcon];
}

/// Fetch new total unread count from core data and assign it as new value (dispatch async on main thread).
- (void)asyncReloadUnreadCount {
	dispatch_async(dispatch_get_main_queue(), ^{
		[self setUnreadCountAbsolute:[StoreCoordinator countTotalUnread]];
	});
}


#pragma mark - Update Menu Bar Icon

/// Update menu bar icon and text according to unread count and user preferences.
- (void)updateBarIcon {
	dispatch_async(dispatch_get_main_queue(), ^{
		BOOL hasNet = [FeedDownload allowNetworkConnection];
		BOOL tint = (self.unreadCountTotal > 0 && hasNet && [UserPrefs defaultYES:@"globalTintMenuBarIcon"]);
		self.statusItem.image = [NSImage imageNamed:(hasNet ? RSSImageMenuBarIconActive : RSSImageMenuBarIconPaused)];
		self.statusItem.image.template = !tint;
		
		BOOL showCount = (self.unreadCountTotal > 0 && [UserPrefs defaultYES:@"globalUnreadCount"]);
		self.statusItem.title = (showCount ? [NSString stringWithFormat:@"%ld", self.unreadCountTotal] : @"");
	});
}

/// Show popover with a brief notice that baRSS is running in the menu bar
- (void)showWelcomeMessage {
	NSString *title = [NSString stringWithFormat:NSLocalizedString(@"Welcome to %@", nil), [UserPrefs appName]];
	NSString *message = NSLocalizedString(@"There's no application window.\nEverything is up there.", nil);
	NSTextField *head = [[NSView label:title] bold];
	NSTextField *body = [[NSView label:message] small];
	
	const CGFloat pad = 12;
	CGFloat icon = NSHeight(head.frame) + PAD_S + NSHeight(body.frame);
	CGFloat dx = pad + icon + PAD_L; // where text begins
	
	NSPopover *pop = [NSView popover:NSMakeSize(dx + NSMaxWidth(head, body) + pad, icon + 2 * pad)];
	NSView *content = pop.contentViewController.view;
	
	[[NSView imageView:NSImageNameApplicationIcon size:icon] placeIn:content x:pad y:pad];
	[head placeIn:content x:dx yTop:pad];
	[body placeIn:content x:dx y:pad];
	[pop showRelativeToRect:NSZeroRect ofView:self.statusItem.button preferredEdge:NSRectEdgeMaxY];
}


#pragma mark - Main Menu Handling

- (void)mainMenuWillOpen {
	self.barMenu = [[BarMenu alloc] initWithStatusItem:self];
	[self insertMainMenuHeader:self.statusItem.menu];
	[self.barMenu menuNeedsUpdate:self.statusItem.menu];
	// Add main menu items 'Preferences' and 'Quit'.
	[self.statusItem.menu addItem:[NSMenuItem separatorItem]];
	[self.statusItem.menu addItemWithTitle:NSLocalizedString(@"Preferences", nil) action:@selector(openPreferences) keyEquivalent:@","];
	[self.statusItem.menu addItemWithTitle:NSLocalizedString(@"Quit", nil) action:@selector(terminate:) keyEquivalent:@"q"];
}

- (void)mainMenuDidClose {
	[self.statusItem.menu removeAllItems];
	self.barMenu = nil;
}

- (void)insertMainMenuHeader:(NSMenu*)menu {
	// 'Pause Updates' item
	NSMenuItem *pause = [menu addItemWithTitle:NSLocalizedString(@"Pause Updates", nil) action:@selector(pauseUpdates) keyEquivalent:@""];
	pause.target = self;
	if ([FeedDownload isPaused])
		pause.title = NSLocalizedString(@"Resume Updates", nil);
	// 'Update all feeds' item
	if ([UserPrefs defaultYES:@"globalUpdateAll"]) {
		NSMenuItem *updateAll = [menu addItemWithTitle:NSLocalizedString(@"Update all feeds", nil) action:@selector(updateAllFeeds) keyEquivalent:@""];
		updateAll.target = self;
		updateAll.enabled = [FeedDownload allowNetworkConnection];
		self.updateAllItem = updateAll;
	}
	// Separator between main header and default header
	[menu addItem:[NSMenuItem separatorItem]];
}

/// Called when user clicks on 'Pause Updates' (main menu only).
- (void)pauseUpdates {
	[FeedDownload setPaused:![FeedDownload isPaused]];
	[self updateBarIcon];
}

/// Called when user clicks on 'Update all feeds' (main menu only).
- (void)updateAllFeeds {
//	[self asyncReloadUnreadCount]; // should not be necessary
	[FeedDownload forceUpdateAllFeeds];
}

@end
