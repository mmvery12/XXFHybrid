//
//  ViewController.m
//  XXFDemo
//
//  Created by JD on 16/9/19.
//  Copyright © 2016年 YC.L. All rights reserved.
//

#import "ViewController.h"
#import <Hybrid/HyBridManager.h>
@interface ViewController ()<UIWebViewDelegate>

@end

@implementation ViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    
    UIWebView *webview = [[UIWebView alloc] initWithFrame:self.view.bounds];
    [self.view addSubview:webview];
    [webview loadRequest:[NSURLRequest requestWithURL:[NSURL URLWithString:@"http://www.baidu.com"]]];
    webview.delegate = self;
    [self xxxx];
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
}

-(void)xxxx
{
    [HyBridManager UseResourceWithModuleName:@"moduleA" fileName:@"TencentOpenAPI" complete:^(NSData *source, NSError *error) {
        
    }];
}

- (BOOL)webView:(UIWebView *)webView shouldStartLoadWithRequest:(NSURLRequest *)request navigationType:(UIWebViewNavigationType)navigationType;
{
    NSData * data = [NSData dataWithContentsOfFile:[[NSBundle mainBundle] pathForResource:@"URL" ofType:@"json"]];
    NSDictionary *dict = [NSJSONSerialization JSONObjectWithData:data options:0 error:nil];
    data = [NSJSONSerialization dataWithJSONObject:dict options:0 error:nil];
    NSString *str = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
    str = [NSString stringWithFormat:@"%@://%@?%@=%@",keyUrlScheme,keyUrlHost,keyUrlParams,str];
    str = [str stringByAddingPercentEscapesUsingEncoding:NSUTF8StringEncoding];
    NSURL *temp = [NSURL URLWithString:str];
    return [HyBridManager HandleWebViewURL:temp CommExcWebView:webView];
}
- (void)webViewDidStartLoad:(UIWebView *)webView;
{
}
- (void)webViewDidFinishLoad:(UIWebView *)webView;
{
}
- (void)webView:(UIWebView *)webView didFailLoadWithError:(nullable NSError *)error;
{
}

@end
