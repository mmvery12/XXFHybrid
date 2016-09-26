//
//  XXFileManager.h
//  XXFFile
//
//  Created by JD on 16/9/20.
//  Copyright © 2016年 YC.L. All rights reserved.
//

#import <Foundation/Foundation.h>
static NSString *const EFolderPath = @"EFolderPath";
@class Module;
@interface ModuleManager : NSObject
//自检，会删除没有存档的文件
-(void)selfAnalyze;
//分析入参于本地配置的不同，返回需要下载的module，会删除入参中没有的module
-(NSArray <Module *> *)analyzeModules:(NSArray <Module *> *)modules;
//返回输入URI指向的文件数据
-(NSData *)findSourceAtRelativePath:(NSString *)path;
//返回指定module名对应的module结构
-(Module *)findModuleWithModuleName:(NSString *)moduleName;
-(Module *)findModuleWithRemoteUrl:(NSString *)remoteurl;
//返回指定module名、文件名对应的数据
-(NSData *)findDataWithModuleName:(NSString *)moduleName fileName:(NSString *)fileName;
//将moduel解压缩，写入文件夹
//请勿在主线程执行次函数，有写文件操作
-(BOOL)storageModule:(Module *)module data:(NSData *)data;
//判断module是否可用
//请勿在主线程执行次函数，有runloop等待操作
-(BOOL)isModuleReady:(Module *)module;
//module确定后才能执行交互操作，不然module中找不到对应的module
-(void)afterModuleInit:(dispatch_block_t)block;
@end
