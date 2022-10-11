//
//  PDKGeneratorDetailsViewController.m
//  PassiveDataKit
//
//  Created by Chris Karr on 8/9/18.
//  Copyright © 2018 Audacious Software. All rights reserved.
//

#import "PDKGeneratorDetailsViewController.h"

@interface PDKGeneratorDetailsViewController ()

@property UIView * separator;

@end

@implementation PDKGeneratorDetailsViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    
    self.detailsView = [[UIView alloc] init];
    
    [self.view addSubview:self.detailsView];
    
    self.parametersView = [[UITableView alloc] init];
    self.parametersView.dataSource = self;
    self.parametersView.delegate = self;
    
    [self.view addSubview:self.parametersView];
    
    self.separator = [[UIView alloc] init];
    self.separator.backgroundColor = self.navigationController.navigationBar.barTintColor;
    self.separator.layer.shadowColor = [UIColor colorWithWhite:0.0 alpha:0.5].CGColor;
    self.separator.layer.shadowOpacity = 0.5;
    self.separator.layer.shadowRadius = 2.0;
    self.separator.layer.shadowOffset = CGSizeMake(0, 0);
    
    [self.view addSubview:self.separator];
}

- (void) viewDidLayoutSubviews {
    [super viewDidLayoutSubviews];
    
    CGSize size = self.view.bounds.size;
    
    CGFloat panelHeight = (size.height - 16) / 2;
    
    self.detailsView.frame = CGRectMake(0, 0, self.view.bounds.size.width, panelHeight);
    self.separator.frame = CGRectMake(0, panelHeight, self.view.bounds.size.width, 16);
    self.parametersView.frame = CGRectMake(0, panelHeight + 16, self.view.bounds.size.width, panelHeight);
}

- (void) viewDidAppear:(BOOL)animated {
    [super viewDidAppear:animated];
    
    [self.parametersView selectRowAtIndexPath:[NSIndexPath indexPathForRow:0 inSection:0] animated:NO scrollPosition:UITableViewScrollPositionTop];
    [self tableView:self.parametersView didSelectRowAtIndexPath:[NSIndexPath indexPathForRow:0 inSection:0]];
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    return 0;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    return [tableView dequeueReusableCellWithIdentifier:@""];
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {

}

- (void)webView:(WKWebView *)webView decidePolicyForNavigationAction:(WKNavigationAction *)navigationAction decisionHandler:(void (^)(WKNavigationActionPolicy))decisionHandler {
    [[UIApplication sharedApplication] openURL:navigationAction.request.URL
                                       options:@{}
                             completionHandler:^(BOOL success) {
    }];
    
    decisionHandler(WKNavigationActionPolicyAllow);
}

@end
