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

@import Cocoa;

@class Feed;

@interface UpdateScheduler : NSObject
@property (class, readonly) NSUInteger feedsInQueue;
@property (class, readonly) NSDate *dateScheduled;
@property (class, readonly) BOOL allowNetworkConnection;
@property (class, readonly) BOOL isUpdating;
@property (class, setter=setPaused:) BOOL isPaused;

// Getter
+ (NSString*)remainingTimeTillNextUpdate:(nullable double*)remaining;
+ (NSString*)updatingXFeeds;
// Scheduling
+ (void)scheduleNextFeed;
+ (void)forceUpdateAllFeeds;
+ (void)downloadList:(NSArray<Feed*>*)list userInitiated:(BOOL)flag finally:(nullable os_block_t)block;
+ (void)updateAllFavicons;
// Auto Download & Parse Feed URL
+ (void)autoDownloadAndParseURL:(NSString*)url;
+ (void)autoDownloadAndParseUpdateURL;
// Register for network change notifications
+ (void)registerNetworkChangeNotification;
+ (void)unregisterNetworkChangeNotification;
@end
