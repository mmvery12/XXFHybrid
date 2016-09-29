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
    BOOL refreshFlag;
}
@property (nonatomic,strong)NSMutableDictionary *threadrunloops;
@end

@implementation ModuleManager
@synthesize threadrunloops = threadrunloops;
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
    myEncodedObject = nil;
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
    @synchronized (self) {
        refreshFlag = NO;
    }
    NSMutableArray *needUpdate = [NSMutableArray new];
    NSMutableArray *needArchive = [NSMutableArray new];
    @synchronized (modules) {
        if ([modules_ isKindOfClass:[NSArray class]] && modules_.count!=0) {
            NSMutableArray *normal = [NSMutableArray new];
            {
                for (Module *md in modules_) {
                    Module *mmd = [self findModuleWithModuleName:md.moduleName];
                    if (mmd &&
                        [md.version isEqualToString:mmd.version] &&
                        ([self isModuleReady:mmd]==ModuleStatusReady ||
                        [self isModuleReady:mmd]==ModuleStatusNeedArchize)) {
                            if ([self isModuleReady:mmd]==ModuleStatusReady) {
                                [normal addObject:mmd];
                            }
                            if ([self isModuleReady:mmd]==ModuleStatusNeedArchize) {
                                [needArchive addObject:mmd];
                            }
                    }else
                        [needUpdate addObject:md];
                }
            }
            [modules removeObjectsInArray:normal];
            [modules removeObjectsInArray:needUpdate];
            [modules removeObjectsInArray:needArchive];
            for (Module *md in modules) {
                [self deleteModule:md];
            }
            [modules removeAllObjects];
            [modules addObjectsFromArray:normal];
            [modules addObjectsFromArray:needUpdate];
            [modules addObjectsFromArray:needArchive];
            for (Module *md in needArchive) {
                [self addModuleInProgress:md];
            }
            for (Module *md in needArchive) {
                NSString *fileName = [[md.remoteurl componentsSeparatedByString:@"/"] lastObject];
                NSString *tpath = [NSString stringWithFormat:@"%@/%@",[self tcachePath],md.moduleName];
                NSString *filefullpath = [NSString stringWithFormat:@"%@/%@",tpath,fileName];
                [self storageModule:md data:[NSData dataWithContentsOfFile:filefullpath]];
            }
            {
                @synchronized (self) {
                    NSData *archiveCarPriceData = [NSKeyedArchiver archivedDataWithRootObject:modules];
                    [[NSUserDefaults standardUserDefaults] setObject:archiveCarPriceData forKey:@"modules"];
                    [[NSUserDefaults standardUserDefaults] synchronize];
                    archiveCarPriceData = nil;
                }
            }
        }
    
        for (Module *md in needUpdate) {
            md.status = ModuleStatusNone;
        }
    }
    resultblock(needUpdate);
    @synchronized (self) {
        refreshFlag = YES;
    }
    [self changeloop:threadrunloops[@"afterModuleInit"]];
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
    BOOL success = NO;
    if (!data || !module) {
        if (module) module.status = ModuleStatusNone;
    }else
    {
        NSString *fileName = [[module.remoteurl componentsSeparatedByString:@"/"] lastObject];
        NSString *epath = [NSString stringWithFormat:@"%@/%@",[self cachePath],module.moduleName];
        NSString *tpath = [NSString stringWithFormat:@"%@/%@",[self tcachePath],module.moduleName];
        [self createpath:epath];
        [self createpath:tpath];
        NSError *error;
        NSString *filefullpath = [NSString stringWithFormat:@"%@/%@",tpath,fileName];
        BOOL success = [data writeToFile:filefullpath atomically:YES];
        if (success) {
            module.status = ModuleStatusNeedArchize;
            if ([needArchiveType containsObject:module.type]) {//zip解压
                NSString *fileSotrePath = [NSString stringWithFormat:@"%@/%@",tpath,module.moduleName];
                if ([fileManager fileExistsAtPath:fileSotrePath]) {
                    [fileManager removeItemAtPath:fileSotrePath error:&error];
                }
                [self createpath:fileSotrePath];
                [Zip unzipFileAtPath:filefullpath toDestination:fileSotrePath overwrite:YES password:nil error:&error];
                if (error) {//
                    module.status = ModuleStatusNone;
                    success = NO;
                }else
                {
                    if ([fileManager fileExistsAtPath:epath]) {
                        [fileManager removeItemAtPath:epath error:&error];
                    }
                    success = [fileManager moveItemAtPath:fileSotrePath toPath:epath error:&error];
                    module.status = success?ModuleStatusReady:ModuleStatusNone;
                }
            }else
            {//普通data写入
                if ([fileManager fileExistsAtPath:epath]) {
                    [fileManager removeItemAtPath:epath error:&error];
                }
                success = [fileManager moveItemAtPath:tpath toPath:epath error:&error];
                module.status = ModuleStatusReady;
            }
            [fileManager removeItemAtPath:filefullpath error:&error];//移掉缓存文件
        }else
        {
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
    }
    [self changeloop:threadrunloops[module.moduleName]];
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

-(ModuleStatus)isModuleReady:(Module *)module;
{
    [self modulesInProcess:module];
    return module.status;
}

-(void)afterModuleInit:(dispatch_block_t)block;
{
    CFRunLoopRef cfRunloop = CFRunLoopGetCurrent();
    CFRunLoopSourceContext context = {0, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL};
    CFRunLoopSourceRef source = CFRunLoopSourceCreate(kCFAllocatorDefault, 0, &context);
    CFRunLoopAddSource(cfRunloop, source, kCFRunLoopCommonModes);
    {
        NSArray *temp = threadrunloops[@"afterModuleInit"];
        NSMutableArray *array;
        if (temp) {
            array = [[NSMutableArray alloc] initWithArray:temp];
        }else
            array = [NSMutableArray new];
        [array addObject:@{@"loop":(__bridge id)cfRunloop,@"src":(__bridge id)source}];
        @synchronized (threadrunloops) {
            [threadrunloops setObject:array forKey:@"afterModuleInit"];
        }
        while (!refreshFlag) {
            CFRunLoopRun;
        }
        @synchronized (threadrunloops) {
            [threadrunloops removeObjectForKey:@"afterModuleInit"];
        }
    }
    CFRunLoopRemoveSource(CFRunLoopGetCurrent(), source, kCFRunLoopCommonModes);
    CFRelease(source);
    if (block) block();
}


-(BOOL)modulesInProcess:(Module *)module
{
    if (!module) return NO;
    CFRunLoopRef cfRunloop = CFRunLoopGetCurrent();
    CFRunLoopSourceContext context = {0, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL};
    CFRunLoopSourceRef source = CFRunLoopSourceCreate(kCFAllocatorDefault, 0, &context);
    CFRunLoopAddSource(cfRunloop, source, kCFRunLoopCommonModes);

    while (1) {
        BOOL inp = NO;
        if ([self findModuleInProgress:module]) {
            inp = YES;
        }
        NSArray *temp = threadrunloops[module.moduleName];
        NSMutableArray *array;
        if (temp) {
            array = [[NSMutableArray alloc] initWithArray:temp];
        }else
            array = [NSMutableArray new];
        [array addObject:@{@"loop":(__bridge id)cfRunloop,@"src":(__bridge id)source}];
        @synchronized (threadrunloops) {
            [threadrunloops setObject:array forKey:module.moduleName];
        }
        if (inp) {
            CFRunLoopRun();
        }else
            break;
    }
    @synchronized (threadrunloops) {
        [threadrunloops removeObjectForKey:module.moduleName];
    }
    CFRunLoopRemoveSource(cfRunloop, source, kCFRunLoopCommonModes);
    CFRelease(source);
    return NO;
}



-(void)changeloop:(NSDictionary *)threadrunloops
{
    if (!threadrunloops) return;
    for (NSDictionary *dict in threadrunloops) {
        CFRunLoopRef loop = (__bridge CFRunLoopRef)(dict[@"loop"]);
        if (loop) CFRunLoopStop(loop);
    }
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
