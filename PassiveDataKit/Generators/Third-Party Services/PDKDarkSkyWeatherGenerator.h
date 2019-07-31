//
//  PDKDarkSkyWeatherGenerator.h
//  PassiveDataKit
//
//  Created by Chris Karr on 6/27/19.
//  Copyright © 2019 Audacious Software. All rights reserved.
//

@import Foundation;

#import "PDKBaseGenerator.h"

extern NSString * _Nonnull const PDKDarkSkyAPIKey;

NS_ASSUME_NONNULL_BEGIN

@interface PDKDarkSkyWeatherGenerator : PDKBaseGenerator

+ (PDKDarkSkyWeatherGenerator *) sharedInstance;

- (void) refresh;

@end

NS_ASSUME_NONNULL_END
