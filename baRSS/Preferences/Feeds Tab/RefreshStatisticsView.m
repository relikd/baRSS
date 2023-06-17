#import "RefreshStatisticsView.h"
#import "NSDate+Ext.h"
#import "NSView+Ext.h"

@implementation RefreshStatisticsView

/**
 Generate UI with buttons for min, max, avg and median. Also show number of articles and latest article date.
 
 @param info The dictionary generated with @c -refreshInterval:
 @param count Article count.
 @param callback If set, @c sender will be called with @c -refreshIntervalButtonClicked:.
                 If not disable button border and display as bold inline text.
 @return Centered view without autoresizing.
 */
- (instancetype)initWithRefreshInterval:(NSDictionary*)info articleCount:(NSUInteger)count callback:(nullable id<RefreshIntervalButtonDelegate>)callback {
	self = [super initWithFrame:NSMakeRect(0, 0, 320, 327)];
	self.autoresizesSubviews = NO;
	
	NSTextField *dateView = [self viewForArticlesCount:count latest:info];
	if (!info || info.count == 0) {
		[self setFrameSize:dateView.frame.size];
		[dateView placeIn:self x:0 y:0];
	} else {
		NSArray *arr = @[GrayLabel(NSLocalizedString(@"min:", nil)), [self createInlineButton:info[@"min"] callback:callback],
						 GrayLabel(NSLocalizedString(@"max:", nil)), [self createInlineButton:info[@"max"] callback:callback],
						 GrayLabel(NSLocalizedString(@"avg:", nil)), [self createInlineButton:info[@"avg"] callback:callback],
						 GrayLabel(NSLocalizedString(@"median:", nil)), [self createInlineButton:info[@"median"] callback:callback]];
		NSView *buttonsView = [self placeViewsHorizontally:arr];
		
		CGFloat w = NSMaxWidth(dateView, buttonsView);
		[self setFrameSize:NSMakeSize(w, NSHeight(buttonsView.frame) + PAD_M + NSHeight(dateView.frame))];
		
		[dateView placeIn:self x:CENTER yTop:0];
		[buttonsView placeIn:self x:CENTER y:0];
	}
	return self;
}

/// TextField with article count and latest article date.
- (NSTextField*)viewForArticlesCount:(NSUInteger)count latest:(nullable NSDictionary*)info {
	NSString *text = [NSString stringWithFormat:NSLocalizedString(@"%lu articles.", nil), count];
	if (!info || info.count == 0) {
		return GrayLabel(text);
	}
	NSDate *lastUpdate = [info valueForKey:@"latest"];
	NSString *mod = [NSDateFormatter localizedStringFromDate:lastUpdate dateStyle:NSDateFormatterMediumStyle timeStyle:NSDateFormatterShortStyle];
	NSTextField *label = GrayLabel([text stringByAppendingFormat:NSLocalizedString(@" (latest: %@)", nil), mod]);
	
	// Feed wasn't updated in a while ...
	if ([lastUpdate timeIntervalSinceNow] < (-360 * 24 * 60 * 60)) {
		NSMutableAttributedString *as = label.attributedStringValue.mutableCopy;
		[as addAttribute:NSForegroundColorAttributeName value:[NSColor systemRedColor] range:NSMakeRange(text.length, as.length - text.length)];
		[label setAttributedStringValue:as]; // red colored date
	}
	return label;
}

/// Label with smaller gray text, non-editable. @c 13px height.
static inline NSTextField* GrayLabel(NSString *text) {
	return [[[NSView label:text] tiny] gray];
}

/// Inline button with tag equal to refresh interval. @c 16px height.
- (NSButton*)createInlineButton:(NSNumber*)num callback:(nullable id<RefreshIntervalButtonDelegate>)callback {
	NSButton *button = [NSView inlineButton: [NSDate floatStringForInterval:num.intValue]];
	Interval intv = [NSDate floatToIntInterval:num.intValue]; // rounded to highest unit
	button.accessibilityTitle = [NSDate intStringForInterval:intv];
	button.tag = (NSInteger)intv;
	if (callback) {
		[button action:@selector(refreshIntervalButtonClicked:) target:callback];
	} else {
		button.bordered = NO;
		button.enabled = NO;
	}
	return button;
}

/// Helper method to arrange all views in a horizontal line (vertically centered).
- (NSView*)placeViewsHorizontally:(NSArray<NSView*>*)views {
	CGFloat w = 0;
	NSView *parent = [[NSView alloc] initWithFrame: NSZeroRect];
	for (NSView *v in views) {
		BOOL isButton = [v isKindOfClass:[NSButton class]];
		[v setFrameOrigin:NSMakePoint(w, (isButton ? 0 : 2))];
		[parent addSubview:v];
		w += NSWidth(v.frame) + (isButton ? PAD_M : 0);
	}
	[parent setFrameSize:NSMakeSize(w - PAD_M, 16)];
	return parent;
}

@end
