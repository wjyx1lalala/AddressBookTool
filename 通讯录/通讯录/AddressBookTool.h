//
//  AddressBookTool.h
//  Projectflow
//
//  Created by nuomi on 16/8/16.
//  Copyright © 2016年 Nuomi. All rights reserved.
/** 访问通讯录流程,仅限大陆的通讯录
 *  未选择授权的时候,先去请求授权,授权结束以后,根据授权状态做出选择
 *  已经授权的情况下,直接调用通讯录
 *  授权被拒绝或者StatusRestricted(受限制)状态下,返回授权失败
 */

#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>

//通讯录的授权状态
typedef NS_ENUM(NSInteger, AuthorizedStatus) {
    NotDeterminedStatus,//未决定是否授权,使用前需授权
    AllowStatus,        //已获取授权,允许使用
    DeniedOrOtherStatus,//受限制或者其他状态,不能访问通讯录
};

@interface AddressBookTool : NSObject

//仅保留中国大陆格式的电话号码,Default YES ,
//if YES过滤后仅返回电话号码, if NO 返回原生电话格式.
@property (nonatomic,assign)BOOL justUseChinaTel;

+ (instancetype)shareTool;

//获取当前授权状态
- (AuthorizedStatus)getAuthorizedStatus;

/**
 *  调用系统通讯录
 *
 *  @param viewController 需要调用的控制器
 *  @param completeBlock    调用后的回调,selectedTel表示选择后的电话号,isCancle表示是否点击取消,isAuthorized表示用户
 */
- (void)showAddressBookAtViewController:(UIViewController *)viewController WithComplete:(void(^)(BOOL isAuthorized,BOOL isCancle,NSString * selectedTel,NSString * contactName))completeBlock;



/**
 *  获取通讯录中所有的手机联系人,(已过滤掉非电话号码)
 *
 *  @param isNeedGetAuthorized 是否请求授权(主要如果是首次使用通讯录)
 *  @subParam telArr           可能数组个数为空,如果通讯录中电话号码个数为0
 *  @param completeBlock       获取到访问结果的回调
 */
- (void)obtainAllTelIfNeedAskForAuthorized:(BOOL)isNeedGetAuthorized   withComplete:(void(^)(BOOL isAuthorized,NSArray * telArr))completeBlock;

@end
