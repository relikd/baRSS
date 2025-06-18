#include "TinySVG.h"


struct SVGState {
	CGFloat scale; // technically not part of parser but easier to pass along
	
	char op;
	float x, y;
	bool prevDot;
	
	float num[6];
	uint8 iNum;
	
	char buf[15];
	uint8 iBuf;
};


# pragma mark - Helper

/// if number buffer contains anything, write it to num array and start new buffer
static void finishNum(struct SVGState *state) {
	if (state->iBuf > 0) {
		state->buf[state->iBuf] = '\0';
		state->num[state->iNum++] = (float)atof(state->buf);
		state->iBuf = 0;
		state->prevDot = false;
	}
}

/// All numbers stored in num array, finalize SVG path operation and add path to @c CGContext
static void finishOp(CGMutablePathRef path, struct SVGState *state) {
	char op = state->op;
	if (op >= 'a' && op <= 'z') {
		// convert relative to absolute coordinates
		for (uint8 t = 0; t < state->iNum; t++) {
			state->num[t] += (t % 2 || op == 'v') ? state->y : state->x;
		}
		// convert to upper-case
		op = op - 'a' + 'A';
	}
	
	if (op == 'Z') {
		CGPathCloseSubpath(path);
		
	} else if (op == 'V' && state->iNum == 1) {
		state->y = state->num[0];
		CGPathAddLineToPoint(path, NULL, state->x * state->scale, state->y * state->scale);
		
	} else if (op == 'H' && state->iNum == 1) {
		state->x = state->num[0];
		CGPathAddLineToPoint(path, NULL, state->x * state->scale, state->y * state->scale);
		
	} else if (op == 'M' && state->iNum == 2) {
		state->x = state->num[0];
		state->y = state->num[1];
		CGPathMoveToPoint(path, NULL, state->x * state->scale, state->y * state->scale);
		// Edge-case: "M 1 2 3 4 5 6" is valid SVG after move 1,2 all remaining points are lines (3,4 and 5,6)
		// For this case we overwrite op here. It will be overwritten again if a new op starts. Else, assume line-op.
		state->op = (state->op == 'm') ? 'l' : 'L';
		
	} else if (op == 'L' && state->iNum == 2) {
		state->x = state->num[0];
		state->y = state->num[1];
		CGPathAddLineToPoint(path, NULL, state->x * state->scale, state->y * state->scale);
		
	} else if (op == 'C' && state->iNum == 6) {
		state->x = state->num[4];
		state->y = state->num[5];
		CGPathAddCurveToPoint(path, NULL, state->num[0] * state->scale, state->num[1] * state->scale, state->num[2] * state->scale, state->num[3] * state->scale, state->x * state->scale, state->y * state->scale);
	} else {
		NSLog(@"Unsupported SVG operation %c %d", state->op, state->iNum);
	}
	state->iNum = 0;
}

/// current number not finished yet. Append another char to internal buffer
inline static void continueNum(char chr, struct SVGState *state) {
	state->buf[state->iBuf++] = chr;
}


# pragma mark - Parser

/// very basic svg path parser.
/// @returns @c CGMutablePathRef which must be released with @c CGPathRelease()
CGMutablePathRef tinySVG_path(CGFloat scale, const char * code) {
	CGMutablePathRef path = CGPathCreateMutable();
	
	struct SVGState state = {
		.scale = scale,
		.op =  '_',
		.x = 0,
		.y = 0,
		.prevDot = false,

		//.num = {0, 0, 0, 0, 0, 0},
		.iNum = 0,
		//.buf = "               ",
		.iBuf = 0,
	};
	
	unsigned long len = strlen(code);
	for (unsigned long i = 0; i < len; i++) {
		char chr = code[i];
		if ((chr >= 'a' && chr <= 'z') || (chr >= 'A' && chr <= 'Z')) {
			if (state.op != '_') {
				finishNum(&state);
				finishOp(path, &state);
			}
			state.op = chr;
		} else if (chr >= '0' && chr <= '9') {
			continueNum(chr, &state);
		} else if (chr == '-' && state.iBuf == 0) {
			continueNum(chr, &state);
		} else if (chr == '.' && !state.prevDot) {
			continueNum(chr, &state);
			state.prevDot = true;
		} else { // any number-separating character
			finishNum(&state);
			
			// Edge-Case: SVG can reuse the previous operation without declaration
			// e.g. you can draw four lines with "L1 2 3 4 5 6 7 8"
			//      or two curves with "c1 2 3 4 5 6 -1 -2 -3 -4 -5 -6"
			// Therefore we need to complete the operation if the number of arguments is reached
			if (state.iNum == 1 && strchr("HhVv", state.op) != NULL) {
				finishOp(path, &state);
			} else if (state.iNum == 2 && strchr("MmLl", state.op) != NULL) {
				finishOp(path, &state);
			} else if (state.iNum == 6 && strchr("Cc", state.op) != NULL) {
				finishOp(path, &state);
			}
			
			if (chr == '-') {
				continueNum(chr, &state);
			} else if (chr == '.') {
				continueNum(chr, &state);
				state.prevDot = true;
			}
		}
	}
	return path;
}


# pragma mark - External API

/// calls @c tinySVG_path and handles @c CGPath creation and release.
void svgAddPath(CGContextRef context, CGFloat scale, const char * path) {
	CGMutablePathRef tmp = tinySVG_path(scale, path);
	CGContextAddPath(context, tmp);
	CGPathRelease(tmp);
}

/// calls @c CGPathAddArc with full circle
void svgAddCircle(CGContextRef context, CGFloat scale, CGFloat x, CGFloat y, CGFloat radius, bool clockwise) {
	CGMutablePathRef tmp = CGPathCreateMutable();
	CGPathAddArc(tmp, NULL, x * scale, y * scale, radius * scale, 0, M_PI * 2, clockwise);
	CGContextAddPath(context, tmp);
	CGPathRelease(tmp);
}

/// Calls @c CGContextAddRect or @c CGPathAddRoundedRect (optional).
/// @param cornerRadius Use @c <=0 for no corners. Use half of @c min(w,h) for a full circle.
void svgAddRect(CGContextRef context, CGFloat scale, CGRect rect, CGFloat cornerRadius) {
	if (cornerRadius > 0) {
		CGMutablePathRef tmp = CGPathCreateMutable();
		CGPathAddRoundedRect(tmp, NULL, rect, cornerRadius * scale, cornerRadius * scale);
		CGContextAddPath(context, tmp);
		CGPathRelease(tmp);
	} else {
		CGContextAddRect(context, rect);
	}
}
