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
@interface HyBridManager ()
{
    ModuleManager *moduleManager;
    NetWorkManager *netWorkManager;
    NSTimer *timer;
}
@end

@implementation HyBridManager
-(void)UIApplicationDidEnterBackgroundNotification
{
    [self timerEnd];
}
-(void)UIApplicationWillEnterForegroundNotification
{
    [self timerBegin];
}

-(void)UIApplicationDidFinishLaunchingNotification
{
    [self timerBegin];
}

-(void)timerBegin
{
    [self timerEnd];
    timer = [NSTimer timerWithTimeInterval:10 target:self selector:@selector(start) userInfo:nil repeats:YES];
    [[NSRunLoop currentRunLoop] addTimer:timer forMode:NSRunLoopCommonModes];
}

-(void)timerEnd
{
    if (timer) {
        [timer invalidate];
        timer = nil;
    }
}

+(void)load
{
    
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
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(UIApplicationWillEnterForegroundNotification) name:UIApplicationWillEnterForegroundNotification object:nil];
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(UIApplicationDidEnterBackgroundNotification) name:UIApplicationDidEnterBackgroundNotification object:nil];
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(UIApplicationDidFinishLaunchingNotification) name:UIApplicationDidFinishLaunchingNotification object:nil];
        
    }
    return self;
}

+(void)Start;
{
    [[HyBridManager Manager] start];
}

+(BOOL)HandleWebViewURL:(NSURL *)url CommExcWebView:(id)webview
{
    return [[HyBridManager Manager] handleWebViewURL:url CommExcWebView:webview];
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
    NSLog(@"will start");
    if (![moduleManager isProgressRuning]) {
        NSLog(@"did start");
        [self remoteChecking];//远程下发服务
    }
}

-(void)remoteChecking
{
    __weak typeof(self) weakSelf = self;
    [netWorkManager addTask:@"http://www.baidu.com" params:nil complete:^(NSData *data, NSError *error) {
        if (!error) {
            data = [NSData dataWithContentsOfFile:[[NSBundle mainBundle] pathForResource:@"Config" ofType:@"json"]];
            [weakSelf analyzeRemoteConfig:[NSJSONSerialization JSONObjectWithData:data options:0 error:nil]];
        }else
        {
            [weakSelf analyzeRemoteConfig:nil];
        }
    }];
}


-(void)analyzeRemoteConfig:(NSDictionary *)remoteConfigDict
{
    __weak typeof(moduleManager) weakModuleManager = moduleManager;
    __weak typeof(netWorkManager) weakNetManager = netWorkManager;
    __weak typeof(self) weakSelf = self;
    //版本分析策略不上传本地资源由native自行判断,服务器下发统一的最新资源配置
    [moduleManager analyzeModules:[weakModuleManager modulesFromeDictionary:remoteConfigDict] result:^(NSArray<Module *> *modules) {
        //    modules =  [self sortModulesSequence:modules];//    计算各个模块权重
        [weakSelf hookWithModules:modules result:^{
            NSLog(@"all allcomplete analyzeRemoteConfig");
        }];
    }];
}

-(BOOL)handleWebViewURL:(NSURL *)url_ CommExcWebView:(id)webview;
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
        SEL sel = NSSelectorFromString([NSString stringWithFormat:@"com%@:p2:p3:p4:",dict[keyCommServiceName]]);
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
        [weakmoduleManager afterModuleInit:^{
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
            NSLog(@"customer rescurseDepend off %d",tdata?1:0);
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
    NSLog(@"hookWithModules");
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
        resultblock();
        return;
    }
    [netWorkManager addTasks:array moduleComplete:^(NSString *url, NSData *data, NSError *error) {
        Module *module = [weakModuleManager findModuleWithRemoteUrl:url];
        NSLog(@"storageModule %@ %@",module.type,module.remoteurl);
        [weakModuleManager storageModule:module data:data];
    } allcomplete:resultblock];
}

@end
