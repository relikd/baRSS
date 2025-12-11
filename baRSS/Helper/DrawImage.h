@import Cocoa;

/// Draw separator line in @c NSOutlineView
IB_DESIGNABLE
@interface DrawSeparator : NSView
@property (assign) BOOL invert;
+ (instancetype)withSize:(NSSize)size;
@end


void RegisterImageViewNames(void);
