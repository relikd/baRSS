@import Cocoa;

NS_ASSUME_NONNULL_BEGIN

@interface NSColor (Ext)
/** @return @c RGB(251,163,58) @c (#FBA33A) */
+ (instancetype)rssOrange;
/** @return User preferred color; default: @c rssOrange */
+ (instancetype)menuBarIconColor;
/** @return User preferred color; default: @c systemBlueColor */
+ (instancetype)unreadIndicatorColor;
@end

NS_ASSUME_NONNULL_END
