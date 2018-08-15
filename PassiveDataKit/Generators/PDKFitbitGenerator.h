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

- (void) addListener:(id<PDKDataListener>)listener options:(NSDictionary *) options;
- (void) refresh;

@end
