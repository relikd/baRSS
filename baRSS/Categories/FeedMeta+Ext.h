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

#import "FeedMeta+CoreDataClass.h"

/// Easy memorable @c int16_t enum for refresh unit index
typedef NS_ENUM(int16_t, RefreshUnitType) {
	RefreshUnitSeconds = 0, RefreshUnitMinutes = 1, RefreshUnitHours = 2, RefreshUnitDays = 3, RefreshUnitWeeks = 4
};


@interface FeedMeta (Ext)
@property (readonly) BOOL refreshIntervalDisabled; // self.refreshNum <= 0
@property (readonly) int32_t refreshInterval; // self.refreshNum * RefreshUnitValue

// HTTP response
- (void)setErrorAndPostponeSchedule;
- (void)setSucessfulWithResponse:(NSHTTPURLResponse*)response;
// Setter
- (void)setUrlIfChanged:(NSString*)url;
- (void)setEtag:(NSString*)etag modified:(NSString*)modified;
- (BOOL)setRefresh:(int32_t)refresh unit:(RefreshUnitType)unit;
- (BOOL)setRefreshAndUnitFromInterval:(int32_t)interval;
@end
