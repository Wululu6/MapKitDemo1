//
//  SearchViewController.m
//  MapKitTest
//
//  Created by apple on 2019/7/29.
//  Copyright © 2019 apple. All rights reserved.
//

#import "SearchViewController.h"

@interface SearchViewController ()<AMapSearchDelegate,UITableViewDelegate,UITableViewDataSource,UITextFieldDelegate>

@property (nonatomic, strong) AMapSearchAPI *searchAPI;

@property (nonatomic, strong) UIView *searchView;

@property (nonatomic, strong) UITextField *textField;

@property (nonatomic, strong) UITableView *tableView;

@property (nonatomic, strong) NSMutableArray *searchResult;

@end

@implementation SearchViewController


- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view.
    
    self.view.backgroundColor = [UIColor whiteColor];
    
    self.navigationItem.titleView = self.searchView;
    
    // 初始化搜索
    self.searchAPI = [[AMapSearchAPI alloc] init];
    self.searchAPI.delegate = self;
    
    [self creatRightItem];
    
    [self.view addSubview:self.tableView];
    
    [self.tableView reloadData];
    
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"cell"];
    if (cell == nil) {
        cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:@"cell"];
    }
    AMapTip *tip = self.searchResult[indexPath.row];
    if (tip.location == nil)
    {
        cell.imageView.image = [UIImage imageNamed:@"search"];
    }
    //NSString *title = [self.searchResult objectAtIndex:indexPath.row];
    cell.textLabel.text = tip.name;
    cell.detailTextLabel.text = tip.address;
    cell.selectionStyle = UITableViewCellSelectionStyleNone;
    return cell;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    return self.searchResult.count;
}


- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath {
    return 45;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    
    AMapTip *tip = self.searchResult[indexPath.row];
    //CLLocation *location = [[CLLocation alloc] initWithLatitude:tip.location.latitude longitude:tip.location.longitude];
    if (tip.location != nil) {
        if (self.selectPositionBlock) {
            self.selectPositionBlock(tip);
        }
        [self.navigationController popViewControllerAnimated:YES];
    }
    
}

#pragma mark--创建右侧的周围环境
- (void)creatRightItem {
    UIBarButtonItem *item = [[UIBarButtonItem alloc] initWithTitle:@"取消" style:(UIBarButtonItemStylePlain) target:self action:@selector(rightItemAction)];
    self.navigationItem.rightBarButtonItem = item;
}


#pragma mark--进入右侧周围的环境事件
- (void)rightItemAction {
    
    [self.navigationController popViewControllerAnimated:YES];
    
}

- (BOOL)textField:(UITextField *)textField shouldChangeCharactersInRange:(NSRange)range replacementString:(NSString *)string {
    
    // 进行搜索
    if (textField.text != nil && textField.text.length > 0) {
        AMapInputTipsSearchRequest *tips = [[AMapInputTipsSearchRequest alloc] init];
        tips.keywords = textField.text;
        tips.city     = self.city;
        tips.cityLimit = YES;// 是否限制城市
        [self.searchAPI AMapInputTipsSearch:tips];
    }
    
    return YES;
}


// 点击搜索的时候进行搜索
- (BOOL)textFieldShouldReturn:(UITextField *)textField {
    [textField resignFirstResponder];
    // 进行搜索
    if (textField.text != nil && textField.text.length > 0) {
        AMapInputTipsSearchRequest *tips = [[AMapInputTipsSearchRequest alloc] init];
        tips.keywords = textField.text;
        tips.city     = self.city;
        tips.cityLimit = YES;// 是否限制城市
        [self.searchAPI AMapInputTipsSearch:tips];
    }
    return YES;
}


/* 输入提示回调. */
- (void)onInputTipsSearchDone:(AMapInputTipsSearchRequest *)request response:(AMapInputTipsSearchResponse *)response {
    //解析response获取提示词，具体解析见 Demo
    
    [self.searchResult setArray:response.tips];
    [self.tableView reloadData];
}


- (void)scrollViewDidScroll:(UIScrollView *)scrollView {
    [self.textField resignFirstResponder];
}


- (UIView *)searchView {
    if (!_searchView) {
        _searchView = [[UIView alloc] initWithFrame:CGRectMake(0, 0, self.view.frame.size.width - 160, 50)];
        _searchView.backgroundColor = [UIColor whiteColor];
        UITextField *textField = [[UITextField alloc] initWithFrame:CGRectMake(0, 5, CGRectGetWidth(_searchView.frame), 40)];
        [_searchView addSubview:textField];
        self.textField = textField;
        textField.backgroundColor = [UIColor lightGrayColor];
        textField.clearButtonMode = UITextFieldViewModeWhileEditing;
        textField.placeholder = @"输入搜索地址";
        textField.delegate = self;
        textField.returnKeyType = UIReturnKeySearch;
    }
    return _searchView;
}


- (NSMutableArray *)searchResult {
    if (!_searchResult) {
        _searchResult = [[NSMutableArray alloc] init];
    }
    return _searchResult;
}


- (UITableView *)tableView {
    if (!_tableView) {
        _tableView = [[UITableView alloc] initWithFrame:self.view.bounds style:UITableViewStylePlain];
    }
    _tableView.delegate = self;
    _tableView.dataSource = self;
    _tableView.tableFooterView = [[UIView alloc] init];
    _tableView.tableHeaderView = [[UIView alloc] init];
    return _tableView;
}



/*
#pragma mark - Navigation

// In a storyboard-based application, you will often want to do a little preparation before navigation
- (void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender {
    // Get the new view controller using [segue destinationViewController].
    // Pass the selected object to the new view controller.
}
*/

@end
