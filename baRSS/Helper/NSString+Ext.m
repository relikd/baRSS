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

#import "NSString+Ext.h"

@implementation NSString (Ext)

/// Init string with @c NSUTF8StringEncoding and call @c htmlToPlainText
+ (NSString*)plainTextFromHTMLData:(NSData*)data {
	if (!data) return nil;
	return [[[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding] htmlToPlainText];
}

/**
 Simple HTML parser to extract TEXT elements and semi-structured elements like list items.
 Ignores @c <head> , @c <style> and @c <script> tags.
 */
- (nonnull NSString*)htmlToPlainText {
	NSScanner *scanner = [NSScanner scannerWithString:self];
	scanner.charactersToBeSkipped = NSCharacterSet.newlineCharacterSet; // ! else, some spaces are dropped
	NSCharacterSet *angleBrackets = [NSCharacterSet characterSetWithCharactersInString:@"<>"];
	unichar prev = '>';
	int order = 0; // ul & ol
	NSString *skip = nil; // head, style, script
	
	NSMutableString *result = [NSMutableString stringWithString:@" "];
	while ([scanner isAtEnd] == NO) {
		NSString *tag = nil;
		if ([scanner scanUpToCharactersFromSet:angleBrackets intoString:&tag]) {
			// parse html tag depending on type
			if (prev == '<') {
				if (skip) {
					// skip everything between <head>, <style>, and <script> tags
					if (CLOSE(tag, skip))
						skip = nil;
					continue;
				}
				if (OPEN(tag, @"a")) [result appendString:@" "];
				else if (OPEN(tag, @"head")) skip = @"/head";
				else if (OPEN(tag, @"style")) skip = @"/style";
				else if (OPEN(tag, @"script")) skip = @"/script";
				else if (CLOSE(tag, @"/p") || OPEN(tag, @"label") || OPEN(tag, @"br"))
					[result appendString:@"\n"];
				else if (OPEN(tag, @"h1") || OPEN(tag, @"h2") || OPEN(tag, @"h3") ||
						 OPEN(tag, @"h4") || OPEN(tag, @"h5") || OPEN(tag, @"h6") ||
						 CLOSE(tag, @"/h1") || CLOSE(tag, @"/h2") || CLOSE(tag, @"/h3") ||
						 CLOSE(tag, @"/h4") || CLOSE(tag, @"/h5") || CLOSE(tag, @"/h6"))
					[result appendString:@"\n"];
				else if (OPEN(tag, @"ol"))  order = 1;
				else if (OPEN(tag, @"ul"))  order = 0;
				else if (OPEN(tag, @"li")) {
					// ordered and unordered list items
					unichar last = [result characterAtIndex:result.length - 1];
					if (last != '\n') {
						[result appendString:@"\n"];
					}
					if (order > 0) [result appendFormat:@" %d. ", order++];
					else           [result appendString:@" • "];
				}
			} else {
				// append text inbetween tags
				if (!skip) {
					[result appendString:tag];
				}
			}
		}
		if (![scanner isAtEnd]) {
			unichar next = [self characterAtIndex:scanner.scanLocation];
			if (prev == next) {
				if (!skip)
					[result appendFormat:@"%c", prev];
			}
			prev = next;
			++scanner.scanLocation;
		}
	}
	// collapsing multiple horizontal whitespaces (\h) into one (the first one)
	[[NSRegularExpression regularExpressionWithPattern:@"(\\h)[\\h]+" options:0 error:nil]
	 replaceMatchesInString:result options:0 range:NSMakeRange(0, result.length) withTemplate:@"$1"];
	return [result stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet];
}


#pragma mark - Helper methods


NS_INLINE BOOL OPEN(NSString *tag, NSString *match) {
	return ([tag isEqualToString:match] || [tag hasPrefix:[match stringByAppendingString:@" "]]);
}

NS_INLINE BOOL CLOSE(NSString *tag, NSString *match) {
	return [tag isEqualToString:match];
}

@end
