//
//  HyBridManager.m
//  Hybrid
//
//  Created by JD on 16/9/20.
//  Copyright © 2016年 YC.L. All rights reserved.
//
#import <UIKit/UIKit.h>
#import "HyBridManager.h"
#import "NetWorkManager.h"
#import "ModuleManager.h"
#import <objc/message.h>
#import <objc/runtime.h>
#import "Module.h"

static BOOL debugOn = NO;

#define Log( s, ... ) !debugOn?:NSLog( @"%@", [NSString stringWithFormat:(s), ##__VA_ARGS__])

@interface HyBridManager ()
{
    ModuleManager *moduleManager;
    NetWorkManager *netWorkManager;
    NSTimer *timer;
    
    BOOL isrefresh;
}
@end

@implementation HyBridManager

-(void)UIApplicationDidEnterBackgroundNotification
{
    Log(@"UIApplicationDidEnterBackgroundNotification timer end");
    [self timerEnd];
}
-(void)UIApplicationDidBecomeActiveNotification
{
    Log(@"UIApplicationDidBecomeActiveNotification timer begin");
    [self timerBegin];
}

-(void)timerBegin
{
    [self timerEnd];
    timer = [NSTimer timerWithTimeInterval:60*60 target:self selector:@selector(start) userInfo:nil repeats:YES];
    [[NSRunLoop currentRunLoop] addTimer:timer forMode:NSRunLoopCommonModes];
}

-(void)timerEnd
{
    if (timer) {
        [timer invalidate];
        timer = nil;
    }
}

+(instancetype)Manager;
{
    static HyBridManager *share;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        share = [HyBridManager new];
    });
    return share;
}

- (instancetype)init
{
    self = [super init];
    if (self) {
        moduleManager = [ModuleManager new];
        netWorkManager = [NetWorkManager new];
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(UIApplicationDidEnterBackgroundNotification) name:UIApplicationDidEnterBackgroundNotification object:nil];
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(UIApplicationDidBecomeActiveNotification) name:UIApplicationDidBecomeActiveNotification object:nil];
        
    }
    return self;
}

+(void)StartWithLog:(BOOL)log;
{
    debugOn = log;
    [[HyBridManager Manager] start];
}

+(BOOL)HandleWebViewURL:(NSURL *)url CommExcWebView:(id)webview CommExcResult:(void (^)(NSString *jsMethodName,NSString *jsIdentify,id jsParams))reslut
{
    return [[HyBridManager Manager] handleWebViewURL:url CommExcWebView:webview CommExcResult:reslut];
}

+(void)UseResourceWithURI:(NSString *)uri complete:(void (^)(NSData *source, NSError *error))block;
{
    [[HyBridManager Manager] useResourceWithURI:uri complete:block];
}

+(void)UseResourceWithModuleName:(NSString *)name fileName:(NSString *)fileName complete:(void (^)(NSData *source, NSError *error))block;
{
    [[HyBridManager Manager] useResourceWithModuleName:name fileName:fileName complete:block];
}

-(void)start
{
    if (![moduleManager isProgressRuning] && !isrefresh) {
        [self remoteChecking];//远程下发服务
    }
}

-(void)remoteChecking
{
    __weak typeof(self) weakSelf = self;
    __block wrRefresh = isrefresh;
    @synchronized (self) {
        wrRefresh = YES;
    }
    Log(@"remoteChecking begin");
    [netWorkManager addTask:@"http://www.baidu.com" params:nil complete:^(NSData *data, NSError *error) {
        Log(@"remoteChecking end");
        if (!error) {
            data = [NSData dataWithContentsOfFile:[[NSBundle mainBundle] pathForResource:@"Config" ofType:@"json"]];
            [weakSelf analyzeRemoteConfig:[NSJSONSerialization JSONObjectWithData:data options:0 error:nil]];
        }else
        {
            [weakSelf analyzeRemoteConfig:nil];
        }
        @synchronized (self) {
            wrRefresh = NO;
        }
    }];
}


-(void)analyzeRemoteConfig:(NSDictionary *)remoteConfigDict
{
    __weak typeof(moduleManager) weakModuleManager = moduleManager;
    __weak typeof(netWorkManager) weakNetManager = netWorkManager;
    __weak typeof(self) weakSelf = self;
    //版本分析策略不上传本地资源由native自行判断,服务器下发统一的最新资源配置
    Log(@"analyzeModules begin");
    [moduleManager analyzeModules:[weakModuleManager modulesFromeDictionary:remoteConfigDict] result:^(NSArray<Module *> *modules) {
        Log(@"analyzeModules end");
        //    modules =  [self sortModulesSequence:modules];//    计算各个模块权重
        [weakSelf hookWithModules:modules result:^{
            Log(@"all allcomplete analyzeRemoteConfig");
        }];
    }];
}

-(BOOL)handleWebViewURL:(NSURL *)url_ CommExcWebView:(id)webview CommExcResult:(void (^)(NSString *jsMethodName,NSString *jsIdentify,id jsParams))reslut;
{
    NSString *scheme = url_.scheme;
    NSString *host = url_.host;
    NSString *params = url_.query;
    if ([scheme isEqualToString:keyUrlScheme] &&
        [host isEqualToString:keyUrlHost] &&
        [params hasPrefix:keyUrlParams]) {
        NSError *error;
        NSString *str = [url_.absoluteString stringByReplacingPercentEscapesUsingEncoding:NSUTF8StringEncoding];
        NSDictionary *dict = [NSJSONSerialization JSONObjectWithData:[[[str componentsSeparatedByString:[NSString stringWithFormat:@"%@=",keyUrlParams]] lastObject] dataUsingEncoding:NSUTF8StringEncoding] options:0 error:&error];
        
        Class cls = NSClassFromString(@"Comm");
        NSAssert(cls, @"[ERROR] Class 'Comm' not found in project!");
        SEL sel = NSSelectorFromString([NSString stringWithFormat:@"com%@:p2:p3:p4:p5:",dict[keyCommServiceName]]);
        id params = dict[keyCommParams];
        id cbsel = dict[keyCommJsCallBackMethodName];
        id identify = dict[keyCommJsCallBackIdentify];
        
        NSMethodSignature *sig = [cls methodSignatureForSelector:sel];
        NSInvocation *inv = [NSInvocation invocationWithMethodSignature:sig];
        [inv setSelector:sel];
        [inv setTarget:cls];
        [inv setArgument:&params atIndex:2];
        [inv setArgument:&cbsel atIndex:3];
        [inv setArgument:&identify atIndex:4];
        [inv setArgument:&webview atIndex:5];
        [inv setArgument:&reslut atIndex:6];
        [inv invoke];
        return NO;
    }
    return YES;
}

-(void)useResourceWithURI:(NSString *)uri complete:(void (^)(NSData *source, NSError *error))block;
{
    __weak typeof(moduleManager) weakmoduleManager = moduleManager;
    dispatch_async(dispatch_get_global_queue(0, 0), ^{
        [weakmoduleManager afterModuleInit:^{
            NSData *data = [weakmoduleManager findSourceAtRelativePath:uri];
            if (data) {
                dispatch_async(dispatch_get_main_queue(), ^{
                        block(data,nil);
                });
            }else
            {
                dispatch_async(dispatch_get_main_queue(), ^{
                    block(nil,[NSError errorWithDomain:@"NSERROR_SOURCENOTFOUND_DOMAIN" code:-100 userInfo:@{NSLocalizedDescriptionKey:[NSString stringWithFormat:@"URI:%@ ; not found",uri]}]);
                });
            }
        }];
    });
    
}

-(void)useResourceWithModuleName:(NSString *)name fileName:(NSString *)fileName complete:(void (^)(NSData *source, NSError *error))block;
{
    __weak typeof(moduleManager) weakmoduleManager = moduleManager;
    __weak typeof(self) weakSelf = self;
    dispatch_async(dispatch_get_global_queue(0, 0), ^{
        Log(@"afterModuleInit begin");
        [weakmoduleManager afterModuleInit:^{
            Log(@"afterModuleInit end");
            Module *md = [weakmoduleManager findModuleWithModuleName:name];
            if (!md) {
                dispatch_async(dispatch_get_main_queue(), ^{
                    block(nil,[NSError errorWithDomain:@"NSERROR_MODULENOTFOUND_DOMAIN" code:-100 userInfo:@{NSLocalizedDescriptionKey:[NSString stringWithFormat:@"MODULE:%@ ; not found",name]}]);
                });
            }
            [weakSelf rescurseDepend:md fileName:fileName complete:block];
        }];
    });
}

-(void)rescurseDepend:(Module *)md fileName:(NSString *)fileName complete:(void (^)(NSData *source, NSError *error))block;
{
    __weak typeof(self) weakSelf = self;
    __weak typeof(moduleManager) weakModuleManager = moduleManager;
    NSMutableArray *arrary = [NSMutableArray new];
    [self rescurseDepend:md arr:arrary];
    [self hookWithModules:arrary result:^{
        dispatch_async(dispatch_get_main_queue(), ^{
            NSData *tdata = [weakModuleManager findDataWithModuleName:md.moduleName fileName:fileName];
            Log(@"useResourceWithXX data output status %d",tdata?1:0);
            if (tdata) {
                block(tdata,nil);
            }else
                block(nil,[NSError errorWithDomain:@"NSERROR_MODULENOTFOUND_DOMAIN" code:-100 userInfo:@{NSLocalizedDescriptionKey:[NSString stringWithFormat:@"MODULE:%@ FILE SOURCE:%@ ; not found",md.moduleName,fileName]}]);
        });
    }];
}

-(void)rescurseDepend:(Module *)md arr:(NSMutableArray *)arr;
{
    if (![arr containsObject:md]) {
        [arr addObject:md];
    }
    for (NSString *mmdst in md.depend) {
        Module *mmd = [moduleManager findModuleWithModuleName:mmdst];
        if (![arr containsObject:mmd]) {
            [arr addObject:mmd];
            [self rescurseDepend:mmd arr:arr];
        }
    }
}


-(NSArray *)sortModulesSequence:(NSArray *)modules
{//计算各个模块权重
    
    NSMutableArray *tempArr = [NSMutableArray new];
    for (Module *module in modules) {
        [tempArr addObject:@{module.remoteurl:@1}];
    }
    
    for (Module *module in modules) {
        for (Module *dep in module.depend) {
            if ([dep.moduleName isEqualToString:module.moduleName]) {
                int i=0;
                for (NSDictionary *dict in tempArr) {
                    if ([[dict allKeys][0] isEqualToString:dep.remoteurl]) {
                        int num = [dict[[dict allKeys][0]] integerValue];
                        num++;
                        [tempArr replaceObjectAtIndex:i withObject:@{dep.remoteurl:@(num)}];
                    }
                    i++;
                }
            }
        }
    }
    tempArr = [NSMutableArray arrayWithArray:[tempArr sortedArrayUsingComparator:^NSComparisonResult(id  _Nonnull obj1, id  _Nonnull obj2) {
        NSDictionary *dict1 = obj1;
        NSDictionary *dict2 = obj2;
        NSNumber *key1 = [dict1 allKeys][0];
        NSNumber *key2 = [dict2 allKeys][0];
        if ([key1 integerValue]>[key2 integerValue]) {
            return NSOrderedAscending;
        }
        if ([key1 integerValue]==[key2 integerValue]) {
            return NSOrderedSame;
        }
        return NSOrderedDescending;
    }]];
    
    for (int i = 0; i<tempArr.count; i++) {
        NSDictionary *temp = tempArr[i];
        [tempArr replaceObjectAtIndex:i withObject:[temp objectForKey:[temp allKeys][0]]];
    }
    return tempArr;
}

/************
 如果module需要开启在workflow中，则开启下载workflow下载，
 module在 moduleManager isModuleReady：方法中会询问是否需要等待，等待的话就表示此module在workflow中
 网络请求即开启workflow，将moduel加入到相应的监视队列，写文件结束workflow结束，将module从监视队列移除，并通知moduleManager isModuleReady：方法，继续执行
 ************/
-(void)hookWithModules:(NSArray <Module *> *)modules_ result:(void (^)(void))resultblock
{
    Log(@"###########################################");
    Log(@"hookWithModules begin analyse moduels");
    __weak typeof(moduleManager) weakModuleManager = moduleManager;
    __weak typeof(netWorkManager) weakNetManager = netWorkManager;
    NSMutableArray *array = [NSMutableArray new];
    for (Module *md in modules_) {
        Module *tmd = nil;
        tmd = [moduleManager findModuleWithModule:md];
        if ([moduleManager isModuleReady:tmd]==ModuleStatusNone) {
            if ([tmd.remoteurl isKindOfClass:[NSString class]] && tmd.remoteurl.length!=0) {
                [moduleManager addModuleInProgress:tmd];
                [array addObject:tmd.remoteurl];
            }
        }
        tmd = nil;
    }
    if (array.count==0) {
        array = nil;
        Log(@"hookWithModules moduels are all ready");
        Log(@"hookWithModules moduels end analyse moduels");
        Log(@"===========================================");
        resultblock();
        return;
    }
    Log(@"hookWithModules will down load %@",array);
    [netWorkManager addTasks:array moduleComplete:^(NSString *url, NSData *data, NSError *error) {
        Module *module = [weakModuleManager findModuleWithRemoteUrl:url];
        Log(@"---->storageModule %@ %@",module.type,module.remoteurl);
        [weakModuleManager storageModule:module data:data];
    } allcomplete:resultblock];
}

@end
