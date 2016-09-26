//
//  Module.m
//  Hybrid
//
//  Created by JD on 16/9/21.
//  Copyright © 2016年 YC.L. All rights reserved.
//

#import "Module.h"

@implementation Module

-(BOOL)allReady
{

    return YES;
}

- (void)encodeWithCoder:(NSCoder *)aCoder;
{
    [aCoder encodeObject:self.identify forKey:@"identify"];
    [aCoder encodeObject:self.moduleName forKey:@"moduleName"];
    [aCoder encodeObject:self.remoteurl forKey:@"remoteurl"];
    [aCoder encodeObject:self.version forKey:@"version"];
    [aCoder encodeObject:self.type forKey:@"type"];
    [aCoder encodeObject:self.depend forKey:@"depend"];
    [aCoder encodeObject:@(self.status) forKey:@"status"];
}

- (nullable instancetype)initWithCoder:(NSCoder *)aDecoder;
{
    self = [super init];
    if (self)
    {
        self.identify = [aDecoder decodeObjectForKey:@"identify"];
        self.moduleName = [aDecoder decodeObjectForKey:@"moduleName"];
        self.remoteurl = [aDecoder decodeObjectForKey:@"remoteurl"];
        self.version = [aDecoder decodeObjectForKey:@"version"];
        self.type = [aDecoder decodeObjectForKey:@"type"];
        self.depend = [aDecoder decodeObjectForKey:@"depend"];
        self.status = [[aDecoder decodeObjectForKey:@"status"] integerValue];
    }
    return self;
}
@end
