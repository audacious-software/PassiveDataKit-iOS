//
//  PDKWithingsGenerator.h
//  PassiveDataKit
//
//  Created by Chris Karr on 8/23/18.
//  Copyright © 2018 Audacious Software. All rights reserved.
//

@import Foundation;

#import "PDKBaseGenerator.h"

extern NSString * const PDKWithingsClientID;
extern NSString * const PDKWithingsClientSecret;
extern NSString * const PDKWithingsCallbackURL;

extern NSString * const PDKWithingsScopes;
extern NSString * const PDKWithingsLoginMandatory;

extern NSString * const PDKWithingsScopeUserInfo;
extern NSString * const PDKWithingsScopeUserMetrics;
extern NSString * const PDKWithingsScopeUserActivity;

extern NSString * const PDKWithingsActivityMeasuresEnabled;
extern NSString * const PDKWithingsIntradayActivityMeasuresEnabled;
extern NSString * const PDKWithingsSleepMeasuresEnabled;
extern NSString * const PDKWithingsSleepSummaryEnabled;
extern NSString * const PDKWithingsBodyMeasuresEnabled;


@interface PDKWithingsGenerator : PDKBaseGenerator<PDKStepCountGenerator>

+ (PDKWithingsGenerator *) sharedInstance;

- (void) addListener:(id<PDKDataListener>)listener options:(NSDictionary *) options;
- (void) refresh;

- (BOOL) isAuthenticated;
- (void) loginToService:(void (^)(void))success failure:(void (^)(void))failure;
- (void) logout;

+ (UIColor *) dataColor;

@end
