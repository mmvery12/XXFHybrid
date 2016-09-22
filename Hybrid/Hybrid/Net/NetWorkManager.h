//
//  NetWorkManager.h
//  NetWork
//
//  Created by JD on 16/9/20.
//  Copyright © 2016年 YC.L. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface NetWorkManager : NSObject
//添加task，其中判定urlStr是否存在于下载队列，存在时给对应urlstr添加此指定的block，不再做重复下载
-(void)addTask:(NSString *)urlStr complete:(void (^)(NSData *data,NSError *error))block;
//添加task，其中判定urlStr是否存在于下载队列，存在时给对应urlstr添加此指定的block，不再做重复下载
-(void)addTask:(NSString *)urlStr params:(id)params complete:(void (^)(NSData *data,NSError *error))block;
//批量添加task，其中判定urlStr是否存在于下载队列，存在时给对应urlstr添加此指定的block，不再做重复下载
-(void)addTasks:(NSArray <NSString *> *)urlStrs tag:(NSString *)tag moduleComplete:(void (^)(NSString *url,NSData *data,NSError *error))oneblock allcomplete:(void (^)(void))block;
//判断批量任务是否都已完成
-(BOOL)isAllTaskFinishWithTag:(NSString *)tag;
@end
