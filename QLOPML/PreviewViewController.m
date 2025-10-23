#import "PreviewViewController.h"
#import <Quartz/Quartz.h>
#import <WebKit/WebKit.h>
#include "opml-lib.h"

@interface PreviewViewController () <QLPreviewingController>
@end

@implementation PreviewViewController

- (NSString *)nibName {
	return @"PreviewViewController";
}

- (void)preparePreviewOfFileAtURL:(NSURL *)url completionHandler:(void (^)(NSError * _Nullable))handler {
	NSData *data = generateHTMLData(url, [NSBundle mainBundle], NO);
	// sure, we could use `WKWebView`, but that requires the `com.apple.security.network.client` entitlement
#pragma clang diagnostic ignored "-Wdeprecated"
	WebView *web = [[WebView alloc] initWithFrame:self.view.bounds];
#pragma clang diagnostic pop
	web.autoresizingMask = NSViewWidthSizable | NSViewHeightSizable;
	[self.view addSubview:web];
//	[web.mainFrame loadHTMLString:html baseURL:nil];
	[web.mainFrame loadData:data MIMEType:@"text/html" textEncodingName:@"UTF-8" baseURL:nil];
	handler(nil);
}

@end

