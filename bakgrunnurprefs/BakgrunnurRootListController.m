#import "../common.h"
#import "../BKGShared.h"
#include "BakgrunnurRootListController.h"
#import "../SpringBoard.h"
#import "../NSTask.h"

@implementation BakgrunnurRootListController

void refreshEnabledSwitch() {
    [[NSNotificationCenter defaultCenter] postNotificationName:RELOAD_SPECIFIERS_LOCAL_NOTIFICATION_NAME object:nil];
}

- (instancetype)init{
    if ((self = [super init])) {
        CFNotificationCenterAddObserver(CFNotificationCenterGetDarwinNotifyCenter(), NULL, (CFNotificationCallback)refreshEnabledSwitch, (CFStringRef)RELOAD_SPECIFIERS_NOTIFICATION_NAME, NULL, CFNotificationSuspensionBehaviorDeliverImmediately);
        
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(refreshSpecifiers:) name:RELOAD_SPECIFIERS_LOCAL_NOTIFICATION_NAME object:nil];
    }
    return self;
}

- (void)refreshSpecifiers:(NSNotification *)notification{
    [self reloadSpecifiers];
}

- (NSArray *)specifiers {
    if (!_specifiers) {
        NSMutableArray *rootSpecifiers = [[NSMutableArray alloc] init];
        
        //Tweak
        PSSpecifier *tweakEnabledGroupSpec = [PSSpecifier preferenceSpecifierNamed:@"Tweak" target:nil set:nil get:nil detail:nil cell:PSGroupCell edit:nil];
        [tweakEnabledGroupSpec setProperty:@"No respring is required for changing this, it'll take effect whenever the app is launched or reactivated." forKey:@"footerText"];
        [rootSpecifiers addObject:tweakEnabledGroupSpec];
        
        PSSpecifier *tweakEnabledSpec = [PSSpecifier preferenceSpecifierNamed:@"Enabled" target:self set:@selector(setPreferenceValue:specifier:) get:@selector(readPreferenceValue:) detail:nil cell:PSSwitchCell edit:nil];
        [tweakEnabledSpec setProperty:@"Enabled" forKey:@"label"];
        [tweakEnabledSpec setProperty:@"enabled" forKey:@"key"];
        [tweakEnabledSpec setProperty:@YES forKey:@"default"];
        [tweakEnabledSpec setProperty:BAKGRUNNUR_IDENTIFIER forKey:@"defaults"];
        [tweakEnabledSpec setProperty:PREFS_CHANGED_NOTIFICATION_NAME forKey:@"PostNotification"];
        [rootSpecifiers addObject:tweakEnabledSpec];
        
        //blank
        PSSpecifier *blankSpecGroup = [PSSpecifier preferenceSpecifierNamed:@"" target:self set:nil get:nil detail:nil cell:PSGroupCell edit:nil];
        [rootSpecifiers addObject:blankSpecGroup];
        
        //Manage Apps
        PSSpecifier *altListSpec = [PSSpecifier preferenceSpecifierNamed:@"Manage Apps" target:nil set:@selector(setPreferenceValue:specifier:) get:@selector(readPreferenceValue:) detail:NSClassFromString(@"BakgrunnurApplicationListSubcontrollerController") cell:PSLinkListCell edit:nil];
        [altListSpec setProperty:@"BakgrunnurAppEntryController" forKey:@"subcontrollerClass"];
        [altListSpec setProperty:@"Manage Apps" forKey:@"label"];
        NSString *sectionType = boolValueForKey(@"showHiddenApps", NO) ? @"All" : @"Visible";
        [altListSpec setProperty:@[
            @{@"sectionType":sectionType},
        ] forKey:@"sections"];
        [altListSpec setProperty:@YES forKey:@"useSearchBar"];
        [altListSpec setProperty:@YES forKey:@"hideSearchBarWhileScrolling"];
        [altListSpec setProperty:@YES forKey:@"alphabeticIndexingEnabled"];
        [altListSpec setProperty:@YES forKey:@"showIdentifiersAsSubtitle"];
        [altListSpec setProperty:@YES forKey:@"includeIdentifiersInSearch"];
        [rootSpecifiers addObject:altListSpec];
        
        //accessory type
        PSSpecifier *homescreenGroupSpec = [PSSpecifier preferenceSpecifierNamed:@"Homescreen" target:nil set:nil get:nil detail:nil cell:PSGroupCell edit:nil];
        [homescreenGroupSpec setProperty:@"Set the indicator on homescreen when app is backgrounding. If dot is preferred, newly installed or recently updated apps' native dot will be overriden to hide." forKey:@"footerText"];
        [rootSpecifiers addObject:homescreenGroupSpec];
        
        PSSpecifier *preferredAccessoryTypeSelectionSpec = [PSSpecifier preferenceSpecifierNamed:@"Retire" target:self set:@selector(setPreferenceValue:specifier:) get:@selector(readPreferenceValue:) detail:nil cell:PSSegmentCell edit:nil];
        [preferredAccessoryTypeSelectionSpec setValues:@[@0, @2, @4] titles:@[@"Disable", @"Dot", @"Sandglass"]];
        [preferredAccessoryTypeSelectionSpec setProperty:@2 forKey:@"default"];
        [preferredAccessoryTypeSelectionSpec setProperty:@"preferredAccessoryType" forKey:@"key"];
        [preferredAccessoryTypeSelectionSpec setProperty:BAKGRUNNUR_IDENTIFIER forKey:@"defaults"];
        [preferredAccessoryTypeSelectionSpec setProperty:PREFS_CHANGED_NOTIFICATION_NAME forKey:@"PostNotification"];
        [rootSpecifiers addObject:preferredAccessoryTypeSelectionSpec];
        
        //dock
        PSSpecifier *showIndicatorOnDockSpec = [PSSpecifier preferenceSpecifierNamed:@"Dock Indicator" target:self set:@selector(setPreferenceValue:specifier:) get:@selector(readPreferenceValue:) detail:nil cell:PSSwitchCell edit:nil];
        [showIndicatorOnDockSpec setProperty:@"Dock Indicator" forKey:@"label"];
        [showIndicatorOnDockSpec setProperty:@"showIndicatorOnDock" forKey:@"key"];
        [showIndicatorOnDockSpec setProperty:@YES forKey:@"default"];
        [showIndicatorOnDockSpec setProperty:BAKGRUNNUR_IDENTIFIER forKey:@"defaults"];
        [showIndicatorOnDockSpec setProperty:PREFS_CHANGED_NOTIFICATION_NAME forKey:@"PostNotification"];
        [rootSpecifiers addObject:showIndicatorOnDockSpec];
        
        /*
        //force touch shortcut
        PSSpecifier *forceTouchShortcutGroupSpec = [PSSpecifier preferenceSpecifierNamed:@"" target:nil set:nil get:nil detail:nil cell:PSGroupCell edit:nil];
        [forceTouchShortcutGroupSpec setProperty:@"Show shortcut for enabling or disabling Bakgrunnur for each individual app via quick actions menu in homescreen." forKey:@"footerText"];
        [rootSpecifiers addObject:forceTouchShortcutGroupSpec];
        
        PSSpecifier *forceTouchShortcutSpec = [PSSpecifier preferenceSpecifierNamed:@"Quick Action" target:self set:@selector(setPreferenceValue:specifier:) get:@selector(readPreferenceValue:) detail:nil cell:PSSwitchCell edit:nil];
        [forceTouchShortcutSpec setProperty:@"Quick Action" forKey:@"label"];
        [forceTouchShortcutSpec setProperty:@"showForceTouchShortcut" forKey:@"key"];
        [forceTouchShortcutSpec setProperty:@YES forKey:@"default"];
        [forceTouchShortcutSpec setProperty:BAKGRUNNUR_IDENTIFIER forKey:@"defaults"];
         [forceTouchShortcutSpec setProperty:PREFS_CHANGED_NOTIFICATION_NAME forKey:@"PostNotification"];
         [rootSpecifiers addObject:forceTouchShortcutSpec];
         */
        
        //force touch shortcut
        PSSpecifier *forceTouchShortcutGroupSpec = [PSSpecifier preferenceSpecifierNamed:@"" target:nil set:nil get:nil detail:nil cell:PSGroupCell edit:nil];
        [forceTouchShortcutGroupSpec setProperty:@"Show shortcuts for enabling or disabling Bakgrunnur for each individual app via quick actions menu in homescreen." forKey:@"footerText"];
        [rootSpecifiers addObject:forceTouchShortcutGroupSpec];
        
        PSSpecifier *forceTouchShortcutSpec = [PSSpecifier preferenceSpecifierNamed:@"Quick Actions" target:nil set:nil get:nil detail:NSClassFromString(@"BakgrunnurQuickActionsController") cell:PSLinkCell edit:nil];
        [rootSpecifiers addObject:forceTouchShortcutSpec];
        
        //banner
        if (@available(iOS 14.0, *)){
            [rootSpecifiers addObject:blankSpecGroup];

            PSSpecifier *presentBannerSpec = [PSSpecifier preferenceSpecifierNamed:@"Banners" target:self set:@selector(setPreferenceValue:specifier:) get:@selector(readPreferenceValue:) detail:nil cell:PSSwitchCell edit:nil];
            [presentBannerSpec setProperty:@"Banners" forKey:@"label"];
            [presentBannerSpec setProperty:@"presentBanner" forKey:@"key"];
            [presentBannerSpec setProperty:@YES forKey:@"default"];
            [presentBannerSpec setProperty:BAKGRUNNUR_IDENTIFIER forKey:@"defaults"];
            [presentBannerSpec setProperty:PREFS_CHANGED_NOTIFICATION_NAME forKey:@"PostNotification"];
            [rootSpecifiers addObject:presentBannerSpec];
        }
        
        //Advanced
        PSSpecifier *advancedGroupSpec = [PSSpecifier preferenceSpecifierNamed:@"" target:nil set:nil get:nil detail:nil cell:PSGroupCell edit:nil];
        [rootSpecifiers addObject:advancedGroupSpec];
        
        PSSpecifier *advancedSpec = [PSSpecifier preferenceSpecifierNamed:@"Advanced" target:nil set:nil get:nil detail:NSClassFromString(@"BakgrunnutAdvancedController") cell:PSLinkCell edit:nil];
        [rootSpecifiers addObject:advancedSpec];
        
        //reset
        PSSpecifier *resetGroupSpec = [PSSpecifier preferenceSpecifierNamed:@"" target:nil set:nil get:nil detail:nil cell:PSGroupCell edit:nil];
        [resetGroupSpec setProperty:@"Reset everything to default." forKey:@"footerText"];
        [rootSpecifiers addObject:resetGroupSpec];
        
        PSSpecifier *resetSpec = [PSSpecifier preferenceSpecifierNamed:@"Reset" target:self set:nil get:nil detail:nil cell:PSButtonCell edit:nil];
        [resetSpec setProperty:@"Reset" forKey:@"label"];
        [resetSpec setButtonAction:@selector(reset)];
        [rootSpecifiers addObject:resetSpec];
        
        //blsnk group
        [rootSpecifiers addObject:blankSpecGroup];
        
        //Support Dev
        PSSpecifier *supportDevGroupSpec = [PSSpecifier preferenceSpecifierNamed:@"Development" target:nil set:nil get:nil detail:nil cell:PSGroupCell edit:nil];
        [rootSpecifiers addObject:supportDevGroupSpec];
        
        PSSpecifier *supportDevSpec = [PSSpecifier preferenceSpecifierNamed:@"Support Development" target:self set:nil get:nil detail:nil cell:PSButtonCell edit:nil];
        [supportDevSpec setProperty:@"Support Development" forKey:@"label"];
        [supportDevSpec setButtonAction:@selector(donation)];
        [supportDevSpec setProperty:[UIImage imageWithContentsOfFile:@"/Library/PreferenceBundles/BakgrunnurPrefs.bundle/PayPal.png"] forKey:@"iconImage"];
        [rootSpecifiers addObject:supportDevSpec];
        
        
        //Contact
        PSSpecifier *contactGroupSpec = [PSSpecifier preferenceSpecifierNamed:@"Contact" target:nil set:nil get:nil detail:nil cell:PSGroupCell edit:nil];
        [rootSpecifiers addObject:contactGroupSpec];
        
        //Twitter
        PSSpecifier *twitterSpec = [PSSpecifier preferenceSpecifierNamed:@"Twitter" target:self set:nil get:nil detail:nil cell:PSButtonCell edit:nil];
        [twitterSpec setProperty:@"Twitter" forKey:@"label"];
        [twitterSpec setButtonAction:@selector(twitter)];
        [twitterSpec setProperty:[UIImage imageWithContentsOfFile:@"/Library/PreferenceBundles/BakgrunnurPrefs.bundle/Twitter.png"] forKey:@"iconImage"];
        [rootSpecifiers addObject:twitterSpec];
        
        //Reddit
        PSSpecifier *redditSpec = [PSSpecifier preferenceSpecifierNamed:@"Reddit" target:self set:nil get:nil detail:nil cell:PSButtonCell edit:nil];
        [redditSpec setProperty:@"Twitter" forKey:@"label"];
        [redditSpec setButtonAction:@selector(reddit)];
        [redditSpec setProperty:[UIImage imageWithContentsOfFile:@"/Library/PreferenceBundles/BakgrunnurPrefs.bundle/Reddit.png"] forKey:@"iconImage"];
        [rootSpecifiers addObject:redditSpec];
        
        //udevs
        PSSpecifier *createdByGroupSpec = [PSSpecifier preferenceSpecifierNamed:@"" target:nil set:nil get:nil detail:nil cell:PSGroupCell edit:nil];
        [createdByGroupSpec setProperty:@"Created by udevs" forKey:@"footerText"];
        [createdByGroupSpec setProperty:@1 forKey:@"footerAlignment"];
        [rootSpecifiers addObject:createdByGroupSpec];
        
        _specifiers = rootSpecifiers;
        
        
    }
    
    return _specifiers;
}

-(id)readPreferenceValue:(PSSpecifier*)specifier{
    NSString *key = [specifier propertyForKey:@"key"];
    id value = valueForKey(key, specifier.properties[@"default"]);
    return value;
}

-(void)setPreferenceValue:(id)value specifier:(PSSpecifier*)specifier{
    setValueForKey([specifier propertyForKey:@"key"], value);
    CFStringRef notificationName = (__bridge CFStringRef)specifier.properties[@"PostNotification"];
    if (notificationName) {
        CFNotificationCenterPostNotification(CFNotificationCenterGetDarwinNotifyCenter(), notificationName, NULL, NULL, YES);
    }
    if ([specifier.properties[@"key"] isEqualToString:@"enabled"]){
        CFNotificationCenterPostNotification(CFNotificationCenterGetDarwinNotifyCenter(), (CFStringRef)REFRESH_MODULE_NOTIFICATION_NAME, NULL, NULL, YES);
        
    }
}

-(void)viewDidLoad  {
    [super viewDidLoad];
    
    
    CGRect frame = CGRectMake(0,0,self.table.bounds.size.width,170);
    CGRect Imageframe = CGRectMake(0,10,self.table.bounds.size.width,80);
    
    
    UIView *headerView = [[UIView alloc] initWithFrame:frame];
    headerView.backgroundColor = [UIColor colorWithRed: 1.00 green: 0.29 blue: 0.61 alpha: 1.00];
    
    
    UIImage *headerImage = [[UIImage alloc]
                            initWithContentsOfFile:[[NSBundle bundleWithPath:@"/Library/PreferenceBundles/BakgrunnurPrefs.bundle"] pathForResource:@"Bakgrunnur512" ofType:@"png"]];
    UIImageView *imageView = [[UIImageView alloc] initWithFrame:Imageframe];
    [imageView setImage:headerImage];
    [imageView setContentMode:UIViewContentModeScaleAspectFit];
    [imageView setAutoresizingMask:UIViewAutoresizingFlexibleWidth];
    [headerView addSubview:imageView];
    
    CGRect labelFrame = CGRectMake(0,imageView.frame.origin.y + 90 ,self.table.bounds.size.width,80);
    UIFont *font = [UIFont fontWithName:@"HelveticaNeue-Light" size:40];
    UILabel *headerLabel = [[UILabel alloc] initWithFrame:labelFrame];
    [headerLabel setText:@"Bakgrunnur"];
    [headerLabel setFont:font];
    [headerLabel setTextColor:[UIColor blackColor]];
    headerLabel.textAlignment = NSTextAlignmentCenter;
    [headerLabel setContentMode:UIViewContentModeScaleAspectFit];
    [headerLabel setAutoresizingMask:UIViewAutoresizingFlexibleWidth];
    [headerView addSubview:headerLabel];
    
    self.table.tableHeaderView = headerView;
    
    self.respringBtn = [[UIBarButtonItem alloc] initWithTitle:@"Respring" style:UIBarButtonItemStylePlain target:self action:@selector(respring)];
    self.navigationItem.rightBarButtonItem = self.respringBtn;
}

-(void)reset{
    
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"Bakgrunnur" message:@"Reset everything back to default?" preferredStyle:UIAlertControllerStyleAlert];
    
    UIAlertAction *yesAction = [UIAlertAction actionWithTitle:@"Yes" style:UIAlertActionStyleDefault handler:^(UIAlertAction *action) {
        NSError *error = nil;
        [[NSFileManager defaultManager] removeItemAtPath:PREFS_PATH error:&error];
        if ((error != nil || error != NULL) && [[NSFileManager defaultManager] fileExistsAtPath:PREFS_PATH]){
            UIAlertController *alertFailed = [UIAlertController alertControllerWithTitle:@"Bakgrunnur" message:[NSString stringWithFormat:@"Failed to reset. %@", error.localizedDescription] preferredStyle:UIAlertControllerStyleAlert];
            UIAlertAction *okAction = [UIAlertAction actionWithTitle:@"Ok" style:UIAlertActionStyleDefault handler:^(UIAlertAction *action) {
            }];
            [alertFailed addAction:okAction];
            
            [self presentViewController:alertFailed animated:YES completion:nil];
            
        }else{
            [self reloadSpecifiers];
            CFNotificationCenterPostNotification(CFNotificationCenterGetDarwinNotifyCenter(), (CFStringRef)PREFS_CHANGED_NOTIFICATION_NAME, NULL, NULL, YES);
            CFNotificationCenterPostNotification(CFNotificationCenterGetDarwinNotifyCenter(), (CFStringRef)REFRESH_MODULE_NOTIFICATION_NAME, NULL, NULL, YES);
            CFNotificationCenterPostNotification(CFNotificationCenterGetDarwinNotifyCenter(), (CFStringRef)RESET_ALL_NOTIFICATION_NAME, NULL, NULL, YES);

        }
    }];
    
    UIAlertAction *noAction = [UIAlertAction actionWithTitle:@"No" style:UIAlertActionStyleCancel handler:^(UIAlertAction *action) {
    }];
    
    [alert addAction:yesAction];
    [alert addAction:noAction];
    
    [self presentViewController:alert animated:YES completion:nil];
    
    
    
}

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

- (void)respring {
    
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"Bakgrunnur" message:@"Respring is not necessary, respring anyway?" preferredStyle:UIAlertControllerStyleAlert];
    
    UIAlertAction *yesAction = [UIAlertAction actionWithTitle:@"Yes" style:UIAlertActionStyleDefault handler:^(UIAlertAction *action) {
        [self runCommand:@"/usr/bin/bkg --privatekillbkgd"];
        NSURL *relaunchURL = [NSURL URLWithString:@"prefs:root=Bakgrunnur"];
        SBSRelaunchAction *restartAction = [NSClassFromString(@"SBSRelaunchAction") actionWithReason:@"RestartRenderServer" options:4 targetURL:relaunchURL];
        [[NSClassFromString(@"FBSSystemService") sharedService] sendActions:[NSSet setWithObject:restartAction] withResult:nil];
    }];
    
    UIAlertAction *noAction = [UIAlertAction actionWithTitle:@"No" style:UIAlertActionStyleCancel handler:^(UIAlertAction *action) {
    }];
    
    [alert addAction:yesAction];
    [alert addAction:noAction];
    
    [self presentViewController:alert animated:YES completion:nil];
    
}

- (void)donation {
    [[UIApplication sharedApplication] openURL:[NSURL URLWithString:@"https://www.paypal.me/udevs"] options:@{} completionHandler:nil];
}

- (void)twitter {
    [[UIApplication sharedApplication] openURL:[NSURL URLWithString:@"https://twitter.com/udevs9"] options:@{} completionHandler:nil];
}

- (void)reddit {
    [[UIApplication sharedApplication] openURL:[NSURL URLWithString:@"https://www.reddit.com/user/h4roldj"] options:@{} completionHandler:nil];
}
@end
