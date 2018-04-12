//
//  ViewController.m
//  VideoSplice
//
//  Created by erpapa on 16/8/14.
//  Copyright © 2016年 erpapa. All rights reserved.
//

#import "ViewController.h"

@interface ViewController() <NSTableViewDataSource, NSTableViewDelegate>

@property (weak) IBOutlet NSTableView *tableView;
@property (nonatomic, strong) NSMutableArray *dataSource;

@end

@implementation ViewController

- (void)viewDidLoad {
    [super viewDidLoad];

    // Do any additional setup after loading the view.
    NSDictionary *dict0 = [NSDictionary dictionaryWithObjectsAndKeys:@"视频转换",@"title",@"VideoSpliceController",@"identifier", nil];
    [self.dataSource addObject:dict0];
    [self.tableView reloadData];
}

#pragma mark - NSTableViewDataSource
- (NSInteger)numberOfRowsInTableView:(NSTableView *)tableView
{
    return self.dataSource.count;
}

- (NSView *)tableView:(NSTableView *)tableView viewForTableColumn:(NSTableColumn *)tableColumn row:(NSInteger)row
{
    NSTableCellView *cell = [tableView makeViewWithIdentifier:[tableColumn identifier] owner:self];
    
    NSDictionary *dict = [self.dataSource objectAtIndex:row];
    cell.textField.stringValue = [NSString stringWithFormat:@"%ld.%@",row+1,[dict objectForKey:@"title"]];
    cell.textField.textColor = [NSColor orangeColor];
    cell.textField.editable = NO;
    cell.textField.selectable = NO;
    return cell;
}

- (BOOL)tableView:(NSTableView *)tableView shouldSelectRow:(NSInteger)row
{
    NSDictionary *dict = [self.dataSource objectAtIndex:row];
    NSString *identifier = [dict objectForKey:@"identifier"];
    [self performSegueWithIdentifier:identifier sender:self];
    
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1.0 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        [self.tableView deselectRow:row];
    });
    
    return YES;
}

- (NSMutableArray *)dataSource
{
    if (_dataSource == nil) {
        _dataSource = [NSMutableArray array];
    }
    return _dataSource;
}

@end
