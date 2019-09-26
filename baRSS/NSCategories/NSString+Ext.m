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

@implementation NSString (PlainHTML)

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


static inline BOOL OPEN(NSString *tag, NSString *match) {
	return ([tag isEqualToString:match] || [tag hasPrefix:[match stringByAppendingString:@" "]]);
}

static inline BOOL CLOSE(NSString *tag, NSString *match) {
	return [tag isEqualToString:match];
}

@end



@implementation NSString (HexColor)

/**
 Color from hex string with format: @c #[0x|0X]([A]RGB|[AA]RRGGBB)

 @return @c nil if string is not properly formatted.
 */
- (nullable NSColor*)hexColor {
	if ([self characterAtIndex:0] != '#') // must start with '#'
		return nil;
	
	NSScanner *scanner = [NSScanner scannerWithString:self];
	scanner.scanLocation = 1;
	unsigned int value;
	if (![scanner scanHexInt:&value])
		return nil;
	
	NSUInteger len = scanner.scanLocation - 1; // -'#'
	if (len > 1 && ([self characterAtIndex:2] == 'x' || [self characterAtIndex:3] == 'X'))
		len -= 2; // ignore '0x'RRGGBB
	
	unsigned int r = 0, g = 0, b = 0, a = 255;
	switch (len) {
		case 4: // #ARGB
			// ignore alpha for now
			// a = (value >> 8) & 0xF0;  a = a | (a >> 4);
		case 3: // #RGB
			r = (value >> 4) & 0xF0;  r = r | (r >> 4);
			g = (value)      & 0xF0;  g = g | (g >> 4);
			b = (value)      & 0x0F;  b = b | (b << 4);
			break;
		case 8: // #AARRGGBB
			// a = (value >> 24) & 0xFF;
		case 6: // #RRGGBB
			r = (value >> 16) & 0xFF;
			g = (value >> 8)  & 0xFF;
			b = (value)       & 0xFF;
			break;
		default:
			return nil;
	}
	return [NSColor colorWithCalibratedRed:r/255.f green:g/255.f blue:b/255.f alpha:a/255.f];
}

@end
