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
}
@property (atomic,assign)NSMutableArray *modules;
@property (atomic,assign)BOOL refreshFlag;
@property (atomic,strong)NSMutableArray *modulesInProcess;
@property (atomic,strong)NSMutableDictionary *threadrunloops;
@end

@implementation ModuleManager
@synthesize modules = modules;
- (instancetype)init
{
    self = [super init];
    if (self) {
        self.modules = [NSMutableArray new];
        fileManager = [NSFileManager defaultManager];
        needArchiveType = [NSSet setWithObjects:@"zip",@"rar", nil];
        self.modulesInProcess = [NSMutableArray new];
        self.threadrunloops = [NSMutableDictionary new];
    }
    return self;
}

-(void)selfAnalyze;
{
    @synchronized (self.modules) {
        NSData *myEncodedObject = [[NSUserDefaults standardUserDefaults] objectForKey:@"modules"];
        self.modules = [NSKeyedUnarchiver unarchiveObjectWithData: myEncodedObject];
        if (!self.modules) {
            self.modules = [NSMutableArray new];
        }
        [self deleteContentsWithOutModules:self.modules];//配置文件中没有的统统删掉
    }
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

-(NSArray *)getUseModules
{
    return self.modules;
}

-(void)analyzeModules:(NSArray <Module *> *)modules_ result:(void (^)(NSArray <Module *> *))resultblock;
{
    self.refreshFlag = NO;
    NSMutableArray *needUpdate = [NSMutableArray new];
    NSThread *thread;
    thread = self.threadrunloops[@"afterModuleInit"][@"thread"];
    @synchronized (self.modules) {
        if (!modules_ || modules_.count==0) {
            
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
            [self.modules removeObjectsInArray:normal];
            [self.modules removeObjectsInArray:needUpdate];
            for (Module *md in self.modules) {
                [self deleteModule:md];
            }
            [self.modules removeAllObjects];
            [self.modules addObjectsFromArray:normal];
            [self.modules addObjectsFromArray:needUpdate];
            {
                NSData *archiveCarPriceData = [NSKeyedArchiver archivedDataWithRootObject:modules];
                [[NSUserDefaults standardUserDefaults] setObject:archiveCarPriceData forKey:@"modules"];
                [[NSUserDefaults standardUserDefaults] synchronize];
            }
            
        }
    }
    resultblock(needUpdate);
    self.refreshFlag = YES;
    if (thread){
        [self performSelector:@selector(changeloop:) onThread:thread withObject:self.threadrunloops[@"afterModuleInit"] waitUntilDone:YES];
    }
}

-(Module *)findModuleWithModuleName:(NSString *)moduleName
{
    for (Module *md in self.modules) {
        if ([md.moduleName isEqualToString:moduleName]) {
            return md;
        }
    }
    return nil;
}

-(Module *)findModuleWithRemoteUrl:(NSString *)remoteurl;
{
    for (Module *md in self.modules) {
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
    [self.modulesInProcess addObject:module];
    NSString *fileName = [[module.remoteurl componentsSeparatedByString:@"/"] lastObject];
    NSString *floderpath = nil;
    NSString *epath = [NSString stringWithFormat:@"%@/%@",[self cachePath],module.moduleName];
    NSString *tpath = [NSString stringWithFormat:@"%@/%@",[self tcachePath],module.moduleName];
    [self createpath:epath];
    [self createpath:tpath];
    if ([needArchiveType containsObject:module.type]) {//解压
        module.status = ModuleStatusNeedArchize;
        floderpath = tpath;
    }else
    {//直写
        floderpath = epath;
    }
    NSString *filefullpath = [NSString stringWithFormat:@"%@/%@",floderpath,fileName];
    BOOL success = [data writeToFile:filefullpath atomically:YES];
//    [NSThread sleepForTimeInterval:10];
    if ([needArchiveType containsObject:module.type]) {
        NSError *error;
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
    [self.modulesInProcess removeObject:module];
    Module *tempMoule = [self findModuleWithModuleName:module.moduleName];
    tempMoule.status = module.status;
    @synchronized (self) {
        NSData *archiveCarPriceData = [NSKeyedArchiver archivedDataWithRootObject:modules];
        [[NSUserDefaults standardUserDefaults] setObject:archiveCarPriceData forKey:@"modules"];
        [[NSUserDefaults standardUserDefaults] synchronize];
    }
    NSThread *thread = self.threadrunloops[module.moduleName][@"thread"];
    if (thread){
        [self performSelector:@selector(changeloop:) onThread:thread withObject:self.threadrunloops[module.moduleName] waitUntilDone:YES];
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
    while (!_refreshFlag) {
        [self.threadrunloops setObject:@{@"loop":(__bridge id)cfRunloop,@"src":(__bridge id)source,@"thread":[NSThread currentThread]} forKey:@"afterModuleInit"];
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

    static dispatch_once_t onceToken;
    CFRunLoopSourceContext context = {0, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL};
    CFRunLoopRef cfRunloop = CFRunLoopGetCurrent();
    CFRunLoopSourceRef source = CFRunLoopSourceCreate(kCFAllocatorDefault, 0, &context);
    CFRunLoopAddSource(cfRunloop, source, kCFRunLoopDefaultMode);
    while (1) {
        BOOL inp = NO;
        for (Module *md in self.modulesInProcess) {
            if ([md.remoteurl isEqualToString:module.remoteurl] && [md.moduleName isEqualToString:module.moduleName]) {
                inp = YES;
                break;
            }
        }
        if (inp) {
            [self.threadrunloops setObject:@{@"loop":(__bridge id)cfRunloop,@"src":(__bridge id)source,@"thread":[NSThread currentThread]} forKey:module.moduleName];
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
@end
