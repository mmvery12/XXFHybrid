//
//  HyBridManager.h
//  Hybrid
//
//  Created by JD on 16/9/20.
//  Copyright © 2016年 YC.L. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "CommFormatConfig.h"
/***********************
 更新下发的配置文件西力度不可控，可能详细到每个文件，可能只到某个大模块。
 资源的依赖可能很复杂，可以尝试通过分析html文件导入js、css的语句来分析出这个html是否可用，js、css没更新完成的情况下需要下载。
 除了程序开始加载一众资源外，可能需要使用时去请求这个模块是否需要更新。
 下发的资源始终以压缩包的形势下发，配置列表中压缩包对应的module名即为压缩包解压后的文件夹名，配置文件中需要添加包与包的依赖关系，但是考虑update时根性细粒度的问题，这样下发的包只能是扁平化的目录结构，即下发的压缩包们全部解压后都在同一级目录，每次更改后更新需要将整个目录一起更新，无法适应可能需要将一个压缩包解压在另一个压缩包的子文件夹中
 本地文件的状态存在3种，1⃣️稳定态2⃣️须根新态3⃣️缺失态，上报让服务器判断文件CUD时情况过于复杂，最简单最稳定的方式本次判断是每个模块一个包，设置依赖关系已确定下载使用次序
 e.g.
 {
    modules = (
                {
                    identify = xxxxx,
                    moduleName = moduleA,
                    remoteurl = http://xxx.xxx,
                    version = 1.0.0,
                    type = jpeg,
                    depend = (
                                moduleC,
                                moduleB
                             )
                },
                {
                    identify = xxxxx,
                    moduleName = moduleB,
                    remoteurl = http://xxx.xxx,
                    version = 1.0.0
                    type = zip,
                    depend = ()
                },
                {
                    identify = xxxxx,
                    moduleName = moduleC,
                    remoteurl = http://xxx.xxx,
                    version = 1.0.0
                    type = bundle,
                    depend = ()
                },
                {
                    identify = xxxxx,
                    moduleName = moduleD,
                    remoteurl = http://xxx.xxx,
                    version = 1.0.0
                    type = jpeg,
                    depend = (
                                moduleA
                             )
                }
              )
 }
 Comm部分运行示意图：
 
***********************/
@interface HyBridManager : NSObject
+(instancetype)Manager;
+(void)Start;//开始使用
//解析webview中传递来的url，具体格式详见CommFormatConfig.h
+(BOOL)HandleWebViewURL:(NSURL *)url CommExcWebView:(id)webview;
// @uri 下发的文件体系中顶级文件夹直到资源的完整相对路径
+(void)UseResourceWithURI:(NSString *)uri complete:(void (^)(NSData *source, NSError *error))block;
//返回入参modulename，filename对应的文件数据
+(void)UseResourceWithModuleName:(NSString *)name fileName:(NSString *)fileName complete:(void (^)(NSData *source, NSError *error))block;
@end
