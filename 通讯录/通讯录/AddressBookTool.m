//
//  AddressBookTool.m
//  Projectflow
//
//  Created by nuomi on 16/8/16.
//  Copyright © 2016年 Nuomi. All rights reserved.
//  通讯录管理工具

#import "AddressBookTool.h"
#import <AddressBookUI/AddressBookUI.h>
#import <ContactsUI/ContactsUI.h>
#import <Contacts/Contacts.h>




@interface AddressBookTool ()<CNContactViewControllerDelegate,CNContactPickerDelegate,ABPeoplePickerNavigationControllerDelegate>

@property (nonatomic,copy) void(^choiceBlock)(BOOL isAuthorized,BOOL isCancle,NSString * tel,NSString * contactName);
@property (nonatomic,assign) BOOL isMoreThanIOS9;//系统版本
@property (nonatomic,assign) AuthorizedStatus status;//授权状态
@property (nonatomic,strong) NSMutableArray * allTelArr;//所有的手机联系人
@end

@implementation AddressBookTool

+(instancetype)shareTool{
    static AddressBookTool * tool = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        tool = [[self alloc] init];
    });
    return tool;
}

- (NSMutableArray *)allTelArr{
    if (_allTelArr == nil) {
        _allTelArr = [NSMutableArray array];
    }
    return _allTelArr;
}

- (instancetype)init
{
    self = [super init];
    
    if (self) {
        _justUseChinaTel = YES;
        _isMoreThanIOS9 = [[[UIDevice currentDevice] systemVersion] compare:@"9" options:NSNumericSearch] != NSOrderedAscending;
        if (_isMoreThanIOS9) {
            CNAuthorizationStatus status = [CNContactStore authorizationStatusForEntityType:CNEntityTypeContacts];
            if (status == CNAuthorizationStatusNotDetermined) {
                _status = NotDeterminedStatus;
            }else if (status == CNAuthorizationStatusAuthorized){
                _status = AllowStatus;
            }else{
                _status = DeniedOrOtherStatus;
            }
        }else{
            //Not Than IOS 8
            ABAuthorizationStatus status = ABAddressBookGetAuthorizationStatus();
            
            if(status == kABAuthorizationStatusNotDetermined){
                
                _status = NotDeterminedStatus;
                
            }else if (status == kABAuthorizationStatusAuthorized){
                
                _status = AllowStatus;
                
            }else{
                _status = DeniedOrOtherStatus;
            }
        }
    }
    return self;
}

- (AuthorizedStatus)getAuthorizedStatus{
    return _status;
}


//发起授权请求
- (void)askAuthorizedWith:(void(^)(BOOL isAuthorizedSuccess))complete{
    if (self.isMoreThanIOS9 == YES) {
        [[[CNContactStore alloc] init] requestAccessForEntityType:CNEntityTypeContacts completionHandler:^(BOOL granted, NSError * _Nullable error) {
            if (granted) {
                _status = AllowStatus;
            }
            complete(granted);
        }];
    }else{
        
        ABAddressBookRef addressBook = ABAddressBookCreateWithOptions(NULL, NULL);
        ABAddressBookRequestAccessWithCompletion(addressBook, ^(bool granted, CFErrorRef error) {
            if (granted) {
                _status = AllowStatus;
            }
            complete(granted);
        });
    }
    
}

- (void)ios8AndBeforeGetContactWith:(void(^)(NSArray * telArr))complete{
    [self.allTelArr removeAllObjects];
    
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        ABAddressBookRef addBook = ABAddressBookCreateWithOptions(NULL, NULL);
        //取得本地所有联系人记录
        NSArray * tmpArray = CFBridgingRelease(ABAddressBookCopyArrayOfAllPeople(addBook));
        
        [tmpArray enumerateObjectsUsingBlock:^(id  obj, NSUInteger idx, BOOL *  stop) {
            ABRecordRef thisPerson = (__bridge ABRecordRef)(obj);
            
            NSString *firstName = CFBridgingRelease(ABRecordCopyValue(thisPerson, kABPersonFirstNameProperty));
            firstName = firstName != nil? firstName:@"";
            NSString *lastName = CFBridgingRelease(ABRecordCopyValue(thisPerson, kABPersonLastNameProperty));
            
            NSString * name = nil;
            
            if (firstName && lastName) {
                name = [firstName stringByAppendingString:lastName];
            } else {
                name = @"未知名字";
            }
            
            NSString* phone = nil;
            
            ABMultiValueRef phoneNumbers = ABRecordCopyValue(thisPerson,kABPersonPhoneProperty);
            
            if (ABMultiValueGetCount(phoneNumbers) > 0 ) {
                
                phone = (__bridge_transfer NSString*)ABMultiValueCopyValueAtIndex(phoneNumbers, 0);
                
                if (phone && name && phone.length > 0 && name.length > 0) {
                    if (self.justUseChinaTel) {
                        phone = [self filterCharacterWithTel:phone];
                        if ([self isMobileNumber:phone]) {
                            [self.allTelArr addObject:@{@"name":name,@"tel":phone}];
                        }else{
                            NSLog(@"被过滤掉的人的名字为:%@\n电话为:%@",name,phone);
                        }
                    }else{
                        [self.allTelArr addObject:@{@"name":name,@"tel":phone}];
                    }
                    
                }
            }
            CFRelease(phoneNumbers);
        }];
        CFRelease(addBook);
        dispatch_async(dispatch_get_main_queue(), ^{
            if (complete) {
                complete(self.allTelArr);
            }
        });
    });
    
}


#pragma GCD 异步读取所有联系人
- (void)ios9LaterGetContactWith:(void(^)(NSArray *telArr))complete{
    //IOS 9
    [self.allTelArr removeAllObjects];
    
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        
        CNContactStore *store = [[CNContactStore alloc]init];
        
        NSError *error = nil;
        
        CNContactFetchRequest *request = [[CNContactFetchRequest alloc]initWithKeysToFetch:@[CNContactGivenNameKey,CNContactFamilyNameKey,CNContactPhoneNumbersKey]];
        
        [store enumerateContactsWithFetchRequest:request error:&error usingBlock:^(CNContact * _Nonnull contact, BOOL * _Nonnull stop) {
            
            NSString *name = [NSString stringWithFormat:@"%@%@",contact.familyName, contact.givenName];//名字
            
            NSString *phone = [NSString string];
            
            if ([self judgeStringNotNull:name] == NO) {
                name = @"未知名字";
            }
            
            if (contact.phoneNumbers.count > 0) {
                
                for (CNLabeledValue *value in contact.phoneNumbers) {
                    
                    CNPhoneNumber *phoneNum = value.value;
                    
                    phone = phoneNum.stringValue; //电话
                }
                if (phone && name && phone.length > 0 && name.length > 0) {
                    if (self.justUseChinaTel) {
                        phone = [self filterCharacterWithTel:phone];
                        if ([self isMobileNumber:phone]) {
                            [self.allTelArr addObject:@{@"name":name,@"tel":phone}];
                        }else{
                            NSLog(@"被过滤掉的人的名字为:%@\n电话为:%@",name,phone);
                        }
                    }else{
                        [self.allTelArr addObject:@{@"name":name,@"tel":phone}];
                    }
                    
                }
            }
            
        }];
        
        dispatch_async(dispatch_get_main_queue(), ^{
            if (complete) {
                complete(self.allTelArr);
            }
        });
        
    });
    
}

//获取通讯录中所有电话号码
- (void)obtainAllTelIfNeedAskForAuthorized:(BOOL)isNeedGetAuthorized   withComplete:(void(^)(BOOL isAuthorized,NSArray * telArr))completeBlock{
    if (self.isMoreThanIOS9 == YES) {
        if (_status == DeniedOrOtherStatus) {
            completeBlock(NO,nil);
        }else if (_status == AllowStatus){
            //异步访问通讯录
            [self ios9LaterGetContactWith:^(NSArray *telArr) {
                completeBlock(YES,telArr);
            }];
        }else if (_status == NotDeterminedStatus){
            
            if (isNeedGetAuthorized) {
                [self askAuthorizedWith:^(BOOL isAuthorizedSuccess) {
                    if (isAuthorizedSuccess) {
                        [self ios9LaterGetContactWith:^(NSArray *telArr) {
                            completeBlock(YES,telArr);
                        }];
                    }else{
                        if ([NSThread isMainThread]) {
                            completeBlock(NO,nil);
                        }else{//回到主线程
                            dispatch_async(dispatch_get_main_queue(), ^{
                                completeBlock(NO,nil);
                            });
                        }
                    }
                    
                }];
            }else{
                completeBlock(NO,nil);
            }
        }
        
    }else{
        
        if (_status == DeniedOrOtherStatus) {
            completeBlock(NO,nil);
        }else if (_status == AllowStatus){
            [self ios8AndBeforeGetContactWith:^(NSArray *telArr) {
                completeBlock(YES,telArr);
            }];
        }else if (_status == NotDeterminedStatus){
            if (isNeedGetAuthorized) {
                [self askAuthorizedWith:^(BOOL isAuthorizedSuccess) {
                    if (isAuthorizedSuccess) {
                        [self ios8AndBeforeGetContactWith:^(NSArray *telArr) {
                            completeBlock(YES,telArr);
                        }];
                    }else{
                        if ([NSThread isMainThread]) {
                            completeBlock(NO,nil);
                        }else{//回到主线程
                            dispatch_async(dispatch_get_main_queue(), ^{
                                completeBlock(NO,nil);
                            });
                        }
                    }
                }];
            }else{
                completeBlock(NO,nil);
            }
        }
    }
}



- (void)showAddressBookAtViewController:(UIViewController *)viewController WithComplete:(void(^)(BOOL isAuthorized,BOOL isCancle,NSString * selectedTel,NSString * contactName))completeBlock{
    
    if (_status == NotDeterminedStatus) {
        [self askAuthorizedWith:^(BOOL isAuthorizedSuccess) {
            if (isAuthorizedSuccess) {
                //如果授权通过
                self.choiceBlock = completeBlock;
                [self showContactViewControllerWithShowViewController:viewController];
            }else{
                //禁止或被限制时
                if (completeBlock) {
                    completeBlock(NO,YES,nil,nil);
                }
            }
            
        }];
    }else if (_status == AllowStatus){
        //已经授权
        self.choiceBlock = completeBlock;
        [self showContactViewControllerWithShowViewController:viewController];
        
    }else{
        //禁止或被限制时
        if (completeBlock) {
            completeBlock(NO,YES,nil,nil);
        }
    }
}

//调用弹出通讯录页面,授权允许的情况下,才可以调用
- (void)showContactViewControllerWithShowViewController:(UIViewController *)viewController{
    
    if (self.isMoreThanIOS9 == YES) {
        
        CNContactPickerViewController* contactPicker = [[CNContactPickerViewController alloc]init];
        
        contactPicker.delegate = self;
        
        contactPicker.displayedPropertyKeys = @[CNContactFamilyNameKey,CNContactPhoneNumbersKey];
        
        [viewController presentViewController:contactPicker animated:YES completion:nil];
        
    }else {
        
        ABPeoplePickerNavigationController *picker = [[ABPeoplePickerNavigationController alloc] init];
        
        picker.peoplePickerDelegate = self;
        
        [viewController presentViewController:picker animated:YES completion:nil];
    }
    
}


- (BOOL)judgeStringNotNull:(NSString *)str{
    
    if ([str isKindOfClass:[NSString class]] == NO) {
        return NO;
    }
    if (str.length <= 0 || [str isEqualToString:@""]) {
        return NO;
    }else{
        return YES;
    }
}

#pragma mark - 判断是否是电话号码
- (BOOL)isMobileNumber:(NSString *)mobileNumber
{
    NSString * tel = [self filterCharacterWithTel:mobileNumber];
    
    NSString * pattern = @"^(0|86|17951)?(13[0-9]|15[0-9]|17[0-9]|18[0-9]|14[0-9])[0-9]{8}$";
    NSPredicate *pred = [NSPredicate predicateWithFormat:@"SELF MATCHES %@", pattern];
    
    return [pred evaluateWithObject:tel];
}

#pragma mark - 过滤掉电话号码中的特殊字符
- (NSString *)filterCharacterWithTel:(NSString * )tel{
    
    //先过滤掉不正常的字符
    NSString * telephone = tel;
    if ([telephone hasPrefix:@"+86"]) {
        telephone = [telephone substringFromIndex:3];
    }
    
    NSCharacterSet * deleteCharacterSet = [NSCharacterSet characterSetWithCharactersInString:@"+- () "];
    telephone = [[telephone componentsSeparatedByCharactersInSet: deleteCharacterSet] componentsJoinedByString:@""];
    
    return telephone;
}

#pragma mark - IOS8 选择通讯录,选择属性详情
- (void)peoplePickerNavigationController:(ABPeoplePickerNavigationController*)peoplePicker didSelectPerson:(ABRecordRef)person property:(ABPropertyID)property identifier:(ABMultiValueIdentifier)identifier NS_AVAILABLE_IOS(8_0){
    
    NSString* phone = nil;
    
    //查找这条记录中的名字
    NSString *firstName =CFBridgingRelease(ABRecordCopyValue(person,kABPersonFirstNameProperty));
    firstName = firstName != nil? firstName:@"";
    //查找这条记录中的姓氏
    NSString *lastName =CFBridgingRelease(ABRecordCopyValue(person,kABPersonLastNameProperty));
    lastName = lastName != nil? lastName:@"";
    NSString * name = [firstName stringByAppendingString:lastName];
    
    ABMultiValueRef phoneNumbers = ABRecordCopyValue(person,kABPersonPhoneProperty);
    
    if (ABMultiValueGetCount(phoneNumbers) > 0) {
        
        phone = (__bridge_transfer NSString*)ABMultiValueCopyValueAtIndex(phoneNumbers, 0);
        phone = [self filterCharacterWithTel:phone];
    }
    
    CFRelease(phoneNumbers);
    
    if(self.choiceBlock){
        self.choiceBlock(YES,NO,phone,name);
    }
    
    self.choiceBlock = nil;
}

#pragma mark - 手机联系人代理 iOS8及以下,选择单个用户
- (void)peoplePickerNavigationController:(ABPeoplePickerNavigationController*)peoplePicker didSelectPerson:(ABRecordRef)person NS_AVAILABLE_IOS(8_0){
    NSString* phone = nil;
    
    //查找这条记录中的名字
    NSString *firstName =CFBridgingRelease(ABRecordCopyValue(person,kABPersonFirstNameProperty));
    firstName = firstName != nil? firstName:@"";
    //查找这条记录中的姓氏
    NSString *lastName =CFBridgingRelease(ABRecordCopyValue(person,kABPersonLastNameProperty));
    lastName = lastName != nil? lastName:@"";
    NSString * name = [firstName stringByAppendingString:lastName];
    
    ABMultiValueRef phoneNumbers = ABRecordCopyValue(person,kABPersonPhoneProperty);
    
    if (ABMultiValueGetCount(phoneNumbers) > 0) {
        
        phone = (__bridge_transfer NSString*)ABMultiValueCopyValueAtIndex(phoneNumbers, 0);
        
        phone = [self filterCharacterWithTel:phone];
    }
    
    CFRelease(phoneNumbers);
    
    if(self.choiceBlock){
        self.choiceBlock(YES,NO,phone,name);
    }
    
    self.choiceBlock = nil;
}

// IOS 8及以下 取消
- (void)peoplePickerNavigationControllerDidCancel:(ABPeoplePickerNavigationController *)peoplePicker{
    
    if(self.choiceBlock){
        self.choiceBlock(YES,YES,nil,nil);
    }
    
    self.choiceBlock = nil;
}


#pragma mark - IOS 9以后通讯录

- (void)contactPicker:(CNContactPickerViewController *)picker didSelectContact:(CNContact *)contact{
    
    NSString *phone = nil;
    NSString *name = [NSString stringWithFormat:@"%@%@",contact.familyName, contact.givenName];//名字
    if (contact.phoneNumbers.count > 0) {
        
        for (CNLabeledValue *value in contact.phoneNumbers) {
            
            CNPhoneNumber *phoneNum = value.value;
            
            phone = phoneNum.stringValue; //电话
            NSLog(@"%@",phone);
            NSLog(@"%@",value);
        }
        
        phone = [self filterCharacterWithTel:phone];
    }
    
    if(self.choiceBlock){
        self.choiceBlock(YES,NO,phone,name);
    }
    self.choiceBlock = nil;
}

- (void)contactPickerDidCancel:(CNContactPickerViewController *)picker{
    
    if(self.choiceBlock){
        self.choiceBlock(YES,YES,nil,nil);
    }
    self.choiceBlock = nil;
}



@end
