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
    
    // UIImage * backIcon = [UIImage imageNamed:@"PDK Icon - Back"
    //                                inBundle:[NSBundle bundleForClass:self.class]
    //           compatibleWithTraitCollection:nil];
    
    // self.navigationItem.title = NSLocalizedString(@"pdk_alerts", nil);

    // self.navigationItem.leftBarButtonItem = [[UIBarButtonItem alloc] initWithImage:backIcon
    //                                                                         style:UIBarButtonItemStylePlain
    //                                                                        target:self
    //                                                                        action:@selector(goBack)];

    self.tableView.separatorStyle = UITableViewCellSeparatorStyleNone;
    self.tableView.backgroundColor = [UIColor colorWithWhite:(0xe0 / 255.0) alpha:1.0];
}

- (void) goBack {
    [self.navigationController popViewControllerAnimated:YES];
}

- (void) viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    
    self.activeAlerts = [[PassiveDataKit sharedInstance] alerts];
    
    [self.tableView reloadData];

    if (self.activeAlerts.count == 0) {
        self.navigationItem.title = NSLocalizedStringFromTableInBundle(@"alerts_title_ready", @"PassiveDataKit", [NSBundle bundleForClass:self.class], nil);
    } else if (self.activeAlerts.count == 1) {
        self.navigationItem.title = NSLocalizedStringFromTableInBundle(@"alerts_title_single_alert", @"PassiveDataKit", [NSBundle bundleForClass:self.class], nil);
    } else {
        self.navigationItem.title = [NSString stringWithFormat:NSLocalizedStringFromTableInBundle(@"alerts_title_multiple_alerts", @"PassiveDataKit", [NSBundle bundleForClass:self.class], nil), (int) self.activeAlerts.count];

    }
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
        cell.selectionStyle = UITableViewCellSelectionStyleNone;
    }
    
    UIView * oldCard = [cell.contentView viewWithTag:1000];
    
    if (oldCard != nil) {
        [oldCard removeFromSuperview];
    }
    
    PDKAlert * alert = self.activeAlerts[indexPath.row];
    
    UIView * card = [self tableView:tableView viewForAlert:alert];
    
    [cell.contentView addSubview:card];
    cell.contentView.backgroundColor = [UIColor colorWithWhite:(0xe0 / 255.0) alpha:1.0];
    
    return cell;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    PDKAlert * alert = self.activeAlerts[indexPath.row];
    
    if (alert.action != nil) {
        alert.action();
    }
}

- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath {
    PDKAlert * alert = self.activeAlerts[indexPath.row];
    
    UIView * card = [self tableView:tableView viewForAlert:alert];
    
    return card.frame.size.height + 10;
}

- (UIView *) tableView:(UITableView *) tableView viewForAlert:(PDKAlert *) alert {
    CGRect bounds = tableView.bounds;
    
    CGSize textSize = CGSizeMake(bounds.size.width - 20, 9999);
    
    UIFont * titleFont = [UIFont boldSystemFontOfSize:14];
    UIFont * messageFont = [UIFont systemFontOfSize:14];

    CGSize titleSize = [alert.title boundingRectWithSize:textSize
                                                 options:NSStringDrawingUsesLineFragmentOrigin
                                              attributes:@{ NSFontAttributeName: titleFont }
                                                 context:nil].size;

    CGSize messageSize = [alert.message boundingRectWithSize:textSize
                                                     options:NSStringDrawingUsesLineFragmentOrigin
                                                  attributes:@{ NSFontAttributeName: messageFont }
                                                     context:nil].size;
    
    CGRect cardFrame = CGRectMake(0, 0, textSize.width, titleSize.height + messageSize.height + 20);
    
    UIView * card = [[UIView alloc] initWithFrame:cardFrame];
    card.backgroundColor = [UIColor whiteColor];
    
    UIView * headerBackground = [[UIView alloc] initWithFrame:CGRectMake(0, 0, textSize.width, titleSize.height + 10)];
    
    UILabel * titleLabel = [[UILabel alloc] initWithFrame:CGRectMake(5, 5, titleSize.width, titleSize.height)];
    titleLabel.font = titleFont;
    titleLabel.text = alert.title;
    titleLabel.textColor = [UIColor whiteColor];

    if (alert.level == PDKAlertLevelError) {
        headerBackground.backgroundColor = [UIColor colorWithRed:(0xb7 / 255.0) green:(0x1c / 255.0) blue:(0x1c / 255.0) alpha:1.0];
    } else {
        headerBackground.backgroundColor = [UIColor colorWithRed:(0x21 / 255.0) green:(0x21 / 255.0) blue:(0x21 / 255.0) alpha:1.0];
    }

    [headerBackground addSubview:titleLabel];
    
    [card addSubview:headerBackground];
    
    UILabel * messageLabel = [[UILabel alloc] initWithFrame:CGRectMake(5, titleSize.height + 15, messageSize.width, messageSize.height)];
    messageLabel.numberOfLines = 0;
    messageLabel.font = messageFont;
    messageLabel.text = alert.message;

    [card addSubview:messageLabel];
    
    card.layer.cornerRadius = 5.0;
    card.layer.masksToBounds = YES;

    cardFrame.origin.x = 10;
    cardFrame.origin.y = 10;

    UIView * cardHolder = [[UIView alloc] initWithFrame:cardFrame];
    cardHolder.layer.shadowOpacity = 0.5;
    cardHolder.layer.shadowOffset = CGSizeMake(0, 2);
    cardHolder.tag = 1000;
    
    [cardHolder addSubview:card];
    
    return cardHolder;
}

@end
