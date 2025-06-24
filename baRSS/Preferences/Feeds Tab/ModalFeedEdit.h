@import Cocoa;
#import "ModalSheet.h"
@class FeedGroup, ModalSheet;

NS_ASSUME_NONNULL_BEGIN

@interface ModalEditDialog : NSViewController
+ (instancetype)modalWith:(FeedGroup*)group;
- (ModalSheet*)getModalSheet;
- (void)applyChangesToCoreDataObject;
@end


@interface ModalFeedEdit : ModalEditDialog <NSTextFieldDelegate>
- (void)didClickWarningButton:(NSButton*)sender;
- (void)openRegexConverter;
@end

@interface ModalGroupEdit : ModalEditDialog
@end

NS_ASSUME_NONNULL_END
