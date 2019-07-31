//
//  PDKAccelerometerGenerator.h
//  PassiveDataKit
//
//  Created by Chris Karr on 7/30/19.
//  Copyright © 2019 Audacious Software. All rights reserved.
//

@import Foundation;

#import "PDKBaseGenerator.h"

extern NSString * _Nonnull const PDKAccelerometerSampleRate;

NS_ASSUME_NONNULL_BEGIN

@interface PDKAccelerometerGenerator : PDKBaseGenerator

+ (PDKAccelerometerGenerator *) sharedInstance;

- (void) refresh;

- (void) startUpdates;
- (void) stopUpdates;

@end

NS_ASSUME_NONNULL_END
