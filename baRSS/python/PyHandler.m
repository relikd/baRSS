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

#import "PyHandler.h"
#import <Python/Python.h>

static PyObject *parseFeedModule;

@implementation PyHandler

+ (PyObject*)appBundlePath {
	CFBundleRef mainBundle = CFBundleGetMainBundle();
	CFURLRef appPath = CFBundleCopyResourcesDirectoryURL(mainBundle);
	CFURLRef absolutePath = CFURLCopyAbsoluteURL(appPath);
	CFStringRef path = CFURLCopyFileSystemPath(absolutePath, kCFURLPOSIXPathStyle);
	PyObject * pyStr = PyString_FromString(CFStringGetCStringPtr(path, CFStringGetSystemEncoding()));
	// const char *resourcePath = [[[NSBundle mainBundle] resourcePath] UTF8String];
	CFRelease(path);
	CFRelease(absolutePath);
	CFRelease(appPath);
	return pyStr;
}

+ (void)prepare {
	Py_Initialize();
	PyObject *sys = PyImport_Import(PyString_FromString("sys"));
	PyObject *sys_path_append = PyObject_GetAttrString(PyObject_GetAttrString(sys, "path"), "append");
	PyObject *resourcePath = PyTuple_New(1);
	PyTuple_SetItem(resourcePath, 0, [self appBundlePath]);
	PyObject_CallObject(sys_path_append, resourcePath);
	
	// import MyModule   # this is in my project folder
	PyObject *myModule = PyImport_Import(PyString_FromString("getFeed"));
	parseFeedModule = PyObject_GetAttrString(myModule, "parse");
}

+ (void)shutdown {
	PyObject_Free(parseFeedModule);
	Py_Finalize();
}

+ (char*)run:(PyObject*)args {
	if (parseFeedModule && PyCallable_Check(parseFeedModule)) {
		PyObject *result = PyObject_CallObject(parseFeedModule, args);
		if (result != NULL && PyObject_TypeCheck(result, &PyString_Type))
			return PyString_AsString(result);
	}
	return NULL;
}

+ (char *)run:(const char *)url withEtag:(const char *)etag andDateString:(const char *)date {
	if (!Py_IsInitialized())
		return NULL;
	return [self run:Py_BuildValue("(z z z)", url, etag, date)];
}

+ (char *)run:(const char *)url withEtag:(const char *)etag andDateArray:(int *)d {
	if (!Py_IsInitialized())
		return NULL;
	if (d == NULL || abs(d[8]) > 1) { // d[8] == tm_isdst (between -1 and 1). Array size must be 9
		return [self run:Py_BuildValue("(z z z)", url, etag, NULL)];
	}
	return [self run:Py_BuildValue("(z z [iiiiiiiii])", url, etag,
									   d[0], d[1], d[2], d[3], d[4], d[5], d[6], d[7], d[8])];
}

+ (NSDictionary *)getFeed:(NSString *)url withEtag:(NSString *)etag andModified:(NSString *)modified {
	const char* u = NULL;
	const char* e = NULL;
	const char* m = NULL;
	if (url && url.length > 0)
		u = [url UTF8String];
	if (etag && etag.length > 0)
		e = [etag UTF8String];
	if (modified && modified.length > 0)
		m = [modified UTF8String];
	
	char *data = [self run:u withEtag:e andDateString:m];
	printf("JSON result:\n%s\n\n", data);
	if (data == NULL) return nil;
	
	NSError *error = nil;
	id object = [NSJSONSerialization JSONObjectWithData:
				 [[NSString stringWithUTF8String:data] dataUsingEncoding:NSUTF8StringEncoding]
												options:0 error:&error];
	
	if (error || !object || ![object isKindOfClass:[NSDictionary class]]) {
		return nil;
	}
	return object;
}

// @see: https://docs.python.org/3/c-api/index.html
/* PyObject *ObjcToPyObject(id object)
{
	if (object == nil) {
		// This technically doesn't need to be an extra case,
		// but you may want to differentiate it for error checking
		return NULL;
	} else if ([object isKindOfClass:[NSString class]]) {
		return PyString_FromString([object UTF8String]);
	} else if ([object isKindOfClass:[NSNumber class]]) {
		// You could probably do some extra checking here if you need to
		// with the -objCType method.
		return PyLong_FromLong([object longValue]);
	} else if ([object isKindOfClass:[NSArray class]]) {
		// You may want to differentiate between NSArray (analagous to tuples)
		// and NSMutableArray (analagous to lists) here.
		Py_ssize_t i, len = [object count];
		PyObject *list = PyList_New(len);
		for (i = 0; i < len; ++i) {
			PyObject *item = ObjcToPyObject([object objectAtIndex:i]);
			NSCAssert(item != NULL, @"Can't add NULL item to Python List");
			// Note that PyList_SetItem() "steals" the reference to the passed item.
			// (i.e., you do not need to release it)
			PyList_SetItem(list, i, item);
		}
		return list;
	} else if ([object isKindOfClass:[NSDictionary class]]) {
		PyObject *dict = PyDict_New();
		for (id key in object) {
			PyObject *pyKey = ObjcToPyObject(key);
			NSCAssert(pyKey != NULL, @"Can't add NULL key to Python Dictionary");
			PyObject *pyItem = ObjcToPyObject([object objectForKey:key]);
			NSCAssert(pyItem != NULL, @"Can't add NULL item to Python Dictionary");
			PyDict_SetItem(dict, pyKey, pyItem);
			Py_DECREF(pyKey);
			Py_DECREF(pyItem);
		}
		return dict;
	} else {
		NSLog(@"ObjcToPyObject() could not convert Obj-C object to PyObject.");
		return NULL;
	}
}*/

@end
