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
-(void)selfAnalyze;
-(NSArray <Module *> *)analyzeModules:(NSArray <Module *> *)modules;
-(NSData *)findSourceAtRelativePath:(NSString *)path;
-(Module *)findModuleWithModuleName:(NSString *)moduleName;
-(NSData *)findDataWithModuleName:(NSString *)moduleName fileName:(NSString *)fileName inDirectory:(NSString *)directoryName;
-(BOOL)zipArchiveModule:(Module *)module data:(NSData *)data;
-(BOOL)isModuleReady:(Module *)module;
//module确定后才能执行交互操作，不然module中找不到对应的module
-(void)afterModuleInit:(dispatch_block_t)block;
@end
