//
//  PDKHttpTransmitter.h
//  PassiveDataKit
//
//  Created by Chris Karr on 6/18/17.
//  Copyright © 2017 Audacious Software. All rights reserved.
//

#import "PassiveDataKit.h"

#define PDK_SOURCE_KEY @"source"
#define PDK_TRANSMITTER_ID_KEY @"transmitter-id"
#define PDK_TRANSMITTER_UPLOAD_URL_KEY @"upload-url"
#define PDK_TRANSMITTER_REQUIRE_CHARGING_KEY @"require-charging"
#define PDK_TRANSMITTER_REQUIRE_WIFI_KEY @"require-wifi"

@interface PDKHttpTransmitter : NSObject<PDKTransmitter, PDKDataListener>

@end
