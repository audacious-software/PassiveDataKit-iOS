//
//  PDKGooglePlacesGenerator.h
//  PassiveDataKit
//
//  Created by Chris Karr on 6/30/16.
//  Copyright © 2016 Audacious Software. All rights reserved.
//

#import <Foundation/Foundation.h>

#import "PassiveDataKit.h"

@interface PDKGooglePlacesGenerator : NSObject<PDKGenerator, PDKDataListener>

+ (PDKGooglePlacesGenerator *) sharedInstance;

@end
