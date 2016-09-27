//
//  Zip.m
//  File
//
//  Created by JD on 16/9/20.
//  Copyright © 2016年 YC.L. All rights reserved.
//

#import "Zip.h"

@implementation Zip
+ (BOOL)unzipFileAtPath:(NSString *)path toDestination:(NSString *)destination overwrite:(BOOL)overwrite password:(nullable NSString *)password error:(NSError * *)error;
{
    return [SSZipArchive unzipFileAtPath:path toDestination:destination overwrite:overwrite password:path error:error];
}
@end
