//
//  LogDebug.m
//  Hybrid
//
//  Created by JD on 17/1/3.
//  Copyright © 2017年 YC.L. All rights reserved.
//

#import "LogDebug.h"

@interface LogDebug ()
@property (nonatomic,assign)BOOL logDebug;
@end

@implementation LogDebug
+(id)Share
{
    static LogDebug *debug;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        debug = [LogDebug new];
    });
    return debug;
}
+(void)SetLogDebug:(BOOL)canlog;
{
    [[LogDebug Share] setLogDebug:canlog];
}

+(BOOL)LogDebug;
{
    return [[LogDebug Share] logDebug];
}
@end
