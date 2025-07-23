#import <Foundation/Foundation.h>
#import <AppKit/AppKit.h>
//#import <WebKit/WebKit.h>

//  ---------------------------------------------------------------
// |
// |  OPML renderer
// |
//  ---------------------------------------------------------------

NSXMLElement* make(NSString *tag, NSString *text, NSXMLElement *parent) {
	NSXMLElement *div = [NSXMLElement elementWithName:tag];
	if (text) div.stringValue = text;
	[parent addChild:div];
	return div;
}

void attribute(NSXMLElement *parent, NSString *key, NSString *value) {
	[parent addAttribute:[NSXMLElement attributeWithName:key stringValue:value]];
}

NSXMLElement* section(NSString *title, NSString *container, NSXMLElement *parent) {
	make(@"h3", title, parent);
	NSXMLElement *div = make(container, nil, parent);
	attribute(div, @"class", @"section");
	return div;
}

void appendNode(NSXMLElement *child, NSXMLElement *parent, Boolean thumb) {
	
	if ([child.name isEqualToString:@"head"]) {
		if (thumb)
			return;
		NSXMLElement *dl = section(@"Metadata:", @"dl", parent);
		for (NSXMLElement *head in child.children) {
			make(@"dt", head.name, dl);
			make(@"dd", head.stringValue, dl);
		}
		return;
	}
	
	if ([child.name isEqualToString:@"body"]) {
		parent = thumb ? make(@"ul", nil, parent) : section(@"Content:", @"ul", parent);
		
	} else if ([child.name isEqualToString:@"outline"]) {
		if ([child attributeForName:@"separator"].stringValue) {
			make(@"hr", nil, parent);
		} else {
			NSString *desc = [child attributeForName:@"title"].stringValue;
			if (!desc || desc.length == 0)
				desc = [child attributeForName:@"text"].stringValue;
			// refreshInterval
			NSXMLElement *li = make(@"li", desc, parent);
			if (!thumb) {
				NSString *xmlUrl = [child attributeForName:@"xmlUrl"].stringValue;
				if (xmlUrl && xmlUrl.length > 0) {
					[li addChild:[NSXMLNode textWithStringValue:@" — "]];
					attribute(make(@"a", xmlUrl, li), @"href", xmlUrl);
				}
			}
		}
		if (child.childCount > 0) {
			parent = make(@"ul", nil, parent);
		}
	}
	for (NSXMLElement *c in child.children) {
		appendNode(c, parent, thumb);
	}
}

NSData* generateHTMLData(NSURL *url, NSBundle *bundle, BOOL thumb) {
	NSError *err;
	NSXMLDocument *doc = [[NSXMLDocument alloc] initWithContentsOfURL:url options:0 error:&err];
	if (err || !doc) {
		printf("ERROR: %s\n", err.description.UTF8String);
		return nil;
	}
	
	NSXMLElement *html = [NSXMLElement elementWithName:@"html"];
	NSXMLElement *head = make(@"head", nil, html);
	make(@"title", @"OPML file", head);
	
	NSString *cssPath = [bundle pathForResource:thumb ? @"style-thumb" : @"style" ofType:@"css"];
	NSString *data = [NSString stringWithContentsOfFile:cssPath encoding:NSUTF8StringEncoding error:nil];
	make(@"style", data, head);
	
	NSXMLElement *body = make(@"body", nil, html);
	
	for (NSXMLElement *child in doc.children) {
		appendNode(child, body, thumb);
	}
	NSXMLDocument *xml = [NSXMLDocument documentWithRootElement:html];
	return [xml XMLDataWithOptions:NSXMLNodePrettyPrint | NSXMLNodeCompactEmptyElement];
}


/*void renderThumbnail(CFURLRef url, CFBundleRef bundle, CGContextRef context, CGSize maxSize) {
	NSData *data = generateHTMLData((__bridge NSURL*)url, bundle, true);
	if (data) {
		CGRect rect = CGRectMake(0, 0, 600, 800);
		float scale = maxSize.height / rect.size.height;
		
		WebView *webView = [[WebView alloc] initWithFrame:rect];
		[webView.mainFrame.frameView scaleUnitSquareToSize:CGSizeMake(scale, scale)];
		[webView.mainFrame.frameView setAllowsScrolling:NO];
		[webView.mainFrame loadData:data MIMEType:@"text/html" textEncodingName:@"utf-8" baseURL:nil];
		
		while ([webView isLoading])
		  CFRunLoopRunInMode(kCFRunLoopDefaultMode, 0, true);
		[webView display];
		
		NSGraphicsContext *gc = [NSGraphicsContext graphicsContextWithGraphicsPort:(void *)context
																		   flipped:webView.isFlipped];
		[webView displayRectIgnoringOpacity:webView.bounds inContext:gc];
	}
}*/
