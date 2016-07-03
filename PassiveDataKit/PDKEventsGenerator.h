//
//  PDKEventGenerator.h
//  PassiveDataKit
//
//  Created by Chris Karr on 6/25/16.
//  Copyright © 2016 Audacious Software. All rights reserved.
//

@import UIKit;

@interface PDKEventsGenerator : NSObject<UITableViewDataSource, UITableViewDelegate>

extern NSString *const PDKEventsGeneratorEnabled;
extern NSString *const PDKEventsGeneratorCanDisable;

+ (void) logForReview:(NSDictionary *) payload;

@end
