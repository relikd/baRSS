@import Cocoa;

void svgPath(CGContextRef context, CGFloat scale, const char * path);
void svgCircle(CGContextRef context, CGFloat scale, CGFloat x, CGFloat y, CGFloat radius, bool clockwise);
void svgRoundedRect(CGContextRef context, CGFloat scale, CGRect rect, CGFloat cornerRadius);
void svgRect(CGContextRef context, CGFloat scale, CGRect rect);
