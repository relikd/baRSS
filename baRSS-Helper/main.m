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

#import <Cocoa/Cocoa.h>

int main(int argc, const char * argv[]) {
	@autoreleasepool {
		// see: http://martiancraft.com/blog/2015/01/login-items/
		NSArray<NSRunningApplication*> *arr = [NSRunningApplication runningApplicationsWithBundleIdentifier:@"de.relikd.baRSS"];
		if (arr.count == 0) { // if not already running
			NSArray *pathComponents = [[[NSBundle mainBundle] bundlePath] pathComponents];
			pathComponents = [pathComponents subarrayWithRange:NSMakeRange(0, [pathComponents count] - 4)];
			NSString *path = [NSString pathWithComponents:pathComponents];
			[[NSWorkspace sharedWorkspace] launchApplication:path];
		}
		/*
		 Important: If your daemon shuts down too quickly after being launched,
		 launchd may think it has crashed. Daemons that continue this behavior may
		 be suspended and not launched again when future requests arrive. To avoid
		 this behavior, do not shut down for at least 10 seconds after launch.
		 */
		// https://developer.apple.com/library/archive/documentation/MacOSX/Conceptual/BPSystemStartup/Chapters/CreatingLaunchdJobs.html
		sleep(10); // Not sure if this is necessary. However, it doesnt hurt.
		[NSApp terminate:nil];
	}
	return 0;
}
