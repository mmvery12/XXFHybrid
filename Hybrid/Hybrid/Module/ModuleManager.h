//
//  XXFileManager.h
//  XXFFile
//
//  Created by JD on 16/9/20.
//  Copyright © 2016年 YC.L. All rights reserved.
//

#import <Foundation/Foundation.h>
static NSString *const EFolderPath = @"EFolderPath";
#import "Module.h"
@interface ModuleManager : NSObject
//自检，会删除没有存档的文件
-(void)selfAnalyze;
-(NSArray <Module *>*)modulesFromeDictionary:(NSDictionary *)dict;
//分析入参于本地配置的不同，返回需要下载的module，会删除入参中没有的module
-(void)analyzeModules:(NSArray <Module *> *)modules result:(void (^)(NSArray <Module *> *))resultblock;
//返回输入URI指向的文件数据
-(NSData *)findSourceAtRelativePath:(NSString *)path;
//返回指定module名对应的module结构
-(Module *)findModuleWithModule:(Module *)module;
-(Module *)findModuleWithModuleName:(NSString *)moduleName;
-(Module *)findModuleWithRemoteUrl:(NSString *)remoteurl;
//返回指定module名、文件名对应的数据
-(NSData *)findDataWithModuleName:(NSString *)moduleName fileName:(NSString *)fileName;
//请勿在主线程执行次函数，有写文件操作
-(BOOL)storageModule:(Module *)module data:(NSData *)data system:(BOOL)system complete:(dispatch_block_t)complete;
//判断module是否可用
-(ModuleStatus)isModuleReady:(Module *)module;
//module确定后才能执行交互操作，不然module中找不到对应的module
-(void)afterModuleInit:(dispatch_block_t)block;

-(void)addModuleInProgress:(Module *)module;
-(BOOL)isProgressRuning;
@end
