#ifndef UserPrefs_h
#define UserPrefs_h

@import Cocoa;

//  ---------------------------------------------------------------
// |  MARK: Constants
//  ---------------------------------------------------------------

// ------ Preferences window ------
/** default: @c  1  */ static NSString* const Pref_prefSelectedTab = @"prefSelectedTab";
/** default: @c nil */ static NSString* const Pref_prefWindowFrame = @"prefWindowFrame";
/** default: @c nil */ static NSString* const Pref_modalSheetWidth = @"modalSheetWidth";
// ------ General settings ------ (Preferences > General Tab) ------
/** default: @c nil */ static NSString* const Pref_defaultHttpApplication = @"defaultHttpApplication";
// ------ Appearance matrix ------ (Preferences > Appearance Tab) ------
/** default: @c YES */ static NSString* const Pref_globalTintMenuIcon   = @"globalTintMenuBarIcon";
/** default: @c YES */ static NSString* const Pref_globalUpdateAll      = @"globalUpdateAll";
/** default: @c YES */ static NSString* const Pref_globalOpenUnread     = @"globalOpenUnread";
/** default: @c YES */ static NSString* const Pref_globalMarkRead       = @"globalMarkRead";
/** default: @c YES */ static NSString* const Pref_globalMarkUnread     = @"globalMarkUnread";
/** default: @c  NO */ static NSString* const Pref_globalUnreadOnly     = @"globalUnreadOnly";
/** default: @c YES */ static NSString* const Pref_globalUnreadCount    = @"globalUnreadCount";
/** default: @c YES */ static NSString* const Pref_groupOpenUnread      = @"groupOpenUnread";
/** default: @c YES */ static NSString* const Pref_groupMarkRead        = @"groupMarkRead";
/** default: @c YES */ static NSString* const Pref_groupMarkUnread      = @"groupMarkUnread";
/** default: @c  NO */ static NSString* const Pref_groupUnreadOnly      = @"groupUnreadOnly";
/** default: @c YES */ static NSString* const Pref_groupUnreadCount     = @"groupUnreadCount";
/** default: @c  NO */ static NSString* const Pref_groupUnreadIndicator = @"groupUnreadIndicator";
/** default: @c YES */ static NSString* const Pref_feedOpenUnread       = @"feedOpenUnread";
/** default: @c YES */ static NSString* const Pref_feedMarkRead         = @"feedMarkRead";
/** default: @c YES */ static NSString* const Pref_feedMarkUnread       = @"feedMarkUnread";
/** default: @c  NO */ static NSString* const Pref_feedUnreadOnly       = @"feedUnreadOnly";
/** default: @c YES */ static NSString* const Pref_feedUnreadCount      = @"feedUnreadCount";
/** default: @c YES */ static NSString* const Pref_feedUnreadIndicator  = @"feedUnreadIndicator";
/** default: @c  NO */ static NSString* const Pref_feedTruncateTitle    = @"feedTruncateTitle";
/** default: @c  NO */ static NSString* const Pref_feedLimitArticles    = @"feedLimitArticles";
// ------ Hidden preferences ------ only modifiable via `defaults write de.relikd.baRSS {KEY}` ------
/** default: @c  10 */ static NSString* const Pref_openFewLinksLimit      = @"openFewLinksLimit";
/** default: @c  60 */ static NSString* const Pref_shortArticleNamesLimit = @"shortArticleNamesLimit";
/** default: @c  40 */ static NSString* const Pref_articlesInMenuLimit    = @"articlesInMenuLimit";
/** default: @c nil */ static NSString* const Pref_colorStatusIconTint    = @"colorStatusIconTint";
/** default: @c nil */ static NSString* const Pref_colorUnreadIndicator   = @"colorUnreadIndicator";


//  ---------------------------------------------------------------
// |  MARK: - NSUserDefaults
//  ---------------------------------------------------------------

void UserPrefsInit(void);
NSColor* UserPrefsColor(NSString *key, NSColor *defaultColor); // Change with:  defaults write de.relikd.baRSS {KEY} -string "#FBA33A"
// ------ Getter ------
/// Helper method calls @c (standardUserDefaults)boolForKey:
static inline BOOL UserPrefsBool(NSString* const key) { return [[NSUserDefaults standardUserDefaults] boolForKey:key]; }
/// Helper method calls @c (standardUserDefaults)integerForKey:
static inline NSInteger UserPrefsInt(NSString* const key) { return [[NSUserDefaults standardUserDefaults] integerForKey:key]; }
/// Helper method calls @c (standardUserDefaults)integerForKey: @return @c (NSUInteger)result
static inline NSUInteger UserPrefsUInt(NSString* const key) { return (NSUInteger)[[NSUserDefaults standardUserDefaults] integerForKey:key]; }
/// Helper method calls @c (standardUserDefaults)stringForKey:
static inline NSString* UserPrefsString(NSString* const key) { return [[NSUserDefaults standardUserDefaults] stringForKey:key]; }
// ------ Setter ------
/// Helper method calls @c (standardUserDefaults)setObject:forKey:
static inline void UserPrefsSet(NSString* const key, id value) { [[NSUserDefaults standardUserDefaults] setObject:value forKey:key]; }
/// Helper method calls @c (standardUserDefaults)setInteger:forKey:
static inline void UserPrefsSetInt(NSString* const key, NSInteger value) { [[NSUserDefaults standardUserDefaults] setInteger:value forKey:key]; }
/// Helper method calls @c (standardUserDefaults)setBool:forKey:
static inline void UserPrefsSetBool(NSString* const key, BOOL value) { [[NSUserDefaults standardUserDefaults] setBool:value forKey:key]; }

//  ---------------------------------------------------------------
// |  MARK: - NSBundle
//  ---------------------------------------------------------------

/// Helper method calls @c (mainBundle)CFBundleShortVersionString
static inline NSString* UserPrefsAppVersion(void) { return [[NSBundle mainBundle] infoDictionary][@"CFBundleShortVersionString"]; }

//  ---------------------------------------------------------------
// |  MARK: - Open URLs
//  ---------------------------------------------------------------

/**
 Open web links in default browser or a browser the user selected in the preferences.
 
 @param urls A list of @c NSURL objects that will be opened immediatelly in bulk.
 @return @c YES if @c urls are opened successfully. @c NO on error.
 */
static inline BOOL UserPrefsOpenURLs(NSArray<NSURL*> *urls) {
	return [[NSWorkspace sharedWorkspace] openURLs:urls withAppBundleIdentifier:UserPrefsString(Pref_defaultHttpApplication) options:NSWorkspaceLaunchDefault additionalEventParamDescriptor:nil launchIdentifiers:nil];
}
/// Call @c UserPrefsOpenURLs() with single item array and convert string to @c NSURL
static inline BOOL UserPrefsOpenURL(NSString *url) { return UserPrefsOpenURLs(@[[NSURL URLWithString:url]]); }

#endif /* UserPrefs_h */
