//
//  CommFormatConfig.h
//  Hybrid
//
//  Created by JD on 16/9/20.
//  Copyright © 2016年 YC.L. All rights reserved.
//

#import <Foundation/Foundation.h>
//webview传递的url须符合url规范，格式：scheme://host?params=jsonStr，系统最终截取到jsonStr，并反析成对象
static NSString *urlSchemeStr = @"__urlSchemeStr";//对应scheme
static NSString *urlHostStr = @"__urlHostStr";//对应host
static NSString *urlParamsStr = @"__params";//对应params


static NSString *commClassName = @"__commClassName";
static NSString *CommSelNameConfig = @"__CommSelNameConfig";
static NSString *CommParamsConfig = @"__CommParamsConfig";
static NSString *CommJsCallBackIdentifyConfig = @"__CommJsCallBackIdentifyConfig";


