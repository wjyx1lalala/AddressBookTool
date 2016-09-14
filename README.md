# AddressBookTool

一段代码轻松帮你访问通讯录

IOS-10 以后,苹果加强用户隐私数据的保护
您需要在info.plist文件配置 NSContactsUsageDescription 字段

//获取通讯录联系人名字,电话,并过滤掉非正常的电话号码

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
            //授权通过
            _dataSource = telArr;
            [self.tableView reloadData];
        }
    }];
    
    
    //调用起系统通讯录页面   
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
