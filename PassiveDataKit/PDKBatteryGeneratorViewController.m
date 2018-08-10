//
//  PDKBatteryGeneratorViewController.m
//  PassiveDataKit
//
//  Created by Chris Karr on 8/9/18.
//  Copyright © 2018 Audacious Software. All rights reserved.
//

#import "PDKBatteryGeneratorViewController.h"

@interface PDKBatteryGeneratorViewController ()

@end

@implementation PDKBatteryGeneratorViewController

- (void) viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    
    self.navigationItem.title = NSLocalizedStringFromTableInBundle(@"name_generator_battery", @"PassiveDataKit", [NSBundle bundleForClass:self.class], nil);
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    return 1;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    UITableViewCell * cell = [tableView dequeueReusableCellWithIdentifier:@"PDKBatteryDetailsDataSourceCell"];
    
    if (cell == nil) {
        cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleSubtitle reuseIdentifier:@"PDKBatteryDetailsDataSourceCell"];
    }
    
    cell.accessoryType = UITableViewCellAccessoryNone;
    cell.selectionStyle = UITableViewCellSelectionStyleBlue;
    
    if (indexPath.row == 0) {
        cell.textLabel.text = NSLocalizedStringFromTableInBundle(@"title_pdk_generator_description", @"PassiveDataKit", [NSBundle bundleForClass:self.class], nil);
        cell.detailTextLabel.text = NSLocalizedStringFromTableInBundle(@"subtitle_pdk_generator_description", @"PassiveDataKit", [NSBundle bundleForClass:self.class], nil);
    }
    
    return cell;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    NSArray * children = self.detailsView.subviews;
    
    for (UIView * child in children) {
        [child removeFromSuperview];
    }
    
    NSString * path = [[NSBundle mainBundle] pathForResource:@"pdk_battery_description" ofType:@"html"];
    
    if (path == nil) {
        UILabel * warningLabel = [[UILabel alloc] initWithFrame:CGRectZero];
        warningLabel.backgroundColor = [UIColor blackColor];
        
        NSString * message = [NSString stringWithFormat:NSLocalizedStringFromTableInBundle(@"warning_pdk_missing_resource", @"PassiveDataKit", [NSBundle bundleForClass:self.class], nil), @"pdk_battery_description.html"];
        
        UIFont * font = [UIFont fontWithName:@"Menlo-Bold" size:16];
        
        CGRect titleRect = [message boundingRectWithSize:CGSizeMake(self.view.frame.size.width - 16, 1000)
                                                 options:NSStringDrawingUsesLineFragmentOrigin
                                              attributes:@{ NSFontAttributeName: font }
                                                 context:nil];
        
        warningLabel.frame = CGRectMake(8, 8, self.view.frame.size.width - 16, titleRect.size.height);
        warningLabel.text = message;
        warningLabel.font = font;
        warningLabel.textColor = [UIColor colorWithRed:0 green:1.0 blue:0 alpha:1.0];
        warningLabel.textAlignment = NSTextAlignmentLeft;
        warningLabel.numberOfLines = 0;
        
        [self.detailsView addSubview:warningLabel];
    } else {
        WKWebView * webView = [[WKWebView alloc] initWithFrame:self.detailsView.bounds];
        webView.navigationDelegate = self;
        [webView loadFileURL:[NSURL fileURLWithPath:path] allowingReadAccessToURL:[NSURL fileURLWithPath:path]];
        
        [self.detailsView addSubview:webView];
    }
}

@end
