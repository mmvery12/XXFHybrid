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

-(void)UIApplicationWillEnterForegroundNotification
{
    [self start];
}

-(void)timerBegin
{
    if (timer) {
        [timer invalidate];
        timer = nil;
    }
    timer = [NSTimer timerWithTimeInterval:60*60 target:self selector:@selector(remoteChecking) userInfo:nil repeats:YES];
    [[NSRunLoop currentRunLoop] addTimer:timer forMode:NSRunLoopCommonModes];
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
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(UIApplicationDidEnterBackgroundNotification) name:UIApplicationWillEnterForegroundNotification object:nil];
    }
    return self;
}

+(void)Start;
{
    [[HyBridManager Manager] start];
}

+(BOOL)HandleWebViewURL:(NSURL *)url CommExcResult:(void (^)(id commresult))block;
{
    return [[HyBridManager Manager] handleWebViewURL:url CommExcResult:block];
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
    if ([netWorkManager isAllTaskFinishWithTag:@"mainDownLoad"]) {
        [moduleManager selfAnalyze];//modules本地自检
        [self remoteChecking];//远程下发服务
    }
}

-(void)remoteChecking
{
    __weak typeof(self) weakSelf = self;
    [netWorkManager addTask:@"http://www.baidu.com" params:nil complete:^(NSData *data, NSError *error) {
        if (data) {
            [weakSelf analyzeRemoteConfig:[NSJSONSerialization JSONObjectWithData:data options:0 error:nil]];
        }
    }];
}


-(void)analyzeRemoteConfig:(NSDictionary *)remoteConfigDict
{
    __weak typeof(moduleManager) weakModuleManager = moduleManager;
    //不上传本地资源由native自行判断,服务器下发统一的最新资源配置
    NSArray <Module *>*modules = [moduleManager analyzeModules:[self modulesFromeDictionary:remoteConfigDict]];
    //计算各个模块权重
//    NSMutableArray *tempArr = [NSMutableArray new];
//    for (Module *module in modules) {
//        [tempArr addObject:@{module.remoteurl:@1}];
//    }
//    
//    for (Module *module in modules) {
//        for (Module *dep in module.depend) {
//            if ([dep.moduleName isEqualToString:module.moduleName]) {
//                int i=0;
//                for (NSDictionary *dict in tempArr) {
//                    if ([[dict allKeys][0] isEqualToString:dep.remoteurl]) {
//                        int num = [dict[[dict allKeys][0]] integerValue];
//                        num++;
//                        [tempArr replaceObjectAtIndex:i withObject:@{dep.remoteurl:@(num)}];
//                    }
//                    i++;
//                }
//            }
//        }
//    }
//    
//    tempArr = [NSMutableArray arrayWithArray:[tempArr sortedArrayUsingComparator:^NSComparisonResult(id  _Nonnull obj1, id  _Nonnull obj2) {
//        NSDictionary *dict1 = obj1;
//        NSDictionary *dict2 = obj2;
//        NSNumber *key1 = [dict1 allKeys][0];
//        NSNumber *key2 = [dict2 allKeys][0];
//        if ([key1 integerValue]>[key2 integerValue]) {
//            return NSOrderedAscending;
//        }
//        if ([key1 integerValue]==[key2 integerValue]) {
//            return NSOrderedSame;
//        }
//        return NSOrderedDescending;
//    }]];
//    
//    for (int i = 0; i<tempArr.count; i++) {
//        NSDictionary *temp = tempArr[i];
//        [tempArr replaceObjectAtIndex:i withObject:[temp objectForKey:[temp allKeys][0]]];
//    }
    NSMutableArray *temp = [NSMutableArray array];
    for (Module *module in modules) {
        [temp addObject:module.remoteurl];
    }
    [netWorkManager addTasks:temp tag:@"mainDownLoad" moduleComplete:^(NSString *url,NSData *data, NSError *error) {
        if (!error) {
            for (Module *module in modules) {
                if ([url isEqualToString:module.remoteurl]) {
                    [weakModuleManager zipArchiveModule:module data:data];
                }
            }
        }
    } allcomplete:^{
        //开启下一次轮训
    }];
}

-(BOOL)handleWebViewURL:(NSURL *)url CommExcResult:(void (^)(id commresult))block;
{
    NSString *scheme = url.scheme;
    NSString *host = url.host;
    NSString *params = url.query;
    if ([scheme isEqualToString:urlSchemeStr] &&
        [host isEqualToString:urlHostStr] &&
        [params hasPrefix:urlParamsStr]) {
        NSError *error;
        NSDictionary *dict = [NSJSONSerialization JSONObjectWithData:[[[params componentsSeparatedByString:urlParamsStr] lastObject] dataUsingEncoding:NSUTF8StringEncoding] options:0 error:&error];
        
        
        return NO;
    }
    return YES;
}

-(void)useResourceWithURI:(NSString *)uri complete:(void (^)(NSData *source, NSError *error))block;
{
    NSData *data = [moduleManager findSourceAtRelativePath:uri];
    if (data) {
        block(data,nil);
    }else
    {
        block(nil,[NSError errorWithDomain:@"NSERROR_SOURCENOTFOUND_DOMAIN" code:-100 userInfo:@{NSLocalizedDescriptionKey:[NSString stringWithFormat:@"URI:%@ ; not found",uri]}]);
    }
}

-(void)useResourceWithModuleName:(NSString *)name fileName:(NSString *)fileName complete:(void (^)(NSData *source, NSError *error))block;
{
    Module *md = [moduleManager findModuleWithModuleName:name];
    if (!md) {
        block(nil,[NSError errorWithDomain:@"NSERROR_MODULENOTFOUND_DOMAIN" code:-100 userInfo:@{NSLocalizedDescriptionKey:[NSString stringWithFormat:@"MODULE:%@ ; not found",name]}]);
    }
    [self rescurseDepend:md fileName:fileName complete:block];
}

-(void)rescurseDepend:(Module *)md fileName:(NSString *)fileName complete:(void (^)(NSData *source, NSError *error))block;
{
    __weak typeof(self) weakSelf = self;
     __weak typeof(moduleManager) weakModuleManager = moduleManager;
    NSMutableArray *arrary = [NSMutableArray new];
    [self rescurseDepend:md arr:arrary];
    __block BOOL ready = YES;
    NSMutableArray *urls = [NSMutableArray new];
    for (Module *module in arrary) {
        if (![moduleManager isModuleReady:module]) {
            [urls addObject:module.remoteurl];
            ready = NO;
        }
    }
    if (ready) {
        block([moduleManager findDataWithModuleName:md.moduleName fileName:fileName inDirectory:nil],nil);
    }else
    {
        [netWorkManager addTasks:urls tag:@"max" moduleComplete:^(NSString *url, NSData *data, NSError *error) {
            
            NSLog(@"123");
            NSLog(@"123");
        } allcomplete:^{
            ready = YES;
            for (Module *module in arrary) {
                if (![weakModuleManager isModuleReady:module]) {
                    ready = NO;
                }
            }
            if (ready) {
                NSData *tdata = [weakModuleManager findDataWithModuleName:md.moduleName fileName:fileName inDirectory:nil];
                if (tdata) {
                    block(tdata,nil);
                }else
                    block(nil,[NSError errorWithDomain:@"NSERROR_MODULENOTFOUND_DOMAIN" code:-100 userInfo:@{NSLocalizedDescriptionKey:[NSString stringWithFormat:@"MODULE:%@ FILE SOURCE:%@ ; not found",md.moduleName,fileName]}]);
            }else
                block(nil,[NSError errorWithDomain:@"NSERROR_MODULENOTFOUND_DOMAIN" code:-100 userInfo:@{NSLocalizedDescriptionKey:[NSString stringWithFormat:@"MODULE:%@ FILE SOURCE:%@ ; not found",md.moduleName,fileName]}]);
            
        }];
    }
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

-(NSArray <Module *>*)modulesFromeDictionary:(NSDictionary *)dict
{
    NSMutableArray *arr = [NSMutableArray new];
    for (NSDictionary *tdict in dict[@"modules"]) {
        Module *module = [Module new];
        module.identify = tdict[@"identify"];
        module.moduleName = tdict[@"moduleName"];
        module.remoteurl = tdict[@"remoteurl"];
        module.version = tdict[@"version"];
        module.depend = tdict[@"depend"];
        [arr addObject:module];
    }
    return arr;
}

-(NSArray *)JsCssNeedUpdate:(NSString *)html
{
    return nil;
}
@end
