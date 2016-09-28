//
//  NetWorkManager.m
//  NetWork
//
//  Created by JD on 16/9/20.
//  Copyright © 2016年 YC.L. All rights reserved.
//

#import "NetWorkManager.h"
#import <objc/runtime.h>
@interface NetWorkManager ()
{
    NSOperationQueue *queue;
    NSMutableDictionary *operDict;
    NSMutableDictionary *tasksCheckTag;
}
@end

@implementation NetWorkManager
- (instancetype)init
{
    self = [super init];
    if (self) {
        queue = [[NSOperationQueue alloc] init];
        operDict = [NSMutableDictionary new];
        tasksCheckTag = [NSMutableDictionary new];
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
    [queue addOperation:inoper];
    
}

-(void)download:(NSString *)url params:(NSData *)data count:(NSInteger)count;
{
    //尝试3次，3次后返回下载错误
    if (count==3) {
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
    NSData *receivedata = [NSURLConnection sendSynchronousRequest:request returningResponse:&response error:&error];
    if (receivedata && !error) {
        NSArray *tempArr = [NSArray arrayWithArray:[operDict objectForKey:url][@"blocks"]];
        @synchronized (operDict) {
            [operDict removeObjectForKey:url];
        }
        for (void (^block)(NSData *data,NSError *error) in tempArr) {
            block(receivedata,nil);
        }
        
    }else
    {
        [self download:url params:data count:++count];
    }
}

-(void)addTasks:(NSArray <NSString *> *)urlStrs moduleComplete:(void (^)(NSString *url,NSData *data,NSError *error))oneblock allcomplete:(void (^)(void))block;
{
    NSString *tag = [NSString stringWithFormat:@"%lld",[[NSDate date] timeIntervalSince1970]];
    if (![urlStrs isKindOfClass:[NSArray class]] ||
        urlStrs.count==0) {
        if (block) block();
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
            if (oneblock)
                oneblock(url,data,error);
            @synchronized (weaktasksCheckTag) {
                [[weaktasksCheckTag objectForKey:tag] removeObject:url];
            }
            if ([weakSelf isAllTaskFinishWithTag:tag] && block) {
                block();
            }
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
@end
