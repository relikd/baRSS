#import "NotifyEndpoint.h"
#import "UserPrefs.h"
#import "StoreCoordinator.h"
#import "Feed+Ext.h"
#import "FeedArticle+Ext.h"

/**
 Sent for global unread count notification alert (Notification Center)
 */
static NSString* const kNotifyIdGlobal = @"global";


@implementation NotifyEndpoint

static NotifyEndpoint *singleton = nil;
static NotificationType notifyType;

/// Ask user for permission to send notifications @b AND register delegate to respond to alert banner clicks.
/// @note Called every time user changes notification settings
+ (void)activate {
	notifyType = UserPrefsNotificationType();
	
	// even if disabled, register delegate. This allows to open previously sent notifications
	static dispatch_once_t onceToken;
	dispatch_once(&onceToken, ^{
		singleton = [NotifyEndpoint new];
		UNUserNotificationCenter.currentNotificationCenter.delegate = singleton;
	});
	
	if (notifyType == NotificationTypeDisabled) {
		return;
	}
	
	[UNUserNotificationCenter.currentNotificationCenter requestAuthorizationWithOptions:UNAuthorizationOptionAlert | UNAuthorizationOptionSound completionHandler:^(BOOL granted, NSError * _Nullable error) {
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
				 title:nil
				  body:[NSString stringWithFormat:@"%ld unread articles", newCount]];
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
			  body:[NSString stringWithFormat:@"%ld unread articles", count]];
	}
}

/// Triggers article notifications (if enabled)
+ (void)postArticle:(FeedArticle*)article {
	if (notifyType != NotificationTypePerArticle) {
		return;
	}
	[article.managedObjectContext obtainPermanentIDsForObjects:@[article] error:nil];
	[self send:article.notificationID
		 title:article.title
		  body:article.abstract ? article.abstract : article.body];
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
	if (title) msg.title = title;
	if (body) msg.body = body;
	// common settings:
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
	[StoreCoordinator updateArticles:articles markRead:YES andOpen:YES inContext:moc];
}

@end
