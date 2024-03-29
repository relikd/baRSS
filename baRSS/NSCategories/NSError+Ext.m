@import RSXML2.RSXMLError;
#import "NSError+Ext.h"

@implementation NSError (Ext)

static const char* CodeDescription(NSInteger code) {
	switch (code) {
		/* --- Informational --- */
		case 100: return "Continue";
		case 101: return "Switching Protocols";
		case 102: return "Processing";
		case 103: return "Early Hints";
		/* --- Success --- */
		case 200: return "OK";
		case 201: return "Created";
		case 202: return "Accepted";
		case 203: return "Non-Authoritative Information";
		case 204: return "No Content";
		case 205: return "Reset Content";
		case 206: return "Partial Content";
		case 207: return "Multi-Status";
		case 208: return "Already Reported";
		case 226: return "IM Used";
		/* --- Redirection --- */
		case 300: return "Multiple Choices";
		case 301: return "Moved Permanently";
		case 302: return "Found";
		case 303: return "See Other";
		case 304: return "Not Modified";
		case 305: return "Use Proxy";
		case 306: return "Switch Proxy";
		case 307: return "Temporary Redirect";
		case 308: return "Permanent Redirect";
		/* --- Client error --- */
		case 400: return "Bad Request";
		case 401: return "Unauthorized";
		case 402: return "Payment Required";
		case 403: return "Forbidden";
		case 404: return "Not Found";
		case 405: return "Method Not Allowed";
		case 406: return "Not Acceptable";
		case 407: return "Proxy Authentication Required";
		case 408: return "Request Timeout";
		case 409: return "Conflict";
		case 410: return "Gone";
		case 411: return "Length Required";
		case 412: return "Precondition Failed";
		case 413: return "Payload Too Large";
		case 414: return "URI Too Long";
		case 415: return "Unsupported Media Type";
		case 416: return "Range Not Satisfiable";
		case 417: return "Expectation Failed";
		case 418: return "I'm a teapot";
		case 421: return "Misdirected Request";
		case 422: return "Unprocessable Entity";
		case 423: return "Locked";
		case 424: return "Failed Dependency";
		case 425: return "Too Early";
		case 426: return "Upgrade Required";
		case 428: return "Precondition Required";
		case 429: return "Too Many Requests";
		case 431: return "Request Header Fields Too Large";
		case 451: return "Unavailable For Legal Reasons";
		/* --- Server error --- */
		case 500: return "Internal Server Error";
		case 501: return "Not Implemented";
		case 502: return "Bad Gateway";
		case 503: return "Service Unavailable";
		case 504: return "Gateway Timeout";
		case 505: return "HTTP Version Not Supported";
		case 506: return "Variant Also Negotiates";
		case 507: return "Insufficient Storage";
		case 508: return "Loop Detected";
		case 510: return "Not Extended";
		case 511: return "Network Authentication Required";
	}
	return "Unknown";
}

//  ---------------------------------------------------------------
// |  MARK: - Generators
//  ---------------------------------------------------------------

/// Generate @c NSError from HTTP status code. E.g., @c code @c = @c 404 will return "404 Not Found".
+ (instancetype)statusCode:(NSInteger)code reason:(nullable NSString*)reason {
	NSMutableDictionary *info = [NSMutableDictionary dictionaryWithCapacity:2];
	info[NSLocalizedDescriptionKey] = [NSString stringWithFormat:@"%ld %s.", code, CodeDescription(code)];
	if (reason) info[NSLocalizedRecoverySuggestionErrorKey] = reason;
	
	NSInteger errCode = NSURLErrorUnknown;
	if (code < 500) { if (code >= 400) errCode = NSURLErrorResourceUnavailable; }
	else if (code < 600) errCode = NSURLErrorBadServerResponse;
	return [self errorWithDomain:NSURLErrorDomain code:errCode userInfo:info];
}

/// Generate @c NSError for webpages that don't contain feed urls.
+ (instancetype)feedURLNotFound:(NSURL*)url {
	return RSXMLMakeErrorWrongParser(RSXMLErrorExpectingFeed, RSXMLErrorExpectingHTML, url);
}

/// Generate @c NSError for user canceled operation. With title "Operation was canceled."
+ (instancetype)canceledByUser {
	return [NSError errorWithDomain:NSCocoaErrorDomain code:NSUserCancelledError userInfo:nil];
}

/*// Generate @c NSError for invalid or malformed input. With title "The value is invalid."
+ (instancetype)formattingError:(NSString*)description {
	NSDictionary *info = nil;
	if (description) info = @{ NSLocalizedRecoverySuggestionErrorKey: description };
	return [NSError errorWithDomain:NSCocoaErrorDomain code:NSFormattingError userInfo:info];
}*/

//  ---------------------------------------------------------------
// |  MARK: - User notification
//  ---------------------------------------------------------------

/// Will only execute and return @c YES if @c error @c != @c nil . Log error message to console.
- (BOOL)inCaseLog:(nullable const char*)title {
	if (title) printf("ERROR %s: %s, %s\n", title, self.description.UTF8String, self.userInfo.description.UTF8String);
	else       printf("%s, %s\n", self.description.UTF8String, self.userInfo.description.UTF8String);
	return YES;
}

/// Will only execute and return @c YES if @c error @c != @c nil . Present application modal error message.
- (BOOL)inCasePresent:(NSApplication*)app {
	[app presentError:self];
	return YES;
}

@end
