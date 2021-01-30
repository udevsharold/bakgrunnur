#include "../common.h"
#include "BakgrunnurQuickActionsController.h"

@implementation BakgrunnurQuickActionsController

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
    return 1;
}

- (NSString *)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section {
    switch (section) {
        case 0:
            return @"";
        default:
            return @"";
    }
}

- (NSString *)tableView:(UITableView *)tableView titleForFooterInSection:(NSInteger)section{
    switch (section) {
        case 0:
            return @"Master switch will take precedence over Once. The latter will dynamically hide when master switch is enabled. Token for Once switch will be revoked when the app is active again.";
        default:
            return @"";
            
    }
}


- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    switch (section) {
        case 0:
            return 2;
        default:
            return 0;
    }
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"BKGQuickActionsCell" forIndexPath:indexPath];
    
    if (cell == nil){
        cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:@"BKGQuickActionsCell"];
    }
    
    switch(indexPath.section) {
        case 0: {
            switch (indexPath.row) {
                case 0:{
                    BOOL enabled = [[self readPreferenceValueForKey:@"quickActionMaster" defaultValue:@YES] boolValue];
                    cell.textLabel.text = @"Master - Enable/Disable";
                    cell.accessoryType = enabled ? UITableViewCellAccessoryCheckmark : UITableViewCellAccessoryNone;
                    break;
                }
                case 1:{
                    BOOL enabled = [[self readPreferenceValueForKey:@"quickActionOnce" defaultValue:@NO] boolValue];
                    cell.textLabel.text = @"Once - Enable/Disable";
                    cell.accessoryType = enabled ? UITableViewCellAccessoryCheckmark : UITableViewCellAccessoryNone;
                    break;
                }
                default:
                    break;
            }
            break;
        }
        case 1: {
            break;
        }
    }
    return cell;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath{
    [tableView deselectRowAtIndexPath:indexPath animated:YES];
    UITableViewCell *cell =  [tableView cellForRowAtIndexPath:indexPath];
    switch(indexPath.section) {
        case 0: {
            switch (indexPath.row) {
                case 0:{
                    BOOL enabled = [[self readPreferenceValueForKey:@"quickActionMaster" defaultValue:@YES] boolValue];
                    [self setPreferenceValue:@(!enabled) forKey:@"quickActionMaster"];
                    cell.accessoryType = !enabled ? UITableViewCellAccessoryCheckmark : UITableViewCellAccessoryNone;
                    break;
                }
                case 1:{
                    BOOL enabled = [[self readPreferenceValueForKey:@"quickActionOnce" defaultValue:@NO] boolValue];
                    [self setPreferenceValue:@(!enabled) forKey:@"quickActionOnce"];
                    cell.accessoryType = !enabled ? UITableViewCellAccessoryCheckmark : UITableViewCellAccessoryNone;
                    break;
                }
                default:
                    break;
            }
            break;
        }
        case 1:{
           
            break;
        }
    }
}

- (id)readPreferenceValueForKey:(NSString *)key defaultValue:(id)defaultVal{
    NSString *path = [NSString stringWithFormat:@"/var/mobile/Library/Preferences/%@.plist", BAKGRUNNUR_IDENTIFIER];
    NSMutableDictionary *settings = [NSMutableDictionary dictionary];
    [settings addEntriesFromDictionary:[NSDictionary dictionaryWithContentsOfFile:path]];
    return (settings[key]) ?: defaultVal;
}

- (void)setPreferenceValue:(id)value forKey:(NSString *)key{
    NSString *path = [NSString stringWithFormat:@"/var/mobile/Library/Preferences/%@.plist", BAKGRUNNUR_IDENTIFIER];
    NSMutableDictionary *settings = [NSMutableDictionary dictionary];
    [settings addEntriesFromDictionary:[NSDictionary dictionaryWithContentsOfFile:path]];
    [settings setObject:value forKey:key];
    [settings writeToFile:path atomically:YES];
    CFStringRef notificationName = (__bridge CFStringRef)PREFS_CHANGED_NOTIFICATION_NAME;
    if (notificationName) {
        CFNotificationCenterPostNotification(CFNotificationCenterGetDarwinNotifyCenter(), notificationName, NULL, NULL, YES);
    }
}


- (void)viewDidLoad {
    [super viewDidLoad];
    
    self.tableView = [[UITableView alloc] initWithFrame:CGRectMake(0, 0, self.view.frame.size.width, self.view.frame.size.height) style:UITableViewStyleGrouped];
    self.tableView.delegate = self;
    self.tableView.dataSource = self;
    [self.tableView setAutoresizingMask:UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight];
    [self.tableView registerClass:[UITableViewCell class] forCellReuseIdentifier:@"BKGQuickActionsCell"];
    //[self.tableView setEditing:YES];
    [self.tableView setAllowsSelection:YES];
    self.tableView.allowsMultipleSelection = YES;
    //self.tableView.allowsSelectionDuringEditing=YES;
    
    self.title = @"Quick Actions";
    self.view = self.tableView;
}
@end
