#import <stdio.h>
#import <getopt.h>
#import "../common.h"
#import "../NSTask.h"

#define NSLog(FORMAT, ...) fprintf(stdout, "%s\n", [[NSString stringWithFormat:FORMAT, ##__VA_ARGS__] UTF8String]);

void display_usage(){
    fprintf(stderr,
            "Usage: bkg [parameters...]\n"
            "       -i, --identifier: process identifier\n"
            "       -a, --add: add into backgrounding list\n"
            "                  new parameters will be merged while keeping old parameters\n"
            "                  use -f to force as new entry\n"
            "       -d, --delete: delete from backgrounding list\n"
            "       -f, --force: force adding new entry by overrding old entry of the\n"
            "                    same identifier\n"
            "       -e, --expire: time (seconds) for process to remains active\n"
            "                     this value will be reset each time the process\n"
            "                     is on foreground. Default is 3 hours.\n"
            "       -r, --retire: retire backgrounding process\n"
            "                     process will become inactive grcefully\n"
            "                     will be overidden if process active again\n"
            "       -R, --remove: remove backgrounding process\n"
            "                     process will be instantly killed\n"
            "                     safest choice to kill a process\n"
            "       -t, --time: custom retiring time (milliseconds) for specified identifier\n"
            "                   default is one year\n"
            "       -m, --mode: backgrouding mode\n"
            "                   1-None\n"
            "                   2-Background\n"
            "                   3-LaunchTAL\n"
            "                   4-NonUserInteractive\n"
            "                   5-UserInteractiveNonFocal (default)\n"
            "                   6-UserInteractive\n"
            "                   7-UserInteractiveFocal\n"
            "       -n, --resist: resistance for termination\n"
            "                     1-None\n"
            "                     2-NonInteractive\n"
            "                     3-Interactive (default)\n"
            "       -s, --state: backgrounding state\n"
            "                    1-none\n"
            "                    2-running\n"
            "                    3-running-suspended\n"
            "                    4-running-active (default)\n"
            "       -E, --enable: enable tweak\n"
            "       -D, --disable: disable tweak\n"
            "       -h, --help: show this help message\n"
            );
    exit(-1);
}

void elevateAsRoot(){
    setuid(0);
    if (getuid() != 0) {
        NSLog(@"%@", @"Failed to elevate as root. Exit.");
        exit(1);
    }
}

void runCommand(NSString *cmd){
    if ([cmd length] != 0){

        NSMutableArray *taskArgs = [[NSMutableArray alloc] init];
        taskArgs = [NSMutableArray arrayWithObjects:@"-c", cmd, nil];
        NSTask * task = [[NSTask alloc] init];
        [task setLaunchPath:@"/bin/bash"];
        [task setArguments:taskArgs];
        [task launch];
    }
}

int main(int argc, char *argv[], char *envp[]) {
    if (argc <= 1) display_usage();

    int mandatoryArgsCount = 0;
    int expectedmandatoryArgsCount = 1;
    
    extern char *optarg;
    extern int optind;
    
    static struct option longopts[] = {
        { "identifier", required_argument, 0, 'i' },
        { "add", no_argument, 0, 'a' },
        { "remove", no_argument, 0, 'r'},
        { "delete", no_argument, 0, 'd'},
        { "force", no_argument, 0, 'f'},
        { "enable", no_argument, 0, 'E'},
        { "disable", no_argument, 0, 'D'},
        { "expire", required_argument, 0, 'e'},
        { "time", required_argument, 0, 't'},
        { "mode", required_argument, 0, 'm'},
        { "resist", required_argument, 0, 'n'},
        { "state", required_argument, 0, 's'},
        { "help", no_argument, 0, 'h'},
        { 0, 0, 0, 0 }
    };
    
    NSMutableDictionary *identifierDict = [[NSMutableDictionary alloc] init];
    BOOL addNewEntry = NO;
    BOOL deleteEntry = NO;
    BOOL enabled = NO;
    BOOL tweakToggling = NO;
    BOOL forceNewEntry = NO;
    
    int opt;
    while ((opt = getopt_long(argc, argv, "i:adrEDRm:n:s:e:hf", longopts, NULL)) != -1){
        switch (opt){
            case 'i':
                identifierDict[@"identifier"] = [NSString stringWithCString:optarg encoding:NSUTF8StringEncoding];
                mandatoryArgsCount += 1;
                break;
            case 'a':
                addNewEntry = YES;
                break;
            case 'f':
                forceNewEntry = YES;
                break;
            case 'r':
                identifierDict[@"retire"] = @YES;
                break;
            case 'R':
                identifierDict[@"remove"] = @YES;
                break;
            case 'e':
                identifierDict[@"expiration"] = @([[NSString stringWithCString:optarg encoding:NSUTF8StringEncoding] doubleValue]);
                break;
            case 'd':
                deleteEntry = YES;
                break;
            case 'E':
                enabled = YES;
                tweakToggling = YES;
                mandatoryArgsCount += 1;
                break;
            case 'D':
                enabled = NO;
                tweakToggling = YES;
                mandatoryArgsCount += 1;
                break;
            case 'm':
                identifierDict[@"mode"] = @([[NSString stringWithCString:optarg encoding:NSUTF8StringEncoding] intValue]);
                break;
            case 'n':
                identifierDict[@"resistance"] = @([[NSString stringWithCString:optarg encoding:NSUTF8StringEncoding] intValue]);
                break;
            case 's':
                identifierDict[@"taskState"] = @([[NSString stringWithCString:optarg encoding:NSUTF8StringEncoding] intValue]);
                break;
            default:
                display_usage();
        }
    }
    if (mandatoryArgsCount < expectedmandatoryArgsCount){
        NSLog(@"Not enough input arguments, -i needs to be specified");
        display_usage();
    }
    
    if (addNewEntry && deleteEntry){
        NSLog(@"-a can't be specified together with -d");
        return 1;
    }
    
    if (addNewEntry && !identifierDict[@"retire"] && !identifierDict[@"remove"]){
        identifierDict[@"retire"] = @YES;
    }else if (addNewEntry && !identifierDict[@"retire"] && identifierDict[@"remove"]){
        identifierDict[@"retire"] = @NO;
    }
    
    if (identifierDict[@"retire"] && identifierDict[@"remove"]){
        NSLog(@"-r and -R can't be specified together")
        return 1;
    }
    
    NSMutableDictionary *prefs = nil;
    NSData *data = [NSData dataWithContentsOfFile:kPrefsPath];
    if(data) {
        prefs = [[NSPropertyListSerialization propertyListWithData:data options:0 format:nil error:nil] mutableCopy];
    } else{
        prefs = [@{} mutableCopy];
    }
    
    elevateAsRoot();

    if (tweakToggling){
        prefs[@"enabled"] = @(enabled);
        [prefs writeToFile:kPrefsPath atomically:NO];
        //runCommand(@"killall -9 runningboardd");
        CFNotificationCenterPostNotification(CFNotificationCenterGetDarwinNotifyCenter(), (CFStringRef)kPrefsChangedIdentifier, NULL, NULL, YES);
        return 0;
    }
    
    if (deleteEntry){
        NSArray *array = [prefs[@"enabledIdentifier"] valueForKey:@"identifier"];
        NSUInteger idx = [array indexOfObject:identifierDict[@"identifier"]];
        if (idx != NSNotFound){
            [prefs[@"enabledIdentifier"] removeObjectAtIndex:idx];
            [prefs writeToFile:kPrefsPath atomically:NO];
            //runCommand(@"killall -9 runningboardd");
            CFNotificationCenterPostNotification(CFNotificationCenterGetDarwinNotifyCenter(), (CFStringRef)kPrefsChangedIdentifier, NULL, NULL, YES);
        }else{
            NSLog(@"Identifier not found in backgrounding list");
            return 1;
        }
        return 0;
    }
    
    
    if (addNewEntry){
        if (prefs && [prefs[@"enabledIdentifier"] firstObject] != nil){
            NSMutableArray *originalIdentifiers = [prefs[@"enabledIdentifier"] mutableCopy];
            NSArray *array = [prefs[@"enabledIdentifier"] valueForKey:@"identifier"];
            NSUInteger idx = [array indexOfObject:identifierDict[@"identifier"]];
            if ((idx != NSNotFound) && !forceNewEntry){
                NSMutableDictionary *mergedDict = originalIdentifiers[idx];
                [mergedDict addEntriesFromDictionary:identifierDict];
                [originalIdentifiers replaceObjectAtIndex:idx
                                               withObject:mergedDict];
            }else if ((idx != NSNotFound) && forceNewEntry){
                [originalIdentifiers removeObjectAtIndex:idx];
                [originalIdentifiers addObject:identifierDict];
            }else{
                [originalIdentifiers addObject:identifierDict];
            }
            NSOrderedSet *uniqueIdentifierSet = [NSOrderedSet orderedSetWithArray:originalIdentifiers];
            NSArray *newIdentifiers = [uniqueIdentifierSet array];
            prefs[@"enabledIdentifier"] = newIdentifiers;
        }else{
            prefs[@"enabledIdentifier"] = @[identifierDict];
        }
        [prefs writeToFile:kPrefsPath atomically:NO];
        CFNotificationCenterPostNotification(CFNotificationCenterGetDarwinNotifyCenter(), (CFStringRef)kPrefsChangedIdentifier, NULL, NULL, YES);
        return 0;
    }
    
    NSMutableDictionary *pendingRequestDict = [[NSMutableDictionary alloc] init];
    pendingRequestDict[@"identifier"] = identifierDict[@"identifier"];
    if (identifierDict[@"retire"]) pendingRequestDict[@"retire"] = identifierDict[@"retire"];
    if (identifierDict[@"remove"]) pendingRequestDict[@"remove"] = identifierDict[@"remove"];
    if (identifierDict[@"expiration"]) pendingRequestDict[@"expiration"] = identifierDict[@"expiration"];
    
    prefs[@"pendingRequest"] = pendingRequestDict;
    [prefs writeToFile:kPrefsPath atomically:NO];
    CFNotificationCenterPostNotification(CFNotificationCenterGetDarwinNotifyCenter(), (CFStringRef)kRetireProcessIndentifier, NULL, NULL, YES);
    
    return 0;
}
