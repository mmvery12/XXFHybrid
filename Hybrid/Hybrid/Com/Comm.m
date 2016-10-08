//
//  Com.m
//  Hybrid
//
//  Created by JD on 16/9/20.
//  Copyright © 2016年 YC.L. All rights reserved.
//
/****************************************
 使用时通过：___Dict_CallBackJsMethod_CallBackJsBlockIdentity_ExcWebView_ExcResultBlock(_serviceName) 函数注册相关service，_serviceName即webview 传递过来的service，通过CommFormatConfig中keyCommServiceName获取
****************************************/
#import "Comm.h"
#import <UIKit/UIKit.h>
#define ___Dict_CallBackJsMethod_CallBackJsBlockIdentity_ExcWebView_ExcResultBlock(_serviceName) \
+(void)com##_serviceName:(id)params \
                      p2:(NSString *)callbackjsmethod \
                      p3:(NSString *)callbackjsblockidentity \
                      p4:(UIWebView *)excwebview \
                      p5:(void (^)(NSString *jsMethodName,NSString *jsIdentify,id jsParams))ExcResultBlock;

#define ExcResultBlockWithResult(_AVG_) ExcResultBlock(callbackjsmethod,callbackjsblockidentity,_AVG_)

@implementation Comm
+ (BOOL)resolveInstanceMethod:(SEL)sel
{
    return YES;
}
+ (BOOL)resolveClassMethod:(SEL)sel
{
    return YES;
}

/**************************
 相关参数：
 params,js传过来的参数
 callbackjsmethod，回调js的执行方法民
 callbackjsblockidentity，回调js的执行方法block识别号
 excwebview，处理的js
 ExcResultBlock，service处理后通知掉用handleWebViewURL：调用者的回调block（推荐在这个block里完成webview执行js）
 **************************/


___Dict_CallBackJsMethod_CallBackJsBlockIdentity_ExcWebView_ExcResultBlock(NavigationHidden)
{
    ExcResultBlockWithResult(nil);
}

___Dict_CallBackJsMethod_CallBackJsBlockIdentity_ExcWebView_ExcResultBlock(TabbarHidden)
{

}

___Dict_CallBackJsMethod_CallBackJsBlockIdentity_ExcWebView_ExcResultBlock(Storage)
{
    
}

@end
