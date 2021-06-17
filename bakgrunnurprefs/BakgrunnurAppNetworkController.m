#import "../common.h"
#import "../BKGShared.h"
#import "BakgrunnurAppEntryController.h"
#import "BakgrunnurAppNetworkController.h"
#import "NSString+Regex.h"
#import "../NSTask.h"

@implementation BakgrunnurAppNetworkController

-(int)runCommand:(NSString *)cmd{
    if ([cmd length] != 0){
        NSMutableArray *taskArgs = [[NSMutableArray alloc] init];
        taskArgs = [NSMutableArray arrayWithObjects:@"-c", cmd, nil];
        NSTask * task = [[NSTask alloc] init];
        [task setLaunchPath:@"/bin/bash"];
        [task setArguments:taskArgs];
        NSPipe* outputPipe = [NSPipe pipe];
        task.standardOutput = outputPipe;
        [task launch];
        //NSData *data = [[outputPipe fileHandleForReading] readDataToEndOfFile];
        [task waitUntilExit];
        return [task terminationStatus];
    }
    return 0;
}

- (NSArray *)specifiers {
    if (!_specifiers) {
        
        self.identifier = [self.specifier.identifier stringByReplacingWithPattern:@"(.*)-bakgrunnur-.*-\\[(.*)\\]" withTemplate:@"$1" error:nil];
        self.appName = [self.specifier.identifier stringByReplacingWithPattern:@"(.*)-bakgrunnur-.*-\\[(.*)\\]" withTemplate:@"$2" error:nil];
        
        NSMutableArray *controllerSpecifiers = [[NSMutableArray alloc] init];
        
        if ([self runCommand:@"which netstat"] != 0){
            PSSpecifier *errorGroupSpec = [PSSpecifier preferenceSpecifierNamed:@"" target:nil set:nil get:nil detail:nil cell:PSGroupCell edit:nil];
            [errorGroupSpec setProperty:@"Oh no, support package for this feature to work not found (netstat). Try to install \"Network Commands\" (network-cmds) from package manager." forKey:@"footerText"];
            [errorGroupSpec setProperty:@1 forKey:@"footerAlignment"];
            [controllerSpecifiers addObject:errorGroupSpec];
            return _specifiers = controllerSpecifiers;
        }

        //network Transmission type selection
        PSSpecifier *networkGroupSpec = [PSSpecifier preferenceSpecifierNamed:@"Network" target:nil set:nil get:nil detail:nil cell:PSGroupCell edit:nil];
        [networkGroupSpec setProperty:[NSString stringWithFormat:@"Set the preferred network bandwidth type to be used for decision-making for retiring %@ within the preferred time span (s).", self.appName] forKey:@"footerText"];
        [controllerSpecifiers addObject:networkGroupSpec];
        
        PSSpecifier *networkTransmissionSelectionSpec = [PSSpecifier preferenceSpecifierNamed:@"Network Transmission Selection" target:self set:@selector(setPreferenceValue:specifier:) get:@selector(readPreferenceValue:) detail:nil cell:PSSegmentCell edit:nil];
        [networkTransmissionSelectionSpec setValues:@[@0, @1, @2, @3] titles:@[@"Disable", @"Download", @"Upload", @"Down+Up"]];
        [networkTransmissionSelectionSpec setProperty:@0 forKey:@"default"];
        [networkTransmissionSelectionSpec setProperty:@"networkTransmissionType" forKey:@"key"];
        [networkTransmissionSelectionSpec setProperty:BAKGRUNNUR_IDENTIFIER forKey:@"defaults"];
        [networkTransmissionSelectionSpec setProperty:PREFS_CHANGED_NOTIFICATION_NAME forKey:@"PostNotification"];
        self.networkTransmissionSelectionSpecifier = networkTransmissionSelectionSpec;
        [controllerSpecifiers addObject:networkTransmissionSelectionSpec];
        
        //network unit selection
        PSSpecifier *networkUnitGroupSpec = [PSSpecifier preferenceSpecifierNamed:@"Bandwidth" target:nil set:nil get:nil detail:nil cell:PSGroupCell edit:nil];
        [networkUnitGroupSpec setProperty:@"Network speed unit in *Bytes/s. Default is 0 *B/s. Note that the speed computed by Bakgrunnur is only an estimation." forKey:@"footerText"];
        [controllerSpecifiers addObject:networkUnitGroupSpec];
        
        PSSpecifier *networkUnitSelectionSpec = [PSSpecifier preferenceSpecifierNamed:@"Speed Unit Selection" target:self set:@selector(setPreferenceValue:specifier:) get:@selector(readPreferenceValue:) detail:nil cell:PSSegmentCell edit:nil];
        [networkUnitSelectionSpec setValues:@[@0, @1, @2, @3] titles:@[@"B/s", @"KB/s", @"MB/s", @"GB/s"]];
        [networkUnitSelectionSpec setProperty:@2 forKey:@"default"];
        [networkUnitSelectionSpec setProperty:@"networkTransmissionUnit" forKey:@"key"];
        [networkUnitSelectionSpec setProperty:BAKGRUNNUR_IDENTIFIER forKey:@"defaults"];
        [networkUnitSelectionSpec setProperty:PREFS_CHANGED_NOTIFICATION_NAME forKey:@"PostNotification"];
        self.networkUnitSelectionSpecifier = networkUnitSelectionSpec;
        [controllerSpecifiers addObject:networkUnitSelectionSpec];
        
        //Download
        PSTextFieldSpecifier* rxbytesSpec = [PSTextFieldSpecifier preferenceSpecifierNamed:@"Download" target:self set:@selector(setPreferenceValue:specifier:) get:@selector(readPreferenceValue:) detail:nil cell:PSEditTextCell edit:nil];
        [rxbytesSpec setKeyboardType:UIKeyboardTypeDecimalPad autoCaps:UITextAutocapitalizationTypeNone autoCorrection:UITextAutocorrectionTypeNo];
        [rxbytesSpec setPlaceholder:@"0"];
        [rxbytesSpec setProperty:@"rxbytesThreshold" forKey:@"key"];
        [rxbytesSpec setProperty:BAKGRUNNUR_IDENTIFIER forKey:@"defaults"];
        [rxbytesSpec setProperty:@"Download" forKey:@"label"];
        [rxbytesSpec setProperty:PREFS_CHANGED_NOTIFICATION_NAME forKey:@"PostNotification"];
        self.rxbytesSpecifier = rxbytesSpec;
        [controllerSpecifiers addObject:rxbytesSpec];
        
        //Upload
        PSTextFieldSpecifier* txbytesSpec = [PSTextFieldSpecifier preferenceSpecifierNamed:@"Upload" target:self set:@selector(setPreferenceValue:specifier:) get:@selector(readPreferenceValue:) detail:nil cell:PSEditTextCell edit:nil];
        [txbytesSpec setKeyboardType:UIKeyboardTypeDecimalPad autoCaps:UITextAutocapitalizationTypeNone autoCorrection:UITextAutocorrectionTypeNo];
        [txbytesSpec setPlaceholder:@"0"];
        [txbytesSpec setProperty:@"txbytesThreshold" forKey:@"key"];
        [txbytesSpec setProperty:BAKGRUNNUR_IDENTIFIER forKey:@"defaults"];
        [txbytesSpec setProperty:@"Upload" forKey:@"label"];
        [txbytesSpec setProperty:PREFS_CHANGED_NOTIFICATION_NAME forKey:@"PostNotification"];
        self.txbytesSpecifier = txbytesSpec;
        [controllerSpecifiers addObject:txbytesSpec];
        
        _specifiers = controllerSpecifiers;
        
        
    }
    
    return _specifiers;
}

- (id)readPreferenceValue:(PSSpecifier*)specifier {
    NSString *key = [specifier propertyForKey:@"key"];
    id value = valueForConfigKey(self.identifier, key, specifier.properties[@"default"]);
    if ([key isEqualToString:@"networkTransmissionType"]){
        switch ([value intValue]) {
            case 0:{
                [self.rxbytesSpecifier setProperty:@NO forKey:@"enabled"];
                [self.txbytesSpecifier setProperty:@NO forKey:@"enabled"];
                [self.networkUnitSelectionSpecifier setProperty:@NO forKey:@"enabled"];
                break;
            }case 1:{
                [self.rxbytesSpecifier setProperty:@YES forKey:@"enabled"];
                [self.txbytesSpecifier setProperty:@YES forKey:@"enabled"];
                [self.networkUnitSelectionSpecifier setProperty:@NO forKey:@"enabled"];
                break;
            }case 2:{
                [self.rxbytesSpecifier setProperty:@NO forKey:@"enabled"];
                [self.txbytesSpecifier setProperty:@YES forKey:@"enabled"];
                [self.networkUnitSelectionSpecifier setProperty:@YES forKey:@"enabled"];
                break;
            }case 3:{
                [self.rxbytesSpecifier setProperty:@YES forKey:@"enabled"];
                [self.txbytesSpecifier setProperty:@YES forKey:@"enabled"];
                [self.networkUnitSelectionSpecifier setProperty:@YES forKey:@"enabled"];
                break;
            }
            default:
                break;
        }
        
        [self reloadSpecifier:self.rxbytesSpecifier animated:YES];
        [self reloadSpecifier:self.txbytesSpecifier animated:YES];
        [self reloadSpecifier:self.networkUnitSelectionSpecifier animated:YES];
        
    }
    return value;
    
}

-(void)updateParentViewController{
    UIViewController *parentController = (UIViewController *)[self valueForKey:@"_parentController"];
    if ([parentController respondsToSelector:@selector(updateParentViewController)]){
        [(BakgrunnurAppEntryController *)parentController updateParentViewController];
    }
}

- (void)setPreferenceValue:(id)value specifier:(PSSpecifier*)specifier {
    
    NSString *key = [specifier propertyForKey:@"key"];
    if ([key isEqualToString:@"networkTransmissionType"]){
        switch ([value intValue]) {
            case 0:{
                [self.rxbytesSpecifier setProperty:@NO forKey:@"enabled"];
                [self.txbytesSpecifier setProperty:@NO forKey:@"enabled"];
                [self.networkUnitSelectionSpecifier setProperty:@NO forKey:@"enabled"];
                break;
            }case 1:{
                [self.rxbytesSpecifier setProperty:@YES forKey:@"enabled"];
                [self.txbytesSpecifier setProperty:@NO forKey:@"enabled"];
                [self.networkUnitSelectionSpecifier setProperty:@YES forKey:@"enabled"];
                break;
            }case 2:{
                [self.rxbytesSpecifier setProperty:@NO forKey:@"enabled"];
                [self.txbytesSpecifier setProperty:@YES forKey:@"enabled"];
                [self.networkUnitSelectionSpecifier setProperty:@YES forKey:@"enabled"];
                break;
            }case 3:{
                [self.rxbytesSpecifier setProperty:@YES forKey:@"enabled"];
                [self.txbytesSpecifier setProperty:@YES forKey:@"enabled"];
                [self.networkUnitSelectionSpecifier setProperty:@YES forKey:@"enabled"];
                break;
            }
            default:
                break;
        }
        
        [self reloadSpecifier:self.rxbytesSpecifier animated:YES];
        [self reloadSpecifier:self.txbytesSpecifier animated:YES];
        [self reloadSpecifier:self.networkUnitSelectionSpecifier animated:YES];
        
    }
    setValueForConfigKey(self.identifier, key, value);
    
    if ([key isEqualToString:@"networkTransmissionType"]){
        [self updateParentViewController];
    }
}

-(void)loadView {
    [super loadView];
    ((UITableView *)[self table]).keyboardDismissMode = UIScrollViewKeyboardDismissModeOnDrag;
}

-(void)_returnKeyPressed:(id)arg1 {
    [self.view endEditing:YES];
}
@end
