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

extern NSString * const PDKNokiaHealthScopeUserInfo;
extern NSString * const PDKNokiaHealthScopeUserMetrics;
extern NSString * const PDKNokiaHealthScopeUserActivity;

@interface PDKNokiaHealthGenerator : PDKBaseGenerator

+ (PDKNokiaHealthGenerator *) sharedInstance;

- (void) addListener:(id<PDKDataListener>)listener options:(NSDictionary *) options;
- (void) refresh;

- (BOOL) isAuthenticated;
- (void) loginToService;
- (void) logout;

@end
