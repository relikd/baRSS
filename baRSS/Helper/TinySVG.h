@import Cocoa;

CGMutablePathRef tinySVG_path(CGFloat scale, const char * code);
void svgAddPath(CGContextRef context, CGFloat scale, const char * path);
void svgAddCircle(CGContextRef context, CGFloat scale, CGFloat x, CGFloat y, CGFloat radius, bool clockwise);
void svgAddRect(CGContextRef context, CGFloat scale, CGRect rect, CGFloat cornerRadius);
