//
//  PDKSystemStatusGenerator.h
//  PassiveDataKit
//
//  Created by Chris Karr on 2/14/19.
//  Copyright © 2019 Audacious Software. All rights reserved.
//

#import <Foundation/Foundation.h>

#import "PDKBaseGenerator.h"

@interface PDKSystemStatusGenerator : PDKBaseGenerator

+ (PDKSystemStatusGenerator *) sharedInstance;

- (void) addListener:(id<PDKDataListener>)listener options:(NSDictionary *) options;
- (void) refresh;

@end
