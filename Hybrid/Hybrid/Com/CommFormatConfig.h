//
//  CommFormatConfig.h
//  Hybrid
//
//  Created by JD on 16/9/20.
//  Copyright © 2016年 YC.L. All rights reserved.
//

#import <Foundation/Foundation.h>
//webview传递的url须符合url规范，格式：scheme://host?params=jsonStr，系统最终截取到jsonStr，并反析成对象
static NSString *keyUrlScheme = @"keyUrlScheme";//对应scheme
static NSString *keyUrlHost = @"keyUrlHost";//对应host
static NSString *keyUrlParams = @"keyUrlParams";//对应params


static NSString *keyCommServiceName = @"__keyCommServiceName";//Comm中注册的相关服务方法
static NSString *keyCommParams = @"__keyCommParams";//传递给Comm的参数
static NSString *keyCommJsCallBackMethodName = @"__keyCommJsCallBackMethodName";//Comm运行完成后回调js的相关方法名
static NSString *keyCommJsCallBackIdentify = @"__keyCommJsCallBackIdentify";//回调js方法中特定jsblock的表识，可用于所有hybrid中js部分回调使用同一个函数，此时需要此表识来区别对应的jsblock
//comm类中注册相关service功能