//
//  PDKMixpanelEventGenerator.h
//  PassiveDataKit
//
//  Created by Chris Karr on 6/25/16.
//  Copyright © 2016 Audacious Software. All rights reserved.
//

#import "PDKEventGenerator.h"

@interface PDKMixpanelEventGenerator : NSObject<UITableViewDataSource, UITableViewDelegate>

+ (void) logForReview:(NSDictionary *) payload;

@end
