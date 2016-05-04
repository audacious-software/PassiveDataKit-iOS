//
//  PDKLocationGenerator.h
//  PassiveDataKit
//
//  Created by Chris Karr on 5/4/16.
//  Copyright © 2016 Audacious Software. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <CoreLocation/CoreLocation.h>

#import "PassiveDataKit.h"

@interface PDKLocationGenerator : NSObject<PDKGenerator, CLLocationManagerDelegate>

+ (PDKLocationGenerator *) sharedInstance;

@end
