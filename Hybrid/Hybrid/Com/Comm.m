//
//  Com.m
//  Hybrid
//
//  Created by JD on 16/9/20.
//  Copyright © 2016年 YC.L. All rights reserved.
//
/****************************************
 使用时通过：Com___Params_CallBackJsMethod_CallBackJsBlockIdentity_ExcWebView(_serviceName) 函数注册相关service，_serviceName即webview 传递过来的service，通过CommFormatConfig中keyCommServiceName获取
****************************************/
#import "Comm.h"
#import <UIKit/UIKit.h>
#define Com___Params_CallBackJsMethod_CallBackJsBlockIdentity_ExcWebView(_serviceName) \
+(void)com##_serviceName:(id)params p2:(NSString *)callbackjsmethod p3:(NSString *)callbackjsblockidentity p4:(UIWebView *)excwebview

@implementation Comm
+(BOOL)resolveInstanceMethod:(SEL)sel
{
    @selector(comNavigationHidden:p2:p3:p4:);
    return YES;
}

Com___Params_CallBackJsMethod_CallBackJsBlockIdentity_ExcWebView(NavigationHidden)
{
    
}

Com___Params_CallBackJsMethod_CallBackJsBlockIdentity_ExcWebView(TabbarHidden)
{

}

Com___Params_CallBackJsMethod_CallBackJsBlockIdentity_ExcWebView(Storage)
{
    
}

@end
