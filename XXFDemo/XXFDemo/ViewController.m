//
//  ViewController.m
//  XXFDemo
//
//  Created by JD on 16/9/19.
//  Copyright © 2016年 YC.L. All rights reserved.
//

#import "ViewController.h"
#import <Hybrid/HyBridManager.h>
@interface ViewController ()

@end

@implementation ViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    
    UIButton *btn = [UIButton new];
    [btn setTitle:@"123" forState:UIControlStateNormal];
    [btn setTitleColor:[UIColor blackColor] forState:UIControlStateNormal];
    [btn addTarget:self action:@selector(xxxx) forControlEvents:UIControlEventTouchUpInside];
    btn.frame = CGRectMake(0, 0, 300, 300);
    [self.view addSubview:btn];
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
}

-(void)xxxx
{
    [HyBridManager UseResourceWithModuleName:@"moduleA" fileName:@"" complete:^(NSData *source, NSError *error) {
        
    }];
}

@end
