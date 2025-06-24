@import Cocoa;
@class RegexConverter, RegexConverterController;

NS_ASSUME_NONNULL_BEGIN

@interface RegexConverterView : NSView
@property (strong) IBOutlet NSTextField *entry;
@property (strong) IBOutlet NSTextField *href;
@property (strong) IBOutlet NSTextField *title;
@property (strong) IBOutlet NSTextField *date;
@property (strong) IBOutlet NSTextField *dateFormat;
@property (strong) IBOutlet NSTextField *desc;
@property (strong) IBOutlet NSTextView *output;

- (instancetype)initWithController:(RegexConverterController*)controller NS_DESIGNATED_INITIALIZER;
- (instancetype)initWithFrame:(NSRect)frameRect NS_UNAVAILABLE;
- (nullable instancetype)initWithCoder:(NSCoder *)decoder NS_UNAVAILABLE;
@end

NS_ASSUME_NONNULL_END
