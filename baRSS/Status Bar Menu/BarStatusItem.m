#import "BarStatusItem.h"
#import "Constants.h"
#import "UpdateScheduler.h"
#import "StoreCoordinator.h"
#import "UserPrefs.h"
#import "BarMenu.h"
#import "AppHook.h"
#import "NSView+Ext.h"
#import "NSColor+Ext.h"

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
	self.unreadCountTotal = 0;
	self.statusItem.button.image = [NSImage imageNamed:RSSImageMenuBarIconActive];
	self.statusItem.button.image.template = YES;
	// Add empty menu (will be populated once opened)
	self.statusItem.menu = [[NSMenu alloc] initWithTitle:@"M"];
	[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(mainMenuWillOpen) name:NSMenuDidBeginTrackingNotification object:self.statusItem.menu];
	[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(mainMenuDidClose) name:NSMenuDidEndTrackingNotification object:self.statusItem.menu];
	// Some icon unread count notification callback methods
	RegisterNotification(kNotificationNetworkStatusChanged, @selector(networkChanged:), self);
	RegisterNotification(kNotificationTotalUnreadCountChanged, @selector(unreadCountChanged:), self);
	RegisterNotification(kNotificationTotalUnreadCountReset, @selector(unreadCountReset:), self);
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
		BOOL hasNet = [UpdateScheduler allowNetworkConnection];
		BOOL tint = (self.unreadCountTotal > 0 && hasNet && UserPrefsBool(Pref_globalTintMenuIcon));
		self.statusItem.button.image = [NSImage imageNamed:(hasNet ? RSSImageMenuBarIconActive : RSSImageMenuBarIconPaused)];
		
		if (@available(macOS 11, *)) {
			self.statusItem.button.image.template = !tint;
		} else if (@available(macOS 10.14, *)) {
//			There is no proper way to display tinted icon WITHOUT tinted text!
//			- using alternate image instead of tint:
//				icon & text stays black on highlight (but only in light mode)
//			- using tint and attributed titles:
//				with controlTextColor the tint is applied regardless
//				with controlColor the color doesnt match (either normal or on highlight)
//				also, setting attributed title kills tint on icon
			self.statusItem.button.image.template = YES;
			self.statusItem.button.contentTintColor = tint ? [NSColor menuBarIconColor] : nil;
		} else {
			self.statusItem.button.image.template = !tint;
		}
		
		BOOL showCount = (self.unreadCountTotal > 0 && UserPrefsBool(Pref_globalUnreadCount));
		self.statusItem.button.title = (showCount ? [NSString stringWithFormat:@"%ld", self.unreadCountTotal] : @"");
		self.statusItem.button.imagePosition = (showCount ? NSImageLeft : NSImageOnly);
	});
}

/// Show popover with a brief notice that baRSS is running in the menu bar
- (void)showWelcomeMessage {
	NSString *title = [NSString stringWithFormat:NSLocalizedString(@"Welcome to %@", nil), APP_NAME];
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
	if ([UpdateScheduler isPaused])
		pause.title = NSLocalizedString(@"Resume Updates", nil);
	// 'Update all feeds' item
	if (UserPrefsBool(Pref_globalUpdateAll)) {
		NSMenuItem *updateAll = [menu addItemWithTitle:NSLocalizedString(@"Update all feeds", nil) action:@selector(updateAllFeeds) keyEquivalent:@""];
		updateAll.target = self;
		updateAll.enabled = [UpdateScheduler allowNetworkConnection];
		self.updateAllItem = updateAll;
	}
	// Separator between main header and default header
	[menu addItem:[NSMenuItem separatorItem]];
}

/// Called when user clicks on 'Pause Updates' (main menu only).
- (void)pauseUpdates {
	[UpdateScheduler setPaused:![UpdateScheduler isPaused]];
	[self updateBarIcon];
}

/// Called when user clicks on 'Update all feeds' (main menu only).
- (void)updateAllFeeds {
//	[self asyncReloadUnreadCount]; // should not be necessary
	[UpdateScheduler forceUpdateAllFeeds];
}

@end
