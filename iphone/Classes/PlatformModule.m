/**
 * Appcelerator Titanium Mobile
 * Copyright (c) 2009-2014 by Appcelerator, Inc. All Rights Reserved.
 * Licensed under the terms of the Apache Public License
 * Please see the LICENSE included with this distribution for details.
 */
#ifdef USE_TI_PLATFORM

#import "PlatformModule.h"
#import "TiApp.h"

#import <mach/mach.h>
#import <sys/sysctl.h>
#import <sys/utsname.h>

#import <arpa/inet.h>
#import <ifaddrs.h>
#import <sys/socket.h>
#import <sys/types.h>

#if defined(USE_TI_PLATFORMIDENTIFIERFORADVERTISING) || defined(USE_TI_PLATFORMGETIDENTIFIERFORADVERTISING)
#import <AdSupport/AdSupport.h>
#endif

NSString *const WIFI_IFACE = @"en0";
NSString *const DATA_IFACE = @"pdp_ip0";

@implementation PlatformModule

@synthesize name, model, version, architecture, processorCount, username, ostype, availableMemory;

#pragma mark Internal

- (id)init
{
  if (self = [super init]) {
    UIDevice *theDevice = [UIDevice currentDevice];
    name = [[theDevice systemName] retain];
    version = [[theDevice systemVersion] retain];
    processorCount = [[NSNumber numberWithInt:1] retain];
    username = [[theDevice name] retain];
#ifdef __LP64__
    ostype = [@"64bit" retain];
#else
    ostype = [@"32bit" retain];
#endif

    if ([TiUtils isIPad]) {
      // ipad is a constant for Ti.Platform.osname
      [self replaceValue:@"ipad" forKey:@"osname" notification:NO];
    } else {
      // iphone is a constant for Ti.Platform.osname
      [self replaceValue:@"iphone" forKey:@"osname" notification:NO];
    }

    NSString *themodel = [theDevice model];

    // attempt to determine extended phone info
    struct utsname u;
    uname(&u);

    // detect iPhone 3G model
    if (!strcmp(u.machine, "iPhone1,2")) {
      model = [[NSString stringWithFormat:@"%@ 3G", themodel] retain];
    }
    // detect iPhone 3Gs model
    else if (!strcmp(u.machine, "iPhone2,1")) {
      model = [[NSString stringWithFormat:@"%@ 3GS", themodel] retain];
    }
    // detect iPhone 4 model
    else if (!strcmp(u.machine, "iPhone3,1")) {
      model = [[NSString stringWithFormat:@"%@ 4", themodel] retain];
    }
    // detect iPod Touch 2G model
    else if (!strcmp(u.machine, "iPod2,1")) {
      model = [[NSString stringWithFormat:@"%@ 2G", themodel] retain];
    }
    // detect iPad 2 model
    else if (!strcmp(u.machine, "iPad2,1")) {
      model = [[NSString stringWithFormat:@"%@ 2", themodel] retain];
    }
    // detect simulator for i386
    else if (!strcmp(u.machine, "i386")) {
      model = [@"Simulator" retain];
    }
    // detect simulator for x86_64
    else if (!strcmp(u.machine, "x86_64")) {
      model = [@"Simulator" retain];
    } else {
      model = [[NSString alloc] initWithUTF8String:u.machine];
    }
    architecture = [[TiUtils currentArchitecture] retain];

    // needed for platform displayCaps orientation to be correct
    [[UIDevice currentDevice] beginGeneratingDeviceOrientationNotifications];
  }
  return self;
}

- (void)dealloc
{
  RELEASE_TO_NIL(name);
  RELEASE_TO_NIL(model);
  RELEASE_TO_NIL(version);
  RELEASE_TO_NIL(architecture);
  RELEASE_TO_NIL(processorCount);
  RELEASE_TO_NIL(username);
  RELEASE_TO_NIL(address);
  RELEASE_TO_NIL(ostype);
  RELEASE_TO_NIL(availableMemory);
  RELEASE_TO_NIL(capabilities);
  [super dealloc];
}

- (NSString *)apiName
{
  return @"Ti.Platform";
}

- (void)registerListeners:(id)unused
{
  UIDevice *device = [UIDevice currentDevice];
  // set a flag to temporarily turn on battery enablement
  if (batteryEnabled == NO && device.batteryMonitoringEnabled == NO) {
    batteryEnabled = YES;
    [device setBatteryMonitoringEnabled:YES];
  }

  [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(batteryStateChanged:) name:UIDeviceBatteryStateDidChangeNotification object:device];
  [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(batteryStateChanged:) name:UIDeviceBatteryLevelDidChangeNotification object:device];
}

- (void)unregisterListeners:(id)unused
{
  UIDevice *device = [UIDevice currentDevice];
  if (batteryEnabled) {
    [device setBatteryMonitoringEnabled:NO];
    batteryEnabled = NO;
  }
  [[NSNotificationCenter defaultCenter] removeObserver:self name:UIDeviceBatteryStateDidChangeNotification object:device];
  [[NSNotificationCenter defaultCenter] removeObserver:self name:UIDeviceBatteryLevelDidChangeNotification object:device];
}

- (void)_listenerAdded:(NSString *)type count:(int)count
{
  if (count == 1 && [type isEqualToString:@"battery"]) {
    TiThreadPerformOnMainThread(^{
      [self registerListeners:nil];
    },
        YES);
  }
}

- (void)_listenerRemoved:(NSString *)type count:(int)count
{
  if (count == 0 && [type isEqualToString:@"battery"]) {
    TiThreadPerformOnMainThread(^{
      [self unregisterListeners:nil];
    },
        YES);
  }
}

- (NSString *)getIface:(NSString *)iname mask:(BOOL)mask
{
  struct ifaddrs *head = NULL;
  struct ifaddrs *ifaddr = NULL;
  getifaddrs(&head);

  NSString *str = nil;
  for (ifaddr = head; ifaddr != NULL; ifaddr = ifaddr->ifa_next) {
    if (ifaddr->ifa_addr->sa_family == AF_INET && !strcmp(ifaddr->ifa_name, [iname UTF8String])) {

      char ipaddr[20];
      struct sockaddr_in *addr;
      if (mask) {
        addr = (struct sockaddr_in *)ifaddr->ifa_netmask;
      } else {
        addr = (struct sockaddr_in *)ifaddr->ifa_addr;
      }
      inet_ntop(addr->sin_family, &(addr->sin_addr), ipaddr, 20);
      str = [NSString stringWithUTF8String:ipaddr];
      break;
    }
  }

  freeifaddrs(head);
  return str;
}

#pragma mark Public APIs

- (NSString *)runtime
{
  return @"javascriptcore";
}

- (NSString *)manufacturer
{
  return @"apple";
}

- (NSString *)locale
{
  // this will return the locale that the user has set the phone in
  // not the region where the phone is
  NSUserDefaults *defs = [NSUserDefaults standardUserDefaults];
  NSArray *languages = [defs objectForKey:@"AppleLanguages"];
  return [languages count] > 0 ? [languages objectAtIndex:0] : @"en";
}

- (NSString *)macaddress
{
  return [TiUtils appIdentifier];
}

- (NSString *)identifierForVendor
{
  return [[[UIDevice currentDevice] identifierForVendor] UUIDString];
}

#if defined(USE_TI_PLATFORMIDENTIFIERFORADVERTISING) || defined(USE_TI_PLATFORMGETIDENTIFIERFORADVERTISING)
- (NSNumber *)isAdvertisingTrackingEnabled
{
  return NUMBOOL([[ASIdentifierManager sharedManager] isAdvertisingTrackingEnabled]);
}

- (NSString *)identifierForAdvertising
{
  return [[[ASIdentifierManager sharedManager] advertisingIdentifier] UUIDString];
}
#endif

- (id)id
{
  return [TiUtils appIdentifier];
}

- (NSString *)createUUID:(id)args
{
  return [TiUtils createUUID];
}

- (NSNumber *)is24HourTimeFormat:(id)unused
{
  NSDateFormatter *dateFormatter = [[NSDateFormatter alloc] init];
  [dateFormatter setLocale:[NSLocale currentLocale]];
  [dateFormatter setTimeStyle:NSDateFormatterShortStyle];
  NSString *dateInStringForm = [dateFormatter stringFromDate:[NSDate date]];
  NSRange amRange = [dateInStringForm rangeOfString:[dateFormatter AMSymbol]];
  NSRange pmRange = [dateInStringForm rangeOfString:[dateFormatter PMSymbol]];
  [dateFormatter release];
  return NUMBOOL(amRange.location == NSNotFound && pmRange.location == NSNotFound);
}

- (NSNumber *)availableMemory
{
  vm_statistics_data_t vmStats;
  mach_msg_type_number_t infoCount = HOST_VM_INFO_COUNT;
  kern_return_t kernReturn = host_statistics(mach_host_self(), HOST_VM_INFO, (host_info_t)&vmStats, &infoCount);

  if (kernReturn != KERN_SUCCESS) {
    return [NSNumber numberWithDouble:-1];
  }

  return [NSNumber numberWithDouble:((vm_page_size * vmStats.free_count) / 1024.0) / 1024.0];
}

- (NSNumber *)openURL:(NSArray *)args
{
  NSString *newUrlString = [args objectAtIndex:0];
  NSURL *newUrl = [TiUtils toURL:newUrlString proxy:self];
  BOOL result = NO;

  // iOS 10+
  KrollCallback *callback = nil;
  NSMutableDictionary *options = [NSMutableDictionary dictionary];

  if ([args count] >= 2) {
    if ([[args objectAtIndex:1] isKindOfClass:[NSDictionary class]]) {
      ENSURE_ARG_AT_INDEX(options, args, 1, NSMutableDictionary);
      if ([args count] == 3) {
        ENSURE_ARG_AT_INDEX(callback, args, 2, KrollCallback);
      }
    } else {
      ENSURE_ARG_AT_INDEX(callback, args, 1, KrollCallback);
    }
  }

  if (newUrl != nil) {
    if ([TiUtils isIOS10OrGreater]) {
      [[UIApplication sharedApplication] openURL:newUrl
                                         options:options
                               completionHandler:^(BOOL success) {
                                 if (callback != nil) {
                                   [callback call:@[ @{ @"success" : @(success) } ] thisObject:self];
                                 }
                               }];
    } else {
      result = [[UIApplication sharedApplication] openURL:newUrl];
    }
  }

  return [NSNumber numberWithBool:result];
}

- (NSNumber *)canOpenURL:(id)arg
{
  ENSURE_SINGLE_ARG(arg, NSString);
  NSURL *url = [TiUtils toURL:arg proxy:self];
  return NUMBOOL([[UIApplication sharedApplication] canOpenURL:url]);
}

- (TiPlatformDisplayCaps *)displayCaps
{
  if (capabilities == nil) {
    return [[[TiPlatformDisplayCaps alloc] _initWithPageContext:[self executionContext]] autorelease];
  }
  return capabilities;
}

- (void)setBatteryMonitoring:(NSNumber *)yn
{
  if (![NSThread isMainThread]) {
    TiThreadPerformOnMainThread(^{
      [self setBatteryMonitoring:yn];
    },
        YES);
  }
  [[UIDevice currentDevice] setBatteryMonitoringEnabled:[TiUtils boolValue:yn]];
}

- (NSNumber *)batteryMonitoring
{
  if (![NSThread isMainThread]) {
    __block NSNumber *result = nil;
    TiThreadPerformOnMainThread(^{
      result = [[self batteryMonitoring] retain];
    },
        YES);
    return [result autorelease];
  }
  return NUMBOOL([UIDevice currentDevice].batteryMonitoringEnabled);
}

- (NSNumber *)batteryState
{
  if (![NSThread isMainThread]) {
    __block NSNumber *result = nil;
    TiThreadPerformOnMainThread(^{
      result = [[self batteryState] retain];
    },
        YES);
    return [result autorelease];
  }
  return NUMINT([[UIDevice currentDevice] batteryState]);
}

- (NSNumber *)batteryLevel
{
  if (![NSThread isMainThread]) {
    __block NSNumber *result = nil;
    TiThreadPerformOnMainThread(^{
      result = [[self batteryLevel] retain];
    },
        YES);
    return [result autorelease];
  }
  return NUMFLOAT([[UIDevice currentDevice] batteryLevel]);
}

- (NSString *)address
{
#if TARGET_IPHONE_SIMULATOR
  // Assume classical ethernet and wifi interfaces
  NSArray *interfaces = [NSArray arrayWithObjects:@"en0", @"en1", nil];
  for (NSString *interface in interfaces) {
    NSString *iface = [self getIface:interface mask:NO];
    if (iface) {
      return iface;
    }
  }
  return nil;
#else
  return [self getIface:WIFI_IFACE mask:NO];
#endif
}

- (NSString *)dataAddress
{
#if TARGET_IPHONE_SIMULATOR
  return nil; // Handy shortcut
#else
  return [self getIface:DATA_IFACE mask:NO];
#endif
}

// Only available for the local wifi; why would you want it for the data network?
- (NSString *)netmask
{
#if TARGET_IPHONE_SIMULATOR
  // Assume classical ethernet and wifi interfaces
  NSArray *interfaces = [NSArray arrayWithObjects:@"en0", @"en1", nil];
  for (NSString *interface in interfaces) {
    NSString *iface = [self getIface:interface mask:YES];
    if (iface) {
      return iface;
    }
  }
  return nil;
#else
  return [self getIface:WIFI_IFACE mask:YES];
#endif
}

MAKE_SYSTEM_PROP(BATTERY_STATE_UNKNOWN, UIDeviceBatteryStateUnknown);
MAKE_SYSTEM_PROP(BATTERY_STATE_UNPLUGGED, UIDeviceBatteryStateUnplugged);
MAKE_SYSTEM_PROP(BATTERY_STATE_CHARGING, UIDeviceBatteryStateCharging);
MAKE_SYSTEM_PROP(BATTERY_STATE_FULL, UIDeviceBatteryStateFull);

#pragma mark Delegates

- (void)batteryStateChanged:(NSNotification *)note
{
  NSDictionary *event = [NSDictionary dictionaryWithObjectsAndKeys:[self batteryState], @"state", [self batteryLevel], @"level", nil];
  [self fireEvent:@"battery" withObject:event];
}

- (void)didReceiveMemoryWarning:(NSNotification *)notification
{
  RELEASE_TO_NIL(capabilities);
  [super didReceiveMemoryWarning:notification];
}

@end

#endif
