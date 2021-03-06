//
//  Module.h
//  Hybrid
//
//  Created by JD on 16/9/21.
//  Copyright © 2016年 YC.L. All rights reserved.
//

#import <Foundation/Foundation.h>


/*************************
 module映射的数据元组
 *************************/

typedef NS_ENUM(NSInteger,ModuleStatus) {
    ModuleStatusNone = 0,//需下载
    ModuleStatusDowning,//在下载
    ModuleStatusNeedArchize,//需解压
    ModuleStatusReady//可以使用
};

@interface Module : NSObject<NSCoding >
@property (nonatomic,copy)NSString *identify;
@property (nonatomic,copy)NSString *moduleName;
@property (nonatomic,copy)NSString *remoteurl;
@property (nonatomic,copy)NSString *version;
@property (nonatomic,copy)NSString *type;
@property (nonatomic,copy)NSMutableArray *depend;
@property (nonatomic,assign)ModuleStatus status;
@end
