//
//  XXFileManager.m
//  XXFFile
//
//  Created by JD on 16/9/20.
//  Copyright © 2016年 YC.L. All rights reserved.
//

#import "ModuleManager.h"
#import "Module.h"
#import "Zip.h"
static NSString *const TFolderPath = @"TFolderPath";
@interface ModuleManager ()
{
    NSFileManager *fileManager;
    NSSet *needArchiveType;
    NSMutableArray *modules;
    NSMutableArray *modulesInProcess;
    NSMutableDictionary *threadrunloops;
    BOOL refreshFlag;
}
@end

@implementation ModuleManager
- (instancetype)init
{
    self = [super init];
    if (self) {
        modules = [NSMutableArray new];
        fileManager = [NSFileManager defaultManager];
        needArchiveType = [NSSet setWithObjects:@"zip",@"rar", nil];
        modulesInProcess = [NSMutableArray new];
        threadrunloops = [NSMutableDictionary new];
        [self selfAnalyze];
    }
    return self;
}

-(void)selfAnalyze;
{
    NSData *myEncodedObject = [[NSUserDefaults standardUserDefaults] objectForKey:@"modules"];
    NSMutableArray *temp = [NSKeyedUnarchiver unarchiveObjectWithData: myEncodedObject];
    if ([temp isKindOfClass:[NSArray class]]) {
        modules = [NSMutableArray arrayWithArray:temp];
    }
     
    for (Module *md in modules) {
        if (md.status == ModuleStatusDowning) {
            md.status = ModuleStatusNone;
        }
    }
    [self deleteContentsWithOutModules:modules];//配置文件中没有的统统删掉
}

-(NSArray <Module *>*)modulesFromeDictionary:(NSDictionary *)dict
{
    if (!dict) {
        return nil;
    }
    NSMutableArray *arr = [NSMutableArray new];
    for (NSDictionary *tdict in dict[@"modules"]) {
        Module *module = [Module new];
        module.identify = tdict[@"identify"];
        module.moduleName = tdict[@"moduleName"];
        module.remoteurl = tdict[@"remoteurl"];
        module.version = tdict[@"version"];
        module.type = tdict[@"type"];
        module.depend = tdict[@"depend"];
        [arr addObject:module];
    }
    return arr;
}


-(void)analyzeModules:(NSArray <Module *> *)modules_ result:(void (^)(NSArray <Module *> *))resultblock;
{
     
    refreshFlag = NO;
    NSMutableArray *needUpdate = [NSMutableArray new];
    @synchronized (self) {
        if ([modules_ isKindOfClass:[NSArray class]] && modules_.count!=0) {
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
        }
    
        for (Module *md in needUpdate) {
            md.status = ModuleStatusNone;
        }
        
    }
    NSThread *thread;
    thread = threadrunloops[@"afterModuleInit"][@"thread"];
    resultblock(needUpdate);
    refreshFlag = YES;
    if (thread){
        [self performSelector:@selector(changeloop:) onThread:thread withObject:threadrunloops[@"afterModuleInit"] waitUntilDone:YES];
    }
}
-(Module *)findModuleWithModule:(Module *)module;
{
    for (Module *md in modules) {
        if ([md.moduleName isEqualToString:module.moduleName] && [md.remoteurl isEqualToString:module.remoteurl]) {
            return md;
        }
    }
    return nil;
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
    if (!data) {
        module.status = ModuleStatusNone;
        return NO;
    }
    NSString *fileName = [[module.remoteurl componentsSeparatedByString:@"/"] lastObject];
    NSString *floderpath = nil;
    NSString *epath = [NSString stringWithFormat:@"%@/%@",[self cachePath],module.moduleName];
    NSString *tpath = [NSString stringWithFormat:@"%@/%@",[self tcachePath],module.moduleName];
    [self createpath:epath];
    [self createpath:tpath];
    if ([needArchiveType containsObject:module.type]) {//解压
        floderpath = tpath;
    }else
    {//直写
        floderpath = epath;
    }
    NSError *error;
    NSString *filefullpath = [NSString stringWithFormat:@"%@/%@",floderpath,fileName];
    BOOL success = [data writeToFile:filefullpath atomically:YES];
    module.status = ModuleStatusNeedArchize;
    if ([needArchiveType containsObject:module.type]) {
        NSString *zipArchivePath = [NSString stringWithFormat:@"%@/%@",floderpath,module.moduleName];
        [self createpath:zipArchivePath];
        [Zip unzipFileAtPath:filefullpath toDestination:zipArchivePath overwrite:YES password:nil error:&error];
        if (error) {//
            module.status = ModuleStatusNone;
            success = NO;
        }else
        {
            if ([fileManager fileExistsAtPath:epath]) {
                [fileManager removeItemAtPath:epath error:&error];
            }
            success = [fileManager moveItemAtPath:zipArchivePath toPath:epath error:&error];
            [fileManager removeItemAtPath:filefullpath error:&error];
            module.status = success?ModuleStatusReady:ModuleStatusNone;
        }
    }else
    {
        if (success) {
            module.status = ModuleStatusReady;
        }else
            module.status = ModuleStatusNone;
    }
    
    Module *tempMoule = [self findModuleWithModuleName:module.moduleName];
    tempMoule.status = module.status;
    @synchronized (self) {
        NSData *archiveCarPriceData = [NSKeyedArchiver archivedDataWithRootObject:modules];
        [[NSUserDefaults standardUserDefaults] setObject:archiveCarPriceData forKey:@"modules"];
        [[NSUserDefaults standardUserDefaults] synchronize];
    }
    [self delModuleInProgress:module];
    NSLog(@"storageModule error %@",error);
    NSThread *thread = threadrunloops[module.moduleName][@"thread"];
    if (thread){
        [self performSelector:@selector(changeloop:) onThread:thread withObject:threadrunloops[module.moduleName] waitUntilDone:YES];
    }
    return success;
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
        BOOL findModule = NO;
        for (Module *md in modules_) {
            if ([name isEqualToString:md.moduleName]) {
                findModule = YES;
                break;
            }
        }
        if (!findModule) {
            [tempArr addObject:name];
        }
    }
    for (NSString *name in tempArr) {
        [fileManager removeItemAtPath:[NSString stringWithFormat:@"%@/%@",[self cachePath],name] error:nil];
    }
}

-(void)createpath:(NSString *)path
{
    if (![fileManager fileExistsAtPath:path]) {
        [fileManager createDirectoryAtPath:path withIntermediateDirectories:YES attributes:nil error:nil];
    }
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
    [self modulesInProcess:module];
    return module.status;
}

-(void)afterModuleInit:(dispatch_block_t)block;
{
    CFRunLoopRef cfRunloop = CFRunLoopGetCurrent();
    CFRunLoopSourceContext context = {0, (__bridge void *)(self), NULL, NULL, NULL, NULL, NULL, NULL, NULL, &RunLoopSourcePerformRoutine};
    CFRunLoopSourceRef source = CFRunLoopSourceCreate(kCFAllocatorDefault, 0, &context);
    CFRunLoopAddSource(cfRunloop, source, kCFRunLoopDefaultMode);
    while (!refreshFlag) {
        @synchronized (threadrunloops) {
            [threadrunloops setObject:@{@"loop":(__bridge id)cfRunloop,@"src":(__bridge id)source,@"thread":[NSThread currentThread]} forKey:@"afterModuleInit"];
        }
        CFRunLoopRun();
    }
    CFRunLoopRemoveSource(CFRunLoopGetCurrent(), source, kCFRunLoopDefaultMode);
    CFRelease(source);
    if (block) {
        block();
    }
}

void RunLoopSourcePerformRoutine (void *info)
{
    
}


-(BOOL)modulesInProcess:(Module *)module
{
    if (!module) return NO;
    CFRunLoopSourceContext context = {0, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL};
    CFRunLoopRef cfRunloop = CFRunLoopGetCurrent();
    CFRunLoopSourceRef source = CFRunLoopSourceCreate(kCFAllocatorDefault, 0, &context);
    CFRunLoopAddSource(cfRunloop, source, kCFRunLoopDefaultMode);
    while (1) {
        BOOL inp = NO;
        if ([self findModuleInProgress:module]) {
            inp = YES;
        }
        if (inp) {
            @synchronized (threadrunloops) {
                [threadrunloops setObject:@{@"loop":(__bridge id)cfRunloop,@"src":(__bridge id)source,@"thread":[NSThread currentThread]} forKey:module.moduleName];
            }
            CFRunLoopRun();
        }else
        {
            break;
        }
    }
    CFRunLoopRemoveSource(cfRunloop, source, kCFRunLoopDefaultMode);
    CFRelease(source);
    return NO;
}

-(void)changeloop:(NSDictionary *)threadrunloops
{
    if (!threadrunloops) return;
    CFRunLoopRef loop = (__bridge CFRunLoopRef)(threadrunloops[@"loop"]);
    if (loop) CFRunLoopStop(loop);
}

-(void)addModuleInProgress:(Module *)module
{
    @synchronized (modulesInProcess) {
        if (![self findModuleInProgress:module])
        {
            module.status = ModuleStatusDowning;
            [modulesInProcess addObject:module];
        }
    }
}

-(BOOL)isProgressRuning;
{
    return modulesInProcess.count!=0?YES:NO;
}

-(void)delModuleInProgress:(Module *)module
{
    @synchronized (modulesInProcess) {
        Module *tmd = [self findModuleInProgress:module];
        if (tmd) [modulesInProcess removeObject:tmd];
    }
}

-(Module *)findModuleInProgress:(Module *)module
{
    for (Module *md in modulesInProcess) {
        if ([module.moduleName isEqualToString:md.moduleName] && [module.remoteurl isEqualToString:md.remoteurl]) {
            return md;
        }
    }
    return nil;
}
@end
