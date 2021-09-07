#include <stdio.h>
#include <getopt.h>
#import "../common.h"
#import "../NSTask.h"
#import <dlfcn.h>
#import "../BKGShared.h"

#define NSLog(FORMAT, ...) fprintf(stdout, "%s", [[NSString stringWithFormat:FORMAT, ##__VA_ARGS__] UTF8String]);
#define NSLogN(FORMAT, ...) fprintf(stdout, "%s\n", [[NSString stringWithFormat:FORMAT, ##__VA_ARGS__] UTF8String]);

#define FLAG_PLATFORMIZE (1 << 1)

#define PRIVATE_PREMING 0
#define PRIVATE_KILL_BKGD 1
#define DOWNLOAD 2
#define UPLOAD 3
#define LAUNCH_FOREGROUND 4
#define LAUNCH_BACKGROUND 5
#define MASTER_STATE 6
#define APP_STATE 7

void display_usage(){
    fprintf(stderr,
            "Usage: bkg [OPTIONS] <APP_IDENTIFIER>\n"
            "       -i, --identifier [APP_IDENTIFIER]: app identifier\n"
            "       -a, --add: add into backgrounding list\n"
            "                  new parameters will be merged while keeping old parameters\n"
			"                  specify with -denpgrRTIACKkNus to change exiting value\n"
            "                  use -f to force as new entry\n"
            "       -d, --disable: disable from backgrounding list\n"
            "       -f, --force: force adding new entry by overrding old entry of the\n"
            "                    same identifier\n"
            "       -e, --expire: time (seconds) for app to remains active\n"
            "       -n, --notifications: enable showing app's notifications while backgrounded\n"
            "       -p, --halfasleep: allow app to put device into half-asleep state when locked\n"
            "                            0 - disable\n"
            "                            1 - enable\n"
            "       -g, --aggressive: enable aggresive mode\n"
            "       -r, --retire: retire backgrounding app\n"
            "                     app will become inactive gracefully\n"
            "                     will be overidden if it becomes active again\n"
			"       -R, -T, --remove, --terminate: terminate backgrounding app\n"
			"                                      app will be instantly terminated\n"
            "       -I, --immortal: app will be backgrounded infinitely\n"
            "       -A, --advanced: app will be retired according to -c and -s\n"
            "       -C, --cpuusage: enable CPU usage\n"
            "                        0 - disable\n"
            "                        1 - enable\n"
            "       -c, --cpu: maximum CPU usage, 0 to 100\n"
            "       -K, --systemcallstype: enable system calls\n"
            "                              0 - disable\n"
            "                              1 - Mach\n"
            "                              2 - BSD\n"
            "                              3 - Mach+BSD\n"
            "       -k, --systemcalls: maximum system calls number\n"
            "       -N, --network: network bandwidth type\n"
            "                      0 - disable\n"
            "                      1 - Download\n"
            "                      2 - Upload\n"
            "                      3 - Down+Up\n"
            "           --download: download speed threshold\n"
            "           --upload: upload speed threshold\n"
            "       -u, --unit: network bandwidth unit\n"
            "                   0 - B/s\n"
            "                   1 - KB/s\n"
            "                   2 - MB/s\n"
            "                   3 - GB/s\n"
            "       -s, --timespan: time span (seconds) for advanced retiring\n"
            "       -F, --foreground: brings started app to foreground or background\n"
            "                         this flag won't respect everything else, manual termination\n"
            "                         is needed\n"
            "                         0 - background\n"
            "                         1 - foreground\n"
            "       -E, --enable: enable tweak\n"
            "       -D, --disable: disable tweak\n"
			"           --master: master switch state\n"
			"           --app [APP_IDENTIFIER]: app switch state\n"
            "       -X, --reset: reset everything back to default\n"
            "       -l, --launch: launch app\n"
            "                     0 - launch in background (device needs not to be unlocked)\n"
            "                     0 - launch to foreground\n"
            "           --launchf: launch app in foreground\n"
            "           --launchb: launch app in background (device needs not to be unlocked)\n"
            "       -h, --help: show this help message\n"
            );
    exit(-1);
}

// Platformize binary
void platformize_me() {
    void* handle = dlopen("/usr/lib/libjailbreak.dylib", RTLD_LAZY);
    if (!handle) return;
    
    // Reset errors
    dlerror();
    typedef void (*fix_entitle_prt_t)(pid_t pid, uint32_t what);
    fix_entitle_prt_t ptr = (fix_entitle_prt_t)dlsym(handle, "jb_oneshot_entitle_now");
    
    const char *dlsym_error = dlerror();
    if (dlsym_error) return;
    
    ptr(getpid(), FLAG_PLATFORMIZE);
}

// Patch setuid
void patch_setuid() {
    void* handle = dlopen("/usr/lib/libjailbreak.dylib", RTLD_LAZY);
    if (!handle) return;
    
    // Reset errors
    dlerror();
    typedef void (*fix_setuid_prt_t)(pid_t pid);
    fix_setuid_prt_t ptr = (fix_setuid_prt_t)dlsym(handle, "jb_oneshot_fix_setuid_now");
    
    const char *dlsym_error = dlerror();
    if (dlsym_error) return;
    
    ptr(getpid());
}


void elevateAsRoot(){
    patch_setuid();
    platformize_me();
    setuid(0);
    setuid(0);
    if (getuid() != 0) {
        NSLogN(@"%@", @"Failed to elevate as root");
        exit(1);
    }
}

static NSDictionary* runCommand(NSString *cmd){
    if ([cmd length] != 0){
        NSMutableArray *taskArgs = [[NSMutableArray alloc] init];
        taskArgs = [NSMutableArray arrayWithObjects:@"-c", cmd, nil];
        NSTask * task = [[NSTask alloc] init];
        [task setLaunchPath:@"/bin/bash"];
        [task setArguments:taskArgs];
        NSPipe* outputPipe = [NSPipe pipe];
        task.standardOutput = outputPipe;
        
        NSMutableData *data = [NSMutableData data];
        
        NSFileHandle *stdoutHandle = [outputPipe fileHandleForReading];
        [stdoutHandle waitForDataInBackgroundAndNotify];
        id observer = [[NSNotificationCenter defaultCenter] addObserverForName:NSFileHandleDataAvailableNotification object:stdoutHandle queue:nil usingBlock:^(NSNotification *note){
            // This block is called when output from the task is available.
            NSData *dataRead = [stdoutHandle availableData];
            if ([dataRead length] > 0){
                NSString *stringRead = [[NSString alloc] initWithData:dataRead encoding:NSUTF8StringEncoding];
                NSLog(@"%@", stringRead);
                [data appendData:dataRead];
                [stdoutHandle waitForDataInBackgroundAndNotify];
            }
        }];
        
        [task launch];
        //NSData *data = [[outputPipe fileHandleForReading] readDataToEndOfFile];
        [task waitUntilExit];
        NSDictionary *result = @{@"exitCode":@([task terminationStatus]), @"stdout":data?:[@"" dataUsingEncoding:NSUTF8StringEncoding]};
        if (observer) [[NSNotificationCenter defaultCenter] removeObserver:observer];
        return result;
    }
    return @{@"exitCode":@0, @"stdout":[@"" dataUsingEncoding:NSUTF8StringEncoding]};
}

int main(int argc, char *argv[], char *envp[]) {
    if (argc <= 1) display_usage();
    
    int mandatoryArgsCount = 0;
    int expectedmandatoryArgsCount = 1;
    
    static struct option longopts[] = {
        { "identifier", required_argument, 0, 'i' },
        { "add", no_argument, 0, 'a' },
        { "force", no_argument, 0, 'f'},
		{ "retire", no_argument, 0, 'r'},
        { "remove", no_argument, 0, 'R'},
        { "delete", no_argument, 0, 'd'},
        { "enable", no_argument, 0, 'E'},
        { "disable", no_argument, 0, 'D'},
        { "expire", required_argument, 0, 'e'},
        { "reset", no_argument, 0, 'e'},
        { "immortal", no_argument, 0, 'I'},
		{ "terminate", no_argument, 0, 'T'},
        { "notifications", required_argument, 0, 'n'},
        { "halfasleep", required_argument, 0, 'p'},
        { "aggressive", required_argument, 0, 'g'},
        { "foreground", required_argument, 0, 'F'},
        { "advanced", no_argument, 0, 'A'},
        { "cpuusage", required_argument, 0, 'C'},
        { "cpu", required_argument, 0, 'c'},
        { "systemcallstype", required_argument, 0, 'K'},
        { "systemcalls", required_argument, 0, 'k'},
        { "timespan", required_argument, 0, 's'},
        { "network", required_argument, 0, 'N'},
        { "unit", required_argument, 0, 'u'},
        { "download", required_argument, 0, DOWNLOAD},
        { "upload", required_argument, 0, UPLOAD},
        { "launch", required_argument, 0, 'l'},
        { "launchf", no_argument, 0, LAUNCH_FOREGROUND},
        { "launchb", no_argument, 0, LAUNCH_BACKGROUND},
        { "help", no_argument, 0, 'h'},
        { "privatepreming", no_argument, 0, PRIVATE_PREMING},
        { "privatekillbkgd", no_argument, 0, PRIVATE_KILL_BKGD},
		{ "master", no_argument, 0, MASTER_STATE},
		{ "app", required_argument, 0, APP_STATE},
        { 0, 0, 0, 0 }
    };
    
    NSMutableDictionary *identifierDict = [[NSMutableDictionary alloc] init];
    BOOL addNewEntry = NO;
    BOOL deleteEntry = NO;
    BOOL enabled = NO;
    BOOL tweakToggling = NO;
    BOOL forceNewEntry = NO;
    BOOL resetToDefault = NO;
    double timeSpan = -1.0;
    
    int opt;
    while ((opt = getopt_long(argc, argv, "i:adrEDRe:hfXITF:n:Ac:s:C:K:k:p:N:u:l:g:", longopts, NULL)) != -1){
        switch (opt){
            case 'i':
                identifierDict[@"identifier"] = [NSString stringWithCString:optarg encoding:NSUTF8StringEncoding];
                mandatoryArgsCount += 1;
                break;
            case 'a':
                addNewEntry = YES;
                identifierDict[@"enabled"] = @YES;
                break;
            case 'f':
                forceNewEntry = YES;
                break;
            case 'r':
                identifierDict[@"retire"] = @(BKGBackgroundTypeRetire);
                break;
            case 'R':
                identifierDict[@"remove"] = @YES;
                break;
			case 'T':
				identifierDict[@"retire"] = @(BKGBackgroundTypeTerminate);
				break;
            case 'I':
                identifierDict[@"retire"] = @(BKGBackgroundTypeImmortal);
                break;
            case 'A':
                identifierDict[@"retire"] = @(BKGBackgroundTypeAdvanced);
                break;
            case 'C':
                identifierDict[@"cpuUsageEnabled"] = @([[NSString stringWithCString:optarg encoding:NSUTF8StringEncoding] boolValue]);
                break;
            case 'c':
                identifierDict[@"cpuUsageThreshold"] = @([[NSString stringWithCString:optarg encoding:NSUTF8StringEncoding] floatValue]);
                break;
            case 'K':
                identifierDict[@"systemCallsType"] = @([[NSString stringWithCString:optarg encoding:NSUTF8StringEncoding] intValue]);
                break;
            case 'k':
                identifierDict[@"systemCallsThreshold"] = @([[NSString stringWithCString:optarg encoding:NSUTF8StringEncoding] intValue]);
                break;
            case 'N':
                identifierDict[@"networkTransmissionType"] = @([[NSString stringWithCString:optarg encoding:NSUTF8StringEncoding] intValue]);
                break;
            case 'u':
                identifierDict[@"networkTransmissionUnit"] = @([[NSString stringWithCString:optarg encoding:NSUTF8StringEncoding] intValue]);
                break;
            case DOWNLOAD:
                identifierDict[@"rxbytesThreshold"] = @([[NSString stringWithCString:optarg encoding:NSUTF8StringEncoding] doubleValue]);
                break;
            case UPLOAD:
                identifierDict[@"txbytesThreshold"] = @([[NSString stringWithCString:optarg encoding:NSUTF8StringEncoding] doubleValue]);
                break;
            case 's':
                timeSpan = [[NSString stringWithCString:optarg encoding:NSUTF8StringEncoding] doubleValue];
                break;
            case 'e':
                identifierDict[@"expiration"] = @([[NSString stringWithCString:optarg encoding:NSUTF8StringEncoding] doubleValue]);
                break;
            case 'd':
                deleteEntry = YES;
                identifierDict[@"enabled"] = @NO;
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
            case 'X':
                resetToDefault = YES;
                mandatoryArgsCount += 1;
                break;
            case 'n':
                identifierDict[@"enabledAppNotifications"] = @([[NSString stringWithCString:optarg encoding:NSUTF8StringEncoding] boolValue]);
                break;
            case 'p':
                identifierDict[@"darkWake"] = @([[NSString stringWithCString:optarg encoding:NSUTF8StringEncoding] boolValue]);
                break;
            case 'g':
                identifierDict[@"aggressiveAssertion"] = @([[NSString stringWithCString:optarg encoding:NSUTF8StringEncoding] boolValue]);
                break;
            case 'F':
                identifierDict[@"foreground"] = @([[NSString stringWithCString:optarg encoding:NSUTF8StringEncoding] boolValue]);
                break;
            case 'l':{
                BOOL argVal = [[NSString stringWithCString:optarg encoding:NSUTF8StringEncoding] boolValue];
                if (!argVal){
                    identifierDict[@"launchb"] = @YES;
                    identifierDict[@"launchf"] = @NO;
                }else{
                    identifierDict[@"launchb"] = @NO;
                    identifierDict[@"launchf"] = @YES;
                }
                break;
            }
            case LAUNCH_BACKGROUND:{
                identifierDict[@"launchb"] = @YES;
                identifierDict[@"launchf"] = @NO;
                break;
            }
            case LAUNCH_FOREGROUND:{
                identifierDict[@"launchb"] = @NO;
                identifierDict[@"launchf"] = @YES;
                break;
            }
            case PRIVATE_PREMING:
                CFNotificationCenterPostNotification(CFNotificationCenterGetDarwinNotifyCenter(), (CFStringRef)PRERMING_NOTIFICATION_NAME, NULL, NULL, YES);
                return 0;
            case PRIVATE_KILL_BKGD:{
                elevateAsRoot();
                NSDictionary *result = runCommand(@"killall -9 bkgd");
                return [result[@"exitCode"] intValue];
            }
			case MASTER_STATE:{
				NSLogN(@"%@", boolValueForKey(@"enabled", YES) ? @"1" : @"0");
				return 0;
			}
			case APP_STATE:{
				NSLogN(@"%@", boolValueForConfigKey([NSString stringWithCString:optarg encoding:NSUTF8StringEncoding], @"enabled", NO) ? @"1" : @"0");
				return 0;
			}
            default:
                display_usage();
				break;
        }
    }
	
	argc -= optind;
	argv += optind;
	
	if (argc > 0){
		identifierDict[@"identifier"] = [NSString stringWithCString:argv[0] encoding:NSUTF8StringEncoding];
		mandatoryArgsCount += 1;
	}
	
    if (mandatoryArgsCount < expectedmandatoryArgsCount || argc < 1){
        NSLogN(@"Not enough input arguments, -i needs to be specified");
        display_usage();
    }
    
    if (resetToDefault && argc > 2){
        NSLogN(@"Too many arguments, -X can't be specified with anything else");
        return 1;
    }
    
    if (identifierDict[@"foreground"] && argc > 5){
        NSLogN(@"Too many arguments, -F can only be specified with -i");
        return 1;
    }
    
    if (addNewEntry && deleteEntry){
        NSLogN(@"-a can't be specified together with -d");
        return 1;
    }
    
    if (identifierDict[@"retire"] && identifierDict[@"remove"]){
        NSLogN(@"-r, -T, -R, -I and -A can't be specified together")
        return 1;
    }
    
    
    if ((identifierDict[@"enabledAppNotifications"] || ([identifierDict[@"retire"] intValue] > 1)) && !addNewEntry){
        NSLogN(@"-n and -I must be specified with -a")
        return 1;
    }
    
	if ((identifierDict[@"cpuUsageEnabled"] || identifierDict[@"systemCallsType"] || identifierDict[@"cpuUsageThreshold"] || identifierDict[@"systemCallsThreshold"] || identifierDict[@"networkTransmissionUnit"] || identifierDict[@"networkTransmissionType"] || identifierDict[@"rxbytesThreshold"] || identifierDict[@"txbytesThreshold"]) && !addNewEntry){
		NSLogN(@"-CcKkNu, --download and --upload must be specified with -a")
		return 1;
	}
	
    
    if (addNewEntry && !identifierDict[@"retire"] && !identifierDict[@"remove"]){
        identifierDict[@"retire"] = @(BKGBackgroundTypeRetire);
    }else if (addNewEntry && !identifierDict[@"retire"] && identifierDict[@"remove"]){
		identifierDict[@"retire"] = @(BKGBackgroundTypeTerminate);
    }
	[identifierDict removeObjectForKey:@"remove"];
    
	/*
    if (!addNewEntry && !deleteEntry){
        addNewEntry = YES;
    }
    */
    
    elevateAsRoot();
        
    if (resetToDefault){
        NSError *error = nil;
        [[NSFileManager defaultManager] removeItemAtPath:PREFS_PATH error:&error];
        if ((error != nil || error != NULL) && [[NSFileManager defaultManager] fileExistsAtPath:PREFS_PATH]){
            NSLogN(@"Failed to reset");
            return 1;
        }
        CFNotificationCenterPostNotification(CFNotificationCenterGetDarwinNotifyCenter(), (CFStringRef)PREFS_CHANGED_NOTIFICATION_NAME, NULL, NULL, YES);
        CFNotificationCenterPostNotification(CFNotificationCenterGetDarwinNotifyCenter(), (CFStringRef)REFRESH_MODULE_NOTIFICATION_NAME, NULL, NULL, YES);
        CFNotificationCenterPostNotification(CFNotificationCenterGetDarwinNotifyCenter(), (CFStringRef)RELOAD_SPECIFIERS_NOTIFICATION_NAME, NULL, NULL, YES);
        CFNotificationCenterPostNotification(CFNotificationCenterGetDarwinNotifyCenter(), (CFStringRef)RESET_ALL_NOTIFICATION_NAME, NULL, NULL, YES);
        return 0;
    }
    
    if (tweakToggling){
		setValueForKey(@"enabled", @(enabled));
        CFNotificationCenterPostNotification(CFNotificationCenterGetDarwinNotifyCenter(), (CFStringRef)PREFS_CHANGED_NOTIFICATION_NAME, NULL, NULL, YES);
        CFNotificationCenterPostNotification(CFNotificationCenterGetDarwinNotifyCenter(), (CFStringRef)REFRESH_MODULE_NOTIFICATION_NAME, NULL, NULL, YES);
        CFNotificationCenterPostNotification(CFNotificationCenterGetDarwinNotifyCenter(), (CFStringRef)RELOAD_SPECIFIERS_NOTIFICATION_NAME, NULL, NULL, YES);

        return 0;
    }
    
    /*
    if (deleteEntry){
        NSArray *array = [prefs[@"enabledIdentifier"] valueForKey:@"identifier"];
        NSUInteger idx = [array indexOfObject:identifierDict[@"identifier"]];
        if (idx != NSNotFound){
            [prefs[@"enabledIdentifier"] removeObjectAtIndex:idx];
            [prefs writeToFile:PREFS_PATH atomically:NO];
            //runCommand(@"killall -9 runningboardd");
            CFNotificationCenterPostNotification(CFNotificationCenterGetDarwinNotifyCenter(), (CFStringRef)PREFS_CHANGED_NOTIFICATION_NAME, NULL, NULL, YES);
        }else{
            NSLogN(@"Identifier not found in backgrounding list");
            return 1;
        }
        return 0;
    }
    */
    
	if (addNewEntry || deleteEntry){
		if (timeSpan >= 0){
			setValueForConfigKey(identifierDict[@"identifier"], @"timeSpan", @(timeSpan));
		}
		
		if (!forceNewEntry){
			setConfigObject(identifierDict[@"identifier"], identifierDict);
		}else{
			removeConfig(identifierDict[@"identifier"]);
			setConfigObject(identifierDict[@"identifier"], identifierDict);
		}
		CFNotificationCenterPostNotification(CFNotificationCenterGetDarwinNotifyCenter(), (CFStringRef)PREFS_CHANGED_NOTIFICATION_NAME, NULL, NULL, YES);
		CFNotificationCenterPostNotification(CFNotificationCenterGetDarwinNotifyCenter(), (CFStringRef)RELOAD_SPECIFIERS_NOTIFICATION_NAME, NULL, NULL, YES);
		return 0;
	}
	
    NSMutableDictionary *pendingRequestDict = [[NSMutableDictionary alloc] init];
    pendingRequestDict[@"identifier"] = identifierDict[@"identifier"];
    if (identifierDict[@"retire"]) pendingRequestDict[@"retire"] = identifierDict[@"retire"];
    if (identifierDict[@"expiration"]) pendingRequestDict[@"expiration"] = identifierDict[@"expiration"];
    if (identifierDict[@"foreground"]) pendingRequestDict[@"foreground"] = identifierDict[@"foreground"];
    if (identifierDict[@"launchb"]) pendingRequestDict[@"launchb"] = identifierDict[@"launchb"];
    if (identifierDict[@"launchf"]) pendingRequestDict[@"launchf"] = identifierDict[@"launchf"];

	setValueForKey(@"pendingRequest", identifierDict);
    CFNotificationCenterPostNotification(CFNotificationCenterGetDarwinNotifyCenter(), (CFStringRef)CLI_REQUEST_NOTIFICATION_NAME, NULL, NULL, YES);
    
    return 0;
}
