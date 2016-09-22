//
//  Module.h
//  Hybrid
//
//  Created by JD on 16/9/21.
//  Copyright © 2016年 YC.L. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "ModuleSelect.h"
@interface Module : NSObject<ModuleSelect,NSCoding >
@property (nonatomic,copy)NSString *identify;
@property (nonatomic,copy)NSString *moduleName;
@property (nonatomic,copy)NSString *remoteurl;
@property (nonatomic,copy)NSString *version;
@property (nonatomic,copy)NSMutableArray *depend;
@end
