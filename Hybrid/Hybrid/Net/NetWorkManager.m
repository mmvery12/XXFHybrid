//
//  NetWorkManager.m
//  NetWork
//
//  Created by JD on 16/9/20.
//  Copyright © 2016年 YC.L. All rights reserved.
//

#import "NetWorkManager.h"
#import <objc/runtime.h>
@interface NetWorkManager ()<NSURLSessionDelegate>
{
    NSOperationQueue *queue;
    NSOperationQueue *sessionqueue;
    NSMutableDictionary *operDict;
    NSMutableDictionary *tasksCheckTag;
    NSURLSession *session;
}
@end

@implementation NetWorkManager
- (instancetype)init
{
    self = [super init];
    if (self) {
        queue = [[NSOperationQueue alloc] init];
        sessionqueue = [[NSOperationQueue alloc] init];
        operDict = [NSMutableDictionary new];
        tasksCheckTag = [NSMutableDictionary new];
        [self configSession];
    }
    return self;
}

-(void)addTask:(NSString *)urlStr complete:(void (^)(NSData *data,NSError *error))block;
{
    [self addTask:urlStr params:nil complete:block];
}

-(void)addTask:(NSString *)urlStr params:(id)params complete:(void (^)(NSData *data,NSError *error))block;
{
    NSMutableDictionary *tempdict = [operDict objectForKey:urlStr];
    NSMutableArray *temparr = nil;
    if (tempdict && tempdict.count!=0) {
        temparr = [tempdict objectForKey:@"blocks"];
        @synchronized (operDict) {
            [temparr addObject:block];
        }
        return;
    }
    NSMethodSignature  *signature = [self.class instanceMethodSignatureForSelector:@selector(download:params:count:)];
    NSInvocation *inv = [NSInvocation invocationWithMethodSignature:signature];
    [inv setSelector:@selector(download:params:count:)];
    [inv setTarget:self];
    [inv setArgument:&urlStr atIndex:2];
    NSData *data = [params dataUsingEncoding:NSUTF8StringEncoding];
    [inv setArgument:&data atIndex:3];
    int i= 0;
    [inv setArgument:&i atIndex:4];
    
    NSInvocationOperation *inoper = [[NSInvocationOperation alloc] initWithInvocation:inv];
    tempdict = [NSMutableDictionary new];
    temparr = [NSMutableArray new];
    [temparr addObject:block];
    [tempdict setObject:temparr forKeyedSubscript:@"blocks"];
    @synchronized (operDict) {
        [operDict setObject:tempdict forKey:urlStr];
    }
    [queue addOperation:inoper];//改成http1.2 这里用queue太鸡肋了，oper里面是个block，完全不能体现queue的价值
}

-(void)download:(NSString *)url params:(NSData *)data count:(NSInteger)tcount;
{
    __block NSInteger mcount = tcount;
    //尝试3次，3次后返回下载错误
    if (mcount==3) {
        NSArray *tempArr = [NSArray arrayWithArray:[operDict objectForKey:url][@"blocks"]];
        @synchronized (operDict) {
            [operDict removeObjectForKey:url];
        }
        for (void (^block)(NSData *data,NSError *error) in [operDict objectForKey:url][@"blocks"]) {
            block(nil,[NSError errorWithDomain:@"error" code:-100 userInfo:@{NSLocalizedDescriptionKey:@"net error"}]);
        }
        return;
    }
    NSMutableURLRequest *request = [[NSMutableURLRequest alloc] initWithURL:[NSURL URLWithString:url] cachePolicy:NSURLRequestReloadIgnoringCacheData timeoutInterval:5];
    if (data) {
        request.HTTPBody = data;
    }
    request.HTTPMethod = @"POST";
    NSURLResponse *response;
    NSError *error;
    NSThread *thread = [NSThread currentThread];
    [[session dataTaskWithRequest:request completionHandler:^(NSData * _Nullable data, NSURLResponse * _Nullable response, NSError * _Nullable error) {
        if (data && !error) {
            Log(@"[下载任务]下载完成:%@",url);
            NSArray *tempArr = [NSArray arrayWithArray:[operDict objectForKey:url][@"blocks"]];
            @synchronized (operDict) {
                [operDict removeObjectForKey:url];
            }
            for (void (^block)(NSData *data,NSError *error) in tempArr) {
                block(data,nil);
            }
        }else
        {
            Log(@"[下载任务]失败重试:%@",url);
            [self download:url params:data count:++mcount];
        }
    }] resume];
}

-(void)addTasks:(NSArray <NSString *> *)urlStrs moduleComplete:(void (^)(BOOL allcomplete,NSString *url,NSData *data,NSError *error))oneblock;
{
    NSString *tag = [NSString stringWithFormat:@"%lld",[[NSDate date] timeIntervalSince1970]];
    if (![urlStrs isKindOfClass:[NSArray class]] ||
        urlStrs.count==0) {
        oneblock(NO,nil,nil,[NSError errorWithDomain:@"" code:-1009 userInfo:nil]);
    }
    NSMutableArray *temp = [NSMutableArray new];
    for (NSString *url in urlStrs) {
        [temp addObject:url];
    }
    @synchronized (tasksCheckTag) {
        [tasksCheckTag setObject:temp forKey:tag];
    }
    __weak typeof(self) weakSelf = self;
    __weak typeof(tasksCheckTag) weaktasksCheckTag = tasksCheckTag;
    for (NSString *url in temp) {
        [self addTask:url complete:^(NSData *data, NSError *error) {
            @synchronized (weaktasksCheckTag) {
                [[weaktasksCheckTag objectForKey:tag] removeObject:url];
            }
            BOOL allcomplete = NO;
            if ([weakSelf isAllTaskFinishWithTag:tag]) {
                allcomplete = YES;
            }
            if (oneblock)
                oneblock(allcomplete,url,data,error);
        }];
    }
}

-(BOOL)isAllTaskFinishWithTag:(NSString *)tag;
{
    if ([tasksCheckTag[tag] count]!=0) {
        return NO;
    }
    return YES;
}

-(void)configSession
{
    NSURLSessionConfiguration *conf = [NSURLSessionConfiguration defaultSessionConfiguration];
    session = [NSURLSession sessionWithConfiguration:conf delegate:self delegateQueue:sessionqueue];
}

- (void)URLSession:(NSURLSession *)session didReceiveChallenge:(NSURLAuthenticationChallenge *)challenge completionHandler:(void (^)(NSURLSessionAuthChallengeDisposition, NSURLCredential *))completionHandler
{
    NSURLProtectionSpace *protectionSpace = challenge.protectionSpace;
    if ([protectionSpace.authenticationMethod isEqualToString:NSURLAuthenticationMethodServerTrust]) {
        SecTrustRef serverTrust = protectionSpace.serverTrust;
        completionHandler(NSURLSessionAuthChallengeUseCredential, [NSURLCredential credentialForTrust:serverTrust]);
    } else {
        completionHandler(NSURLSessionAuthChallengePerformDefaultHandling, nil);
    }
}

-(void)inthread:(NSData *)data error:(NSError *)error count:(NSInteger)mcount url:(NSString *)url
{
    if (data && !error) {
        NSArray *tempArr = [NSArray arrayWithArray:[operDict objectForKey:url][@"blocks"]];
        @synchronized (operDict) {
            [operDict removeObjectForKey:url];
        }
        for (void (^block)(NSData *data,NSError *error) in tempArr) {
            block(data,nil);
        }
    }else
    {
        [self download:url params:data count:++mcount];
    }
}

@end
