#import "../common.h"
#import "BakgrunnurAppListController.h"
#import <AppList/AppList.h>

static NSMutableDictionary *prefs;
static NSString *searchTxt = @"";
static BOOL searching = NO;
static UISearchController *searchController;

@implementation BakgrunnurAppListController

-(void)searchBarTextDidBeginEditing:(UISearchBar *)searchBar {
    [searchBar setShowsCancelButton:YES animated:YES];
}

-(void)searchBarTextDidEndEditing:(UISearchBar *)searchBar {
    [searchBar setShowsCancelButton:NO animated:YES];
}

-(void)updateSearchResultsForSearchController:(UISearchController *)searchController{
    [self searchBar:searchController.searchBar textDidChange:searchController.searchBar.text];
}

-(void)searchBar:(UISearchBar *)searchBar textDidChange:(NSString *)searchText {
    if ([searchText length] > 0) {
        searching = YES;
        searchTxt = searchText;
    }else{
        searching = NO;
    }
    [self reloadSpecifiers];
}

-(void)searchBarCancelButtonClicked:(UISearchBar *)searchBar {
    searching = NO;
    [self reloadSpecifiers];
}


- (NSArray *)specifiers {
    if (!_specifiers) {
        
        NSMutableArray *appListSpecifiers = [[NSMutableArray alloc] init];
        
        ALApplicationList *appList = [ALApplicationList sharedApplicationList];
        
        
        //sort
        PSSpecifier *sortPriorityGroupSpec = [PSSpecifier preferenceSpecifierNamed:@"Sort Priority" target:nil set:nil get:nil detail:nil cell:PSGroupCell edit:nil];
        if (!searching){
            [appListSpecifiers addObject:sortPriorityGroupSpec];
        }
        
        PSSpecifier *sortPrioritySpec = [PSSpecifier preferenceSpecifierNamed:@"Retire" target:self set:@selector(setPreferenceValue:specifier:) get:@selector(readPreferenceValue:) detail:nil cell:PSSegmentCell edit:nil];
        [sortPrioritySpec setValues:@[@0, @1] titles:@[@"Alphabet", @"State"]];
        [sortPrioritySpec setProperty:@1 forKey:@"default"];
        [sortPrioritySpec setProperty:@"sortPriority" forKey:@"key"];
        [sortPrioritySpec setProperty:BAKGRUNNUR_IDENTIFIER forKey:@"defaults"];
        if (!searching){
            [appListSpecifiers addObject:sortPrioritySpec];
        }
        
        
        //system app group spec
        PSSpecifier *systemAppsGroupSpec = [PSSpecifier preferenceSpecifierNamed:@"System Applications" target:self set:nil get:nil detail:nil cell:PSGroupCell edit:nil];
        [appListSpecifiers addObject:systemAppsGroupSpec];
        
        //system apps
        NSDictionary *systemApps = [appList applicationsFilteredUsingPredicate:[NSPredicate predicateWithFormat:@"isSystemApplication = YES"] onlyVisible:YES titleSortedIdentifiers:nil];
        //NSSortDescriptor *sort = [NSSortDescriptor sortDescriptorWithKey:@"self" ascending:YES selector:@selector(localizedCaseInsensitiveCompare:)];
        
        NSArray *sortedBundleIdentifier = [systemApps keysSortedByValueUsingComparator:^NSComparisonResult(id obj1, id obj2){
            return [obj1 localizedCaseInsensitiveCompare:obj2];
        }];
        //NSArray *sortedDisplayName = [systemApps objectsForKeys:sortedBundleIdentifier notFoundMarker:[NSNull null]];
        
        if ([[self readPreferenceValue:sortPrioritySpec] intValue] == 1){
            NSMutableArray *statePriotizedBundleIdentifier = [[NSMutableArray alloc] init];
            NSMutableArray *statePriotizedBundleIdentifierDisabled = [[NSMutableArray alloc] init];
            for (NSString *priotizeBundleIdentifer in sortedBundleIdentifier){
                if ([self isBundleIdentifierEnabled:priotizeBundleIdentifer]){
                    [statePriotizedBundleIdentifier addObject:priotizeBundleIdentifer];
                }else{
                    [statePriotizedBundleIdentifierDisabled addObject:priotizeBundleIdentifer];
                }
            }
            sortedBundleIdentifier = [statePriotizedBundleIdentifier arrayByAddingObjectsFromArray:statePriotizedBundleIdentifierDisabled];
        }
        NSArray *sortedDisplayName = [systemApps objectsForKeys:sortedBundleIdentifier notFoundMarker:[NSNull null]];
        
        NSUInteger idx = 0;
        for (NSString *bundleIdentifier in sortedBundleIdentifier){
            
            if (searching){
                if (![[sortedDisplayName[idx] lowercaseString] containsString:[searchTxt lowercaseString]]){
                    idx++;
                    continue;
                }
            }
            
            PSSpecifier *appItemSpec = [PSSpecifier preferenceSpecifierNamed:sortedDisplayName[idx] target:self set:nil get:nil detail:NSClassFromString(@"BakgrunnurAppEntryController") cell:PSLinkCell edit:nil];
            UIImage *icon =  [[ALApplicationList sharedApplicationList] iconOfSize:ALApplicationIconSizeSmall forDisplayIdentifier:bundleIdentifier];;
            [appItemSpec setProperty:icon forKey:@"iconImage"];
            [appItemSpec setProperty:bundleIdentifier forKey:@"id"];
            [appListSpecifiers addObject:appItemSpec];
            idx++;
        }
        
        /*
        [systemApps enumerateKeysAndObjectsUsingBlock:^(NSString *bundleIdentifier, NSString *displayName, BOOL *stop) {
            PSSpecifier *appItemSpec = [PSSpecifier preferenceSpecifierNamed:displayName target:self set:nil get:nil detail:NSClassFromString(@"BakgrunnurAppEntryController") cell:PSLinkCell edit:nil];
            UIImage *icon =  [[ALApplicationList sharedApplicationList] iconOfSize:ALApplicationIconSizeSmall forDisplayIdentifier:bundleIdentifier];;
            [appItemSpec setProperty:icon forKey:@"iconImage"];
            [appItemSpec setProperty:bundleIdentifier forKey:@"id"];
            [appListSpecifiers addObject:appItemSpec];
        }];
        */
        
        //user app group spec
        PSSpecifier *userAppsGroupSpec = [PSSpecifier preferenceSpecifierNamed:@"User Applications" target:self set:nil get:nil detail:nil cell:PSGroupCell edit:nil];
        [appListSpecifiers addObject:userAppsGroupSpec];
        
        //user apps
        NSDictionary *userApps = [appList applicationsFilteredUsingPredicate:[NSPredicate predicateWithFormat:@"isSystemApplication = NO"] onlyVisible:YES titleSortedIdentifiers:nil];
        sortedBundleIdentifier = [userApps keysSortedByValueUsingComparator:^NSComparisonResult(id obj1, id obj2){
            return [obj1 localizedCaseInsensitiveCompare:obj2];
        }];
        
        if ([[self readPreferenceValue:sortPrioritySpec] intValue] == 1){
            NSMutableArray *statePriotizedBundleIdentifier = [[NSMutableArray alloc] init];
            NSMutableArray *statePriotizedBundleIdentifierDisabled = [[NSMutableArray alloc] init];
            for (NSString *priotizeBundleIdentifer in sortedBundleIdentifier){
                if ([self isBundleIdentifierEnabled:priotizeBundleIdentifer]){
                    [statePriotizedBundleIdentifier addObject:priotizeBundleIdentifer];
                }else{
                    [statePriotizedBundleIdentifierDisabled addObject:priotizeBundleIdentifer];
                }
            }
            sortedBundleIdentifier = [statePriotizedBundleIdentifier arrayByAddingObjectsFromArray:statePriotizedBundleIdentifierDisabled];
        }
        
        sortedDisplayName = [userApps objectsForKeys:sortedBundleIdentifier notFoundMarker:[NSNull null]];
        
        idx = 0;
        for (NSString *bundleIdentifier in sortedBundleIdentifier){
            
            if (searching){
                if (![[sortedDisplayName[idx] lowercaseString] containsString:[searchTxt lowercaseString]]){
                    idx++;
                    continue;
                }
            }
            
            PSSpecifier *appItemSpec = [PSSpecifier preferenceSpecifierNamed:sortedDisplayName[idx] target:self set:nil get:nil detail:NSClassFromString(@"BakgrunnurAppEntryController") cell:PSLinkCell edit:nil];
            UIImage *icon =  [[ALApplicationList sharedApplicationList] iconOfSize:ALApplicationIconSizeSmall forDisplayIdentifier:bundleIdentifier];;
            [appItemSpec setProperty:icon forKey:@"iconImage"];
            [appItemSpec setProperty:bundleIdentifier forKey:@"id"];
            [appListSpecifiers addObject:appItemSpec];
            idx++;
        }
        
        /*
        [userApps enumerateKeysAndObjectsUsingBlock:^(NSString *bundleIdentifier, NSString *displayName, BOOL *stop) {
            PSSpecifier *appItemSpec = [PSSpecifier preferenceSpecifierNamed:displayName target:self set:nil get:nil detail:NSClassFromString(@"BakgrunnurAppEntryController") cell:PSLinkCell edit:nil];
            UIImage *icon =  [[ALApplicationList sharedApplicationList] iconOfSize:ALApplicationIconSizeSmall forDisplayIdentifier:bundleIdentifier];;
            [appItemSpec setProperty:icon forKey:@"iconImage"];
            [appItemSpec setProperty:bundleIdentifier forKey:@"id"];
            [appListSpecifiers addObject:appItemSpec];
        }];
        */
        _specifiers = appListSpecifiers;
        
    }

	return _specifiers;
}

- (id)readPreferenceValue:(PSSpecifier*)specifier {
    NSString *path = [NSString stringWithFormat:@"/var/mobile/Library/Preferences/%@.plist", specifier.properties[@"defaults"]];
    NSMutableDictionary *settings = [NSMutableDictionary dictionary];
    [settings addEntriesFromDictionary:[NSDictionary dictionaryWithContentsOfFile:path]];
    return (settings[specifier.properties[@"key"]]) ?: specifier.properties[@"default"];
}

- (void)setPreferenceValue:(id)value specifier:(PSSpecifier*)specifier {
    NSString *path = [NSString stringWithFormat:@"/var/mobile/Library/Preferences/%@.plist", specifier.properties[@"defaults"]];
    NSMutableDictionary *settings = [NSMutableDictionary dictionary];
    [settings addEntriesFromDictionary:[NSDictionary dictionaryWithContentsOfFile:path]];
    [settings setObject:value forKey:specifier.properties[@"key"]];
    [settings writeToFile:path atomically:YES];
    CFStringRef notificationName = (__bridge CFStringRef)specifier.properties[@"PostNotification"];
    if (notificationName) {
        CFNotificationCenterPostNotification(CFNotificationCenterGetDarwinNotifyCenter(), notificationName, NULL, NULL, YES);
    }
     NSString *key = [specifier propertyForKey:@"key"];
       if ([key isEqualToString:@"sortPriority"]){
           [self reloadSpecifiers];
       }
}

-(NSDictionary *)getItem:(NSDictionary *)prefs ofIdentifier:(NSString *)snippetID forKey:(NSString *)keyName identifierKey:(NSString *)identifier completion:(void (^)(NSUInteger idx))handler{
    NSArray *arrayWithEventID = [prefs[keyName] valueForKey:identifier];
    //HBLogDebug(@"arrayWithEventID: %@", arrayWithEventID);
    NSUInteger index = [arrayWithEventID indexOfObject:snippetID];
    NSDictionary *snippet = index != NSNotFound ? prefs[keyName][index] : nil;
    if (handler){
        handler(index);
    }
    return snippet;
}

-(BOOL)isBundleIdentifierEnabled:(NSString *)bundleIdentifier{
    NSDictionary *item = [self getItem:prefs ofIdentifier:bundleIdentifier forKey:@"enabledIdentifier" identifierKey:@"identifier" completion:nil];
    //HBLogDebug(@"item %@", item);

    return item[@"enabled"] ? [item[@"enabled"] boolValue] : NO;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    PSTableCell *cell = (PSTableCell *)[super tableView:tableView cellForRowAtIndexPath:indexPath];

    if ([cell.specifier.identifier isEqualToString:@"sortPriority"]) return cell;
    
    BOOL isEnabled = [self isBundleIdentifierEnabled:cell.specifier.properties[@"id"]];
    cell.accessoryType = isEnabled ? 3 : 1;
    return cell;
}

-(void)viewWillAppear:(BOOL)animated{
    prefs = [NSMutableDictionary dictionary];
    [prefs addEntriesFromDictionary:[NSDictionary dictionaryWithContentsOfFile:PREFS_PATH]];
    HBLogDebug(@"prefs %@", prefs);
    [self reloadSpecifiers];
    [super viewWillAppear:animated];
}

- (void)viewDidLoad{
    [super viewDidLoad];

    searchController = [[UISearchController alloc] initWithSearchResultsController:nil];
    searchController.definesPresentationContext = YES;
    searchController.hidesNavigationBarDuringPresentation = YES;
    searchController.searchBar.delegate = self;
    searchController.searchBar.placeholder = @"Search Apps";
    
    if (@available(iOS 13.0, *)){
        searchController.dimsBackgroundDuringPresentation = NO;
    } else {
        searchController.obscuresBackgroundDuringPresentation = NO;
    }
    
    if (@available(iOS 11.0, *)){
        self.navigationItem.searchController = searchController;
        self.navigationItem.hidesSearchBarWhenScrolling = YES;
    }else{
        searchController.searchResultsUpdater = self;
        self.table.tableHeaderView   = searchController.searchBar;
    }
}

@end
