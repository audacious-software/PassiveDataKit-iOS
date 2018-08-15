//
//  PDKAlertsTableViewController.m
//  PassiveDataKit
//
//  Created by Chris Karr on 8/14/18.
//  Copyright © 2018 Audacious Software. All rights reserved.
//

#import "PassiveDataKit.h"

#import "PDKAlertsTableViewController.h"

@interface PDKAlertsTableViewController ()

@property NSArray * activeAlerts;

@end

@implementation PDKAlertsTableViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    
    // Uncomment the following line to preserve selection between presentations.
    // self.clearsSelectionOnViewWillAppear = NO;
    
    // Uncomment the following line to display an Edit button in the navigation bar for this view controller.
    // self.navigationItem.rightBarButtonItem = self.editButtonItem;
}

- (void) viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    
    self.activeAlerts = [[PassiveDataKit sharedInstance] alerts];
    
    [self.tableView reloadData];
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

#pragma mark - Table view data source

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
    return 1;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    return self.activeAlerts.count;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    UITableViewCell * cell = [tableView dequeueReusableCellWithIdentifier:@"PDKAlertsTableCell"];
    
    if (cell == nil) {
        cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleSubtitle reuseIdentifier:@"PDKAlertsTableCell"];
    }
    
    cell.accessoryType = UITableViewCellAccessoryNone;
    cell.selectionStyle = UITableViewCellSelectionStyleBlue;
    
    PDKAlert * alert = self.activeAlerts[indexPath.row];
    
    cell.textLabel.text = alert.message;
    
    return cell;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    PDKAlert * alert = self.activeAlerts[indexPath.row];
    
    if (alert.action != nil) {
        alert.action();
    }
}

@end
