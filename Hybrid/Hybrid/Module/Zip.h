//
//  Zip.h
//  File
//
//  Created by JD on 16/9/20.
//  Copyright © 2016年 YC.L. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <ZipArchive/ZipArchive.h>
@interface Zip : NSObject
+ (BOOL)unzipFileAtPath:(NSString *)path toDestination:(NSString *)destination overwrite:(BOOL)overwrite password:(nullable NSString *)password error:(NSError * *)error;
@end
