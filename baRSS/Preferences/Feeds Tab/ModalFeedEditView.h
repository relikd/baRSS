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

#import <Cocoa/Cocoa.h>

@class ModalFeedEdit;

@interface ModalFeedEditView : NSView
@property (weak) IBOutlet NSTextField *url;
@property (weak) IBOutlet NSProgressIndicator *spinnerURL;
@property (weak) IBOutlet NSImageView *favicon;

@property (weak) IBOutlet NSTextField *name;
@property (weak) IBOutlet NSProgressIndicator *spinnerName;

@property (weak) IBOutlet NSTextField *refreshNum;
@property (weak) IBOutlet NSPopUpButton *refreshUnit;

@property (weak) IBOutlet NSButton *warningButton;
@property NSPopover *warningPopover;
@property (weak) IBOutlet NSTextField *warningText;
@property (weak) IBOutlet NSButton *warningReload;

- (instancetype)initWithController:(ModalFeedEdit*)controller NS_DESIGNATED_INITIALIZER;
- (instancetype)initWithFrame:(NSRect)frameRect NS_UNAVAILABLE;
- (nullable instancetype)initWithCoder:(NSCoder *)decoder NS_UNAVAILABLE;
@end