//
//  PDKEventGenerator.h
//  PassiveDataKit
//
//  Created by Chris Karr on 6/25/16.
//  Copyright © 2016 Audacious Software. All rights reserved.
//

@import UIKit;

@interface PDKEventGenerator : NSObject<UITableViewDataSource, UITableViewDelegate>

+ (void) logForReview:(NSDictionary *) payload;

@end
