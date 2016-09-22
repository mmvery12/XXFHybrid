//
//  XXFileManager.m
//  XXFFile
//
//  Created by JD on 16/9/20.
//  Copyright © 2016年 YC.L. All rights reserved.
//

#import "ModuleManager.h"
#import "Module.h"
@interface ModuleManager ()
{
    NSMutableArray *modules;
    NSFileManager *fileManager;
}
@end

@implementation ModuleManager

- (instancetype)init
{
    self = [super init];
    if (self) {
        modules = [NSMutableArray new];
        fileManager = [NSFileManager defaultManager];
    }
    return self;
}

-(void)selfAnalyze;
{
    NSData *myEncodedObject = [[NSUserDefaults standardUserDefaults] objectForKey:@"modules"];
    modules = [NSKeyedUnarchiver unarchiveObjectWithData: myEncodedObject];
    if (!modules) {
        modules = [NSMutableArray new];
    }
    [self deleteContentsWithOutModules:modules];//配置文件中没有的统统删掉
}

-(NSArray <Module *> *)analyzeModules:(NSArray <Module *> *)modules_;
{
    NSMutableArray *needUpdate = [NSMutableArray new];
    NSMutableArray *normal = [NSMutableArray new];
    {
        for (Module *md in modules_) {
            Module *mmd = [self findModuleWithModuleName:md.moduleName];
            if (mmd && [md.version isEqualToString:mmd.version] && [self isModuleReady:mmd]) {
                [normal addObject:mmd];
            }else
                [needUpdate addObject:md];
        }
    }
    [modules removeObjectsInArray:normal];
    [modules removeObjectsInArray:needUpdate];
    for (Module *md in modules) {
        [self deleteModule:md];
    }
    [modules removeAllObjects];
    [modules addObjectsFromArray:normal];
    [modules addObjectsFromArray:needUpdate];
    {
        NSData *archiveCarPriceData = [NSKeyedArchiver archivedDataWithRootObject:modules];
        [[NSUserDefaults standardUserDefaults] setObject:archiveCarPriceData forKey:@"modules"];
        [[NSUserDefaults standardUserDefaults] synchronize];
    }
    return needUpdate;
}

-(Module *)findModuleWithModuleName:(NSString *)moduleName
{
    for (Module *md in modules) {
        if ([md.moduleName isEqualToString:moduleName]) {
            return md;
        }
    }
    return nil;
}

-(NSData *)findDataWithModuleName:(NSString *)moduleName fileName:(NSString *)fileName inDirectory:(NSString *)directoryName;
{
    NSString *cachePath = [self cachePath];
    NSString *path = nil;
    if (directoryName==nil || [directoryName isKindOfClass:[NSString class]]) {
        path = [NSString stringWithFormat:@"%@/%@",cachePath,fileName];
    }else
        path = [NSString stringWithFormat:@"%@/%@/%@",cachePath,directoryName,fileName];
    
    return [self findSourceAtRelativePath:path];
}

-(NSData *)findSourceAtRelativePath:(NSString *)path;
{
    return [NSData dataWithContentsOfFile:path];
}

-(BOOL)zipArchiveModule:(Module *)module data:(NSData *)data;
{
    NSString *path = [NSString stringWithFormat:@"%@/%@",[self cachePath],module.moduleName];
    [self createpath:path];
    return [data writeToFile:[NSString stringWithFormat:@"%@/%@.a",path,module.identify] atomically:YES];
}

-(void)deleteModule:(Module *)module_
{
    [fileManager removeItemAtPath:[NSString stringWithFormat:@"%@/%@",[self cachePath],module_.moduleName] error:nil];
}

-(void)deleteContentsWithOutModules:(NSArray <Module *>*)modules_
{
    NSArray *tempContent = [fileManager contentsOfDirectoryAtPath:[self cachePath] error:nil];
    NSMutableArray *tempArr = [NSMutableArray new];
    for (NSString *name in tempContent) {
        for (Module *md in modules_) {
            if (![name isEqualToString:md.moduleName]) {
                [tempArr addObject:name];
            }
        }
    }
    for (NSString *name in tempArr) {
        [fileManager removeItemAtPath:[NSString stringWithFormat:@"%@/%@",[self cachePath],name] error:nil];
    }
}

-(void)createpath:(NSString *)path
{
    [fileManager createDirectoryAtPath:path withIntermediateDirectories:YES attributes:nil error:nil];
}

-(NSString *)cachePath
{
    NSString *path = [NSString stringWithFormat:@"%@/%@",[NSSearchPathForDirectoriesInDomains(NSCachesDirectory, NSUserDomainMask, YES) firstObject],EFolderPath];
    [self createpath:path];
    return path;
}

-(BOOL)isModuleReady:(Module *)module;
{
    NSString *path = [NSString stringWithFormat:@"%@/%@",[self cachePath],module.moduleName];
    return [fileManager fileExistsAtPath:path];
}
@end
