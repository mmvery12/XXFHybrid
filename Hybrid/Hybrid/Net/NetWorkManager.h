//
//  NetWorkManager.h
//  NetWork
//
//  Created by JD on 16/9/20.
//  Copyright © 2016年 YC.L. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface NetWorkManager : NSObject
-(void)addTask:(NSString *)urlStr complete:(void (^)(NSData *data,NSError *error))block;
-(void)addTask:(NSString *)urlStr params:(id)params complete:(void (^)(NSData *data,NSError *error))block;
-(void)addTasks:(NSArray <NSString *> *)urlStrs tag:(NSString *)tag moduleComplete:(void (^)(NSString *url,NSData *data,NSError *error))oneblock allcomplete:(void (^)(void))block;
-(BOOL)isAllTaskFinishWithTag:(NSString *)tag;
@end
