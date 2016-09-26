//
//  XXFileManager.m
//  XXFFile
//
//  Created by JD on 16/9/20.
//  Copyright © 2016年 YC.L. All rights reserved.
//

#import "ModuleManager.h"
#import "Module.h"
static NSString *const TFolderPath = @"TFolderPath";
@interface ModuleManager ()
{
    NSMutableArray *modules;
    NSFileManager *fileManager;
    CFRunLoopRef cfRunloop;
    NSSet *needArchiveType;
}
@property (atomic,assign)BOOL refreshFlag;
@end

@implementation ModuleManager

- (instancetype)init
{
    self = [super init];
    if (self) {
        modules = [NSMutableArray new];
        fileManager = [NSFileManager defaultManager];
        needArchiveType = [NSSet setWithObjects:@"zip",@"rar", nil];
    }
    return self;
}

-(void)selfAnalyze;
{
    @synchronized (modules) {
        NSData *myEncodedObject = [[NSUserDefaults standardUserDefaults] objectForKey:@"modules"];
        modules = [NSKeyedUnarchiver unarchiveObjectWithData: myEncodedObject];
        if (!modules) {
            modules = [NSMutableArray new];
        }
        [self deleteContentsWithOutModules:modules];//配置文件中没有的统统删掉
    }
}

-(NSArray <Module *> *)analyzeModules:(NSArray <Module *> *)modules_;
{
    NSMutableArray *needUpdate = [NSMutableArray new];
    @synchronized (modules) {
        if (modules_.count==0 && modules.count==0) {
            _refreshFlag = YES;
            if (cfRunloop){
                CFRunLoopStop(cfRunloop);
            }
        }else
        {
            NSMutableArray *normal = [NSMutableArray new];
            {
                for (Module *md in modules_) {
                    Module *mmd = [self findModuleWithModuleName:md.moduleName];
                    if (mmd &&
                        [md.version isEqualToString:mmd.version] &&
                        [self isModuleReady:mmd]) {
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
            _refreshFlag = YES;
            if (cfRunloop){
                CFRunLoopStop(cfRunloop);
            }
        }
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

-(Module *)findModuleWithRemoteUrl:(NSString *)remoteurl;
{
    for (Module *md in modules) {
        if ([md.remoteurl isEqualToString:remoteurl]) {
            return md;
        }
    }
    return nil;
}

-(NSData *)findDataWithModuleName:(NSString *)moduleName fileName:(NSString *)fileName;
{
    if (![fileName isKindOfClass:[NSString class]]) {
        return nil;
    }
    NSString *cachePath = [self cachePath];
    NSString *path = nil;
    path = [NSString stringWithFormat:@"%@/%@/%@",cachePath,moduleName,fileName];
    return [self findSourceAtRelativePath:path];
}

-(NSData *)findSourceAtRelativePath:(NSString *)path;
{
    return [NSData dataWithContentsOfFile:path];
}

-(BOOL)storageModule:(Module *)module data:(NSData *)data;
{
    if (!module) return NO;
    NSString *path = [NSString stringWithFormat:@"%@/%@",[self cachePath],module.moduleName];
    [self createpath:path];
    if ([needArchiveType containsObject:module.type]) {//解压
        module.status = ModuleStatusNeedArchize;
        path = [NSString stringWithFormat:@"%@/%@",[self tcachePath],module.moduleName];
        [self createpath:path];
        
    }else
    {//直写
        BOOL success = [data writeToFile:[NSString stringWithFormat:@"%@/%@.a",path,module.identify] atomically:YES];;
        if (success) {
            module.status = ModuleStatusReady;
        }else
            module.status = ModuleStatusNone;
        return success;
    }
    return NO;
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

-(NSString *)tcachePath
{
    NSString *path = [NSString stringWithFormat:@"%@/%@",[NSSearchPathForDirectoriesInDomains(NSCachesDirectory, NSUserDomainMask, YES) firstObject],TFolderPath];
    [self createpath:path];
    return path;
}

-(BOOL)isModuleReady:(Module *)module;
{
    NSString *path = [NSString stringWithFormat:@"%@/%@",[self cachePath],module.moduleName];
    return [fileManager fileExistsAtPath:path];
}

-(void)afterModuleInit:(dispatch_block_t)block;
{
    cfRunloop = CFRunLoopGetCurrent();
    CFRunLoopSourceContext context = {0, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL};
    CFRunLoopSourceRef source = CFRunLoopSourceCreate(kCFAllocatorDefault, 0, &context);
    CFRunLoopAddSource(cfRunloop, source, kCFRunLoopDefaultMode);
    while (!_refreshFlag) {
        CFRunLoopRun();
    }
    CFRunLoopRemoveSource(CFRunLoopGetCurrent(), source, kCFRunLoopDefaultMode);
    CFRelease(source);
    block();
}
@end
