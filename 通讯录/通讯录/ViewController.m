//
//  ViewController.m
//  通讯录
//
//  Created by nuomi on 16/9/14.
//  Copyright © 2016年 ADai. All rights reserved.
//

#import "ViewController.h"
#import "AddressBookTool.h"

@interface ViewController ()<UITableViewDelegate,UITableViewDataSource>
@property (strong, nonatomic)  UITableView *tableView;
@property (strong, nonatomic) NSArray * dataSource;
@end

@implementation ViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    self.navigationController.navigationBar.translucent = NO;
    _tableView = [[UITableView alloc] initWithFrame:self.view.bounds];
    _tableView.delegate = self;
    _tableView.dataSource = self;
    [self.view addSubview:_tableView];
    [self accessContact];
}

- (void)accessContact{
    
    [[AddressBookTool shareTool] obtainAllTelIfNeedAskForAuthorized:YES withComplete:^(BOOL isAuthorized, NSArray *telArr) {
        
        if (isAuthorized == NO) {
            UILabel *label = [[UILabel alloc]initWithFrame:CGRectMake(0, 0, [UIScreen mainScreen].bounds.size.width, 100)];
            label.text = @"访问通讯录被拒绝了";
            label.numberOfLines = 0;
            label.textAlignment = NSTextAlignmentCenter;
            label.font = [UIFont systemFontOfSize:18];
            label.textColor = [UIColor darkGrayColor];
            label.center = self.view.center;
            [self.view addSubview:label];
        }else{
            _dataSource = telArr;
            [self.tableView reloadData];
        }
    }];
}

- (IBAction)clickContact:(id)sender {
    
    [[AddressBookTool shareTool] showAddressBookAtViewController:self WithComplete:^(BOOL isAuthorized, BOOL isCancle, NSString *selectedTel, NSString *contactName) {
        if (isAuthorized == NO) {
            //delay to show alert can avoid modal Present conflict
            dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.2 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
                UIAlertController * alert = [UIAlertController alertControllerWithTitle:@"提示" message:@"请您设置允许APP访问您的通讯录,请前往\n设置>隐私>通讯录" preferredStyle:UIAlertControllerStyleAlert];
                UIAlertAction *action = [UIAlertAction actionWithTitle:@"确定" style:UIAlertActionStyleCancel handler:^(UIAlertAction * _Nonnull action) {
                    
                }];
                [alert addAction:action];
                [self presentViewController:alert animated:YES completion:nil];
            });
        }else if (isCancle){
            NSLog(@"取消选择联系人");
        }else{
            NSLog(@"\n选择联系人的\n联系人名字是:%@\n电话是:%@",contactName,selectedTel);
        }
    }];
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section{
    return _dataSource.count;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath{
    static NSString * const ContactCellID = @"cellId";
    UITableViewCell * cell = [tableView dequeueReusableCellWithIdentifier:ContactCellID];
    if (cell == nil) {
        cell = [[UITableViewCell alloc] initWithStyle:1 reuseIdentifier:ContactCellID];
    }
    NSDictionary * dict = _dataSource[indexPath.row];
    cell.textLabel.text = dict[@"name"];
    cell.detailTextLabel.text = dict[@"tel"];
    return cell;
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}


@end
