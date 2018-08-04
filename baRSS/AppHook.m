//
//  The MIT License (MIT)
//  Copyright (c) 2018 Oleg Geier
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

#import "AppHook.h"

static NSEventModifierFlags fnKeyFlags = NSEventModifierFlagShift | NSEventModifierFlagControl | NSEventModifierFlagOption | NSEventModifierFlagCommand | NSEventModifierFlagFunction;

@implementation AppHook
- (void) sendEvent:(NSEvent *)event {
	if ([event type] == NSEventTypeKeyDown) {
		NSEventModifierFlags flags = (event.modifierFlags & fnKeyFlags); // ignore caps lock, etc.
		unichar key = [event.characters characterAtIndex:0]; // charactersIgnoringModifiers
		if (flags == NSEventModifierFlagCommand) {
			switch (key) {
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wundeclared-selector"
				case 'z': if ([self sendAction:@selector(undo:) to:nil from:self]) return; break;
#pragma clang diagnostic pop
				case 'x': if ([self sendAction:@selector(cut:) to:nil from:self]) return; break;
				case 'c': if ([self sendAction:@selector(copy:) to:nil from:self]) return; break;
				case 'v': if ([self sendAction:@selector(paste:) to:nil from:self]) return; break;
				case 'a': if ([self sendAction:@selector(selectAll:) to:nil from:self]) return; break;
				case 'q': if ([self sendAction:@selector(terminate:) to:nil from:self]) return; break;
				case 'w': if ([self sendAction:@selector(performClose:) to:nil from:self]) return; break;
			}
		} else if (flags == (NSEventModifierFlagCommand | NSEventModifierFlagShift)) {
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wundeclared-selector"
			if (key == 'z') {
				if ([self sendAction:@selector(redo:) to:nil from:self])
					return;
			}
		} else {
			if (key == 13 || key == 3) { // Enter / Return key
				if ([self sendAction:@selector(enterPressed:) to:nil from:self])
					return;
			}
		}
#pragma clang diagnostic pop
	}
	[super sendEvent:event];
}
@end
