#import "NotifyEndpoint.h"
#import "UserPrefs.h"
#import "StoreCoordinator.h"
#import "Feed+Ext.h"
#import "FeedArticle+Ext.h"

/**
 Sent for global unread count notification alert (Notification Center)
 */
static NSString* const kNotifyIdGlobal = @"global";

static NSString* const kCategoryDismissable = @"DISMISSIBLE";
static NSString* const kActionOpenBackground = @"OPEN_IN_BACKGROUND";
static NSString* const kActionMarkRead = @"MARK_READ_DONT_OPEN";
static NSString* const kActionOpenOnly = @"OPEN_ONLY_DONT_MARK_READ";


@implementation NotifyEndpoint

static NotifyEndpoint *singleton = nil;
static NotificationType notifyType;

/// Ask user for permission to send notifications @b AND register delegate to respond to alert banner clicks.
/// @note Called every time user changes notification settings
+ (void)activate {
	UNUserNotificationCenter *center = UNUserNotificationCenter.currentNotificationCenter;
	notifyType = UserPrefsNotificationType();
	
	// even if disabled, register delegate. This allows to open previously sent notifications
	static dispatch_once_t onceToken;
	dispatch_once(&onceToken, ^{
		singleton = [NotifyEndpoint new];
		center.delegate = singleton;
	});
	
	if (notifyType == NotificationTypeDisabled) {
		return;
	}
	// register action types (allow mark read without opening notification)
	UNNotificationAction *openBackgroundAction = [UNNotificationAction actionWithIdentifier:kActionOpenBackground title:NSLocalizedString(@"Open in background", nil) options:UNNotificationActionOptionNone];
	UNNotificationAction *dontOpenAction = [UNNotificationAction actionWithIdentifier:kActionMarkRead title:NSLocalizedString(@"Mark read & dismiss", nil) options:UNNotificationActionOptionNone];
	UNNotificationAction *dontReadAction = [UNNotificationAction actionWithIdentifier:kActionOpenOnly title:NSLocalizedString(@"Open but keep unread", nil) options:UNNotificationActionOptionNone];
	UNNotificationCategory *category = [UNNotificationCategory categoryWithIdentifier:kCategoryDismissable actions:@[openBackgroundAction, dontOpenAction, dontReadAction] intentIdentifiers:@[] options:UNNotificationCategoryOptionNone];
	[center setNotificationCategories:[NSSet setWithObject:category]];
	
	[center requestAuthorizationWithOptions:UNAuthorizationOptionAlert | UNAuthorizationOptionSound completionHandler:^(BOOL granted, NSError * _Nullable error) {
		if (error) {
			dispatch_async(dispatch_get_main_queue(), ^{
				NSAlert *alert = [[NSAlert alloc] init];
				alert.messageText = NSLocalizedString(@"Notifications Disabled", nil);
				alert.informativeText = NSLocalizedString(@"Either enable notifications in System Settings, or disable notifications in baRSS settings.", nil);
				alert.alertStyle = NSAlertStyleInformational;
				[alert runModal];
			});
		}
	}];
}

/// Set (or update) global "X unread articles"
+ (void)setGlobalCount:(NSInteger)newCount previousCount:(NSInteger)oldCount {
	if (newCount > 0) {
		if (notifyType != NotificationTypeGlobal) {
			return;
		}
		// TODO: how to handle global count updates?
		// ignore and keep old count until 0?
		// or update count and show a new notification banner?
		if (newCount > oldCount) { // only notify if new feeds (quirk: will also trigger for option-click menu to mark unread)
			[self send:kNotifyIdGlobal
				 title:APP_NAME
				  body:[NSString stringWithFormat:NSLocalizedString(@"%ld unread articles", nil), newCount]];
		}
	} else {
		[self dismiss:@[kNotifyIdGlobal]];
	}
}

/// Triggers feed notifications (if enabled)
+ (void)postFeed:(Feed*)feed {
	if (notifyType != NotificationTypePerFeed) {
		return;
	}
	NSUInteger count = feed.countUnread;
	if (count > 0) {
		[feed.managedObjectContext obtainPermanentIDsForObjects:@[feed] error:nil];
		[self send:feed.notificationID
			 title:feed.title
			  body:[NSString stringWithFormat:NSLocalizedString(@"%ld unread articles", nil), count]];
	}
}

/// Triggers article notifications (if enabled)
+ (void)postArticle:(FeedArticle*)article {
	if (notifyType != NotificationTypePerArticle) {
		return;
	}
	[article.managedObjectContext obtainPermanentIDsForObjects:@[article] error:nil];
	[self send:article.notificationID
		 title:article.feed.title
		  body:article.title];
}

/// Close already posted notifications because they were opened via menu
+ (void)dismiss:(nullable NSArray<NSString*>*)list {
	if (list.count > 0) {
		[UNUserNotificationCenter.currentNotificationCenter removeDeliveredNotificationsWithIdentifiers:list];
	}
}


#pragma mark - Helper methods

/// Post notification (immediatelly).
/// @param identifier Used to identify a specific instance (and dismiss a previously shown notification).
+ (void)send:(NSString *)identifier title:(nullable NSString *)title body:(nullable NSString *)body {
	UNMutableNotificationContent *msg = [UNMutableNotificationContent new];
	if (title != nil) msg.title = title;
	if (body != nil) msg.body = body;
	// common settings:
	msg.categoryIdentifier = kCategoryDismissable;
	// TODO: make sound configurable?
	msg.sound = [UNNotificationSound defaultSound];
	[self send:identifier content: msg];
}

/// Internal method for queueing a new notification.
+ (void)send:(NSString *)identifier content:(UNMutableNotificationContent*)msg {
	UNUserNotificationCenter *center = UNUserNotificationCenter.currentNotificationCenter;
	
	[center getNotificationSettingsWithCompletionHandler:^(UNNotificationSettings * _Nonnull settings) {
		if (settings.authorizationStatus != UNAuthorizationStatusAuthorized) {
			return;
		}
		
		UNNotificationRequest *req = [UNNotificationRequest requestWithIdentifier:identifier content:msg trigger:nil];
		[center addNotificationRequest:req withCompletionHandler:^(NSError * _Nullable error) {
			if (error) {
				NSLog(@"Could not send notification: %@", error);
			}
		}];
	}];
}


#pragma mark - Delegate

/// Must be implemented to show notifications while the app is in foreground
- (void)userNotificationCenter:(UNUserNotificationCenter *)center willPresentNotification:(UNNotification *)notification withCompletionHandler:(void (^)(UNNotificationPresentationOptions))completionHandler {
	// all the options
	UNNotificationPresentationOptions common = UNNotificationPresentationOptionSound | UNNotificationPresentationOptionBadge;
	if (@available(macOS 11.0, *)) {
		completionHandler(common | UNNotificationPresentationOptionBanner | UNNotificationPresentationOptionList);
	} else {
		completionHandler(common | UNNotificationPresentationOptionAlert);
	}
}

/// Callback method when user clicks on alert banner
- (void)userNotificationCenter:(UNUserNotificationCenter *)center didReceiveNotificationResponse:(UNNotificationResponse *)response withCompletionHandler:(void (^)(void))completionHandler {
	NSArray<FeedArticle*> *articles;
	
	NSManagedObjectContext *moc = [StoreCoordinator createChildContext];
	NSString *theId = response.notification.request.identifier;
	if ([theId isEqualToString:kNotifyIdGlobal]) {
		// global notification
		articles = [StoreCoordinator articlesAtPath:nil isFeed:NO sorted:YES unread:YES inContext:moc limit:0];
	} else {
		NSURL *uri = [NSURL URLWithString:theId];
		NSManagedObjectID *oid = [moc.persistentStoreCoordinator managedObjectIDForURIRepresentation:uri];
		NSManagedObject *obj = [moc objectWithID:oid];
		if ([obj isKindOfClass:[FeedArticle class]]) {
			// per-article notification
			articles = @[(FeedArticle*)obj];
		} else if ([obj isKindOfClass:[Feed class]]) {
			// per-feed notification
			articles = [[[(Feed*)obj articles]
						 filteredSetUsingPredicate:[NSPredicate predicateWithFormat:@"unread = 1"]]
						sortedArrayUsingDescriptors:@[[NSSortDescriptor sortDescriptorWithKey:@"sortIndex" ascending:NO]]];
		} else {
			return;
		}
	}
	
	// open-in-background performs the same operation as a normal click
	// the "background" part is triggered by _NOT_ having the UNNotificationActionOptionForeground option
	BOOL dontOpen = [response.actionIdentifier isEqualToString:kActionMarkRead];
	BOOL dontMarkRead = [response.actionIdentifier isEqualToString:kActionOpenOnly];
	[StoreCoordinator updateArticles:articles markRead:!dontMarkRead andOpen:!dontOpen inContext:moc];
}

@end
