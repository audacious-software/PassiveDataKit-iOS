//
//  PDKFitbitGenerator.h
//  PassiveDataKit
//
//  Created by Chris Karr on 8/14/18.
//  Copyright © 2018 Audacious Software. All rights reserved.
//

@import Foundation;

#import "PDKBaseGenerator.h"

extern NSString * const PDKFitbitClientID;
extern NSString * const PDKFitbitClientSecret;
extern NSString * const PDKFitbitCallbackURL;
extern NSString * const PDKFitbitLoginMandatory;


extern NSString * const PDKFitbitScopes;

extern NSString * const PDKFitbitScopeActivity;
extern NSString * const PDKFitbitScopeHeartRate;
// extern NSString * const PDKFitbitScopeLocation;
// extern NSString * const PDKFitbitScopeNutrition;
// extern NSString * const PDKFitbitScopeProfile;
// extern NSString * const PDKFitbitScopeSettings;
extern NSString * const PDKFitbitScopeSleep;
// extern NSString * const PDKFitbitScopeSocial;
extern NSString * const PDKFitbitScopeWeight;

@interface PDKFitbitGenerator : PDKBaseGenerator

+ (PDKFitbitGenerator *) sharedInstance;
+ (UIColor *) dataColor;

- (void) refresh;

- (BOOL) isAuthenticated;
- (void) loginToService;
- (void) logout;

- (void) stepsBetweenStart:(NSTimeInterval) start end:(NSTimeInterval) end callback:(void (^)(NSTimeInterval start, NSTimeInterval end, CGFloat steps)) callback;

- (void) resetData;

@end
