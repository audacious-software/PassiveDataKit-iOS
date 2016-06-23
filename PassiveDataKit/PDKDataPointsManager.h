//
//  PDKEventManager.h
//  PassiveDataKit
//
//  Created by Chris Karr on 6/4/16.
//  Copyright © 2016 Audacious Software. All rights reserved.
//

@import Foundation;

@interface PDKDataPointsManager : NSObject

+ (PDKDataPointsManager *) sharedInstance;

- (BOOL) logDataPoint:(NSString *) generator generatorId:(NSString *) generatorId source:(NSString *) source properties:(NSDictionary *) properties;
- (BOOL) logEvent:(NSString *) eventName properties:(NSDictionary *) properties;

- (void) uploadDataPoints:(NSURL *) url window:(NSTimeInterval) uploadWindow complete:(void (^)(BOOL success, int uploaded)) completed;

@end
