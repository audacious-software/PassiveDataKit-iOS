//
//  PDKBatteryGenerator.h
//  PassiveDataKit
//
//  Created by Chris Karr on 9/18/17.
//  Copyright © 2017 Audacious Software. All rights reserved.
//

#import <UIKit/UIKit.h>

#import "PDKBaseGenerator.h"


@interface PDKBatteryGenerator : PDKBaseGenerator<UITableViewDelegate, UITableViewDataSource>

+ (PDKBatteryGenerator *) sharedInstance;

- (void) addListener:(id<PDKDataListener>)listener options:(NSDictionary *) options;
- (void) refresh;

@end

