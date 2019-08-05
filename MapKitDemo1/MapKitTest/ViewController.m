//
//  ViewController.m
//  MapKitTest
//
//  Created by apple on 2019/7/22.
//  Copyright © 2019年 apple. All rights reserved.
//

#import "ViewController.h"

#import "LocationViewController.h"

#import "MovePostionViewController.h"

#import "ShowPostionViewController.h"

#import "FindRoundPositionViewController.h"
#import "SearchFindPostionController.h"
#import "RoutePlanDriveViewController.h"
#import "FindPositionDrawLineViewController.h"
#import "FindDrawLineCompositeController.h"
#import "DrivePositionsCompositeController.h"


@interface ViewController ()<UITableViewDelegate,UITableViewDataSource>


@property (nonatomic, strong) UITableView *tableView;

@property (nonatomic, strong) NSMutableArray *dataSource;

@end

@implementation ViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view, typically from a nib.
    
    
    self.title = @"地图系统";
    
    
    self.view.backgroundColor = [UIColor whiteColor];
    
    
    NSString *title  = @"定位并且找出周围建筑";
    NSString *title1 = @"移动位置并找出周围环境";
    NSString *title2 = @"时时移动定位，并显示位置";
    NSString *title3 = @"时时定位并找出多点坐标";
    NSString *title4 = @"关键词搜索并定位";
    NSString *title5 = @"绘制驾车出行路线规划（彩色线路）";
    NSString *title6 = @"搜索地址并规划路线（彩色线路）";
    NSString *title7 = @"搜索地址，规划路线，选择线路并导航";
    NSString *title8 = @"点击停车位进行线路规划，并添加导航";
    
    [self.dataSource addObject:title];
    [self.dataSource addObject:title1];
    [self.dataSource addObject:title2];
    [self.dataSource addObject:title3];
    [self.dataSource addObject:title4];
    [self.dataSource addObject:title5];
    [self.dataSource addObject:title6];
    [self.dataSource addObject:title7];
    [self.dataSource addObject:title8];
    
    
    [self.view addSubview:self.tableView];
    
    [self.tableView reloadData];
    
}


- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"cell"];
    if (cell == nil) {
        cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:@"cell"];
    }
    NSString *title = [self.dataSource objectAtIndex:indexPath.row];
    cell.textLabel.text = title;
    cell.selectionStyle = UITableViewCellSelectionStyleNone;
    return cell;
}


- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    return self.dataSource.count;
}


- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath {
    return 45;
}


#pragma mark--tableView的点击事件
- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    
    
    if (indexPath.row == 0) {
        LocationViewController *location = [[LocationViewController alloc] init];
        [self.navigationController pushViewController:location animated:YES];
    } else if (indexPath.row == 1) {
        MovePostionViewController *moveVc = [[MovePostionViewController alloc] init];
        [self.navigationController pushViewController:moveVc animated:YES];
    } else if (indexPath.row == 2) {
        ShowPostionViewController *showVc = [[ShowPostionViewController alloc] init];
        [self.navigationController pushViewController:showVc animated:YES];
    } else if (indexPath.row == 3) {
        FindRoundPositionViewController *fVc = [[FindRoundPositionViewController alloc] init];
        [self.navigationController pushViewController:fVc animated:YES];
    } else if (indexPath.row == 4) {
        SearchFindPostionController *sVc = [[SearchFindPostionController alloc] init];
        [self.navigationController pushViewController:sVc animated:YES];
    } else if (indexPath.row == 5) {
        RoutePlanDriveViewController *rVc = [[RoutePlanDriveViewController alloc] init];
        [self.navigationController pushViewController:rVc animated:YES];
    } else if (indexPath.row == 6) {
        FindPositionDrawLineViewController *fVc = [[FindPositionDrawLineViewController alloc] init];
        [self.navigationController pushViewController:fVc animated:YES];
    } else if (indexPath.row == 7) {
        FindDrawLineCompositeController *compositeVc = [[FindDrawLineCompositeController alloc] init];
        [self.navigationController pushViewController:compositeVc animated:YES];
    } else if (indexPath.row == 8) {
        DrivePositionsCompositeController *dVc = [[DrivePositionsCompositeController alloc] init];
        [self.navigationController pushViewController:dVc animated:YES];
    }
    
    
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


- (NSMutableArray *)dataSource {
    if (!_dataSource) {
        _dataSource = [[NSMutableArray alloc] init];
    }
    return _dataSource;
}


@end


