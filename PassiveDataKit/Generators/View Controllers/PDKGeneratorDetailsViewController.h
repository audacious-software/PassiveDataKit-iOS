//
//  PDKGeneratorDetailsViewController.h
//  PassiveDataKit
//
//  Created by Chris Karr on 8/9/18.
//  Copyright © 2018 Audacious Software. All rights reserved.
//

#import <UIKit/UIKit.h>
#import <WebKit/WebKit.h>

@interface PDKGeneratorDetailsViewController : UIViewController<UITableViewDelegate, UITableViewDataSource, WKNavigationDelegate>

@property UIView * detailsView;
@property UITableView * parametersView;

@end
