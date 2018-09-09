//
//  PDKNokiaHealthGenerator.h
//  PassiveDataKit
//
//  Created by Chris Karr on 8/23/18.
//  Copyright © 2018 Audacious Software. All rights reserved.
//

@import Foundation;

#import "PDKBaseGenerator.h"

extern NSString * const PDKNokiaHealthClientID;
extern NSString * const PDKNokiaHealthClientSecret;
extern NSString * const PDKNokiaHealthCallbackURL;

extern NSString * const PDKNokiaHealthScopes;
extern NSString * const PDKNokiaHealthLoginMandatory;

extern NSString * const PDKNokiaHealthScopeUserInfo;
extern NSString * const PDKNokiaHealthScopeUserMetrics;
extern NSString * const PDKNokiaHealthScopeUserActivity;

extern NSString * const PDKNokiaHealthActivityMeasuresEnabled;
extern NSString * const PDKNokiaHealthIntradayActivityMeasuresEnabled;
extern NSString * const PDKNokiaHealthSleepMeasuresEnabled;
extern NSString * const PDKNokiaHealthSleepSummaryEnabled;
extern NSString * const PDKNokiaHealthBodyMeasuresEnabled;


@interface PDKNokiaHealthGenerator : PDKBaseGenerator

+ (PDKNokiaHealthGenerator *) sharedInstance;

- (void) addListener:(id<PDKDataListener>)listener options:(NSDictionary *) options;
- (void) refresh;

- (BOOL) isAuthenticated;
- (void) loginToService:(void (^)(void))success failure:(void (^)(void))failure;
- (void) logout;


- (void) stepsBetweenStart:(NSTimeInterval) start end:(NSTimeInterval) end callback:(void (^)(NSTimeInterval start, NSTimeInterval end, CGFloat steps)) callback;

@end
