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

#import <Foundation/Foundation.h>
#import <Cocoa/Cocoa.h>

@class FeedGroup;

typedef NS_OPTIONS(NSUInteger, OpmlFileExportOptions) {
	OpmlFileExportOptionFlattened = 1 << 1,
	OpmlFileExportOptionFullBackup = 1 << 2,
};

#pragma mark - Protocols

@protocol OpmlFileImportDelegate <NSObject>
@required
- (NSManagedObjectContext*)opmlFileImportContext; // currently called only once
@optional
- (void)opmlFileImportWillBegin:(NSManagedObjectContext*)moc;
- (void)opmlFileImportDidEnd:(NSManagedObjectContext*)moc;
@end


@protocol OpmlFileExportDelegate <NSObject>
@required
- (NSArray<FeedGroup*>*)opmlFileExportListOfFeedGroups:(OpmlFileExportOptions)options;
@end


#pragma mark - Classes

@interface OpmlFileImport : NSObject
@property (weak) id<OpmlFileImportDelegate> delegate;
+ (instancetype)withDelegate:(id<OpmlFileImportDelegate>)delegate;
- (void)showImportDialog:(NSWindow*)window;
- (void)importFiles:(NSArray<NSURL*>*)files;
@end


@interface OpmlFileExport : NSObject
@property (weak) id<OpmlFileExportDelegate> delegate;
+ (instancetype)withDelegate:(id<OpmlFileExportDelegate>)delegate;
- (void)showExportDialog:(NSWindow*)window;
- (nullable NSError*)writeOPMLFile:(NSURL*)url withOptions:(OpmlFileExportOptions)opt;
@end
