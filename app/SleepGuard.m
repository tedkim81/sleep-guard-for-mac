// Sleep Guard menu bar app
// Shows ☕️ and the remaining time only while disablesleep is on, and quits by itself once it is off.
// It is launched only by `awake` and once at login (in case the setting survived a reboot),
// so nothing runs while sleep is enabled.
#import <AppKit/AppKit.h>

static NSString *const kStateFile = @"/var/run/sleepguard.state";
static NSString *const kHelper = @"/usr/local/libexec/sleep-guard/sleepguard.sh";

static BOOL Korean(void) {
    return [NSLocale.preferredLanguages.firstObject hasPrefix:@"ko"];
}

static BOOL SleepDisabled(void) {
    NSTask *task = [NSTask new];
    task.executableURL = [NSURL fileURLWithPath:@"/usr/bin/pmset"];
    task.arguments = @[@"-g"];
    NSPipe *pipe = [NSPipe pipe];
    task.standardOutput = pipe;
    if (![task launchAndReturnError:nil]) return NO;
    NSData *data = [pipe.fileHandleForReading readDataToEndOfFile];
    [task waitUntilExit];
    NSString *out = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
    NSPredicate *nonEmpty = [NSPredicate predicateWithFormat:@"length > 0"];
    for (NSString *line in [out componentsSeparatedByString:@"\n"]) {
        NSArray *parts = [[line componentsSeparatedByCharactersInSet:NSCharacterSet.whitespaceCharacterSet]
                          filteredArrayUsingPredicate:nonEmpty];
        if (parts.count == 2 && [parts[0] isEqual:@"SleepDisabled"]) return [parts[1] isEqual:@"1"];
    }
    return NO;
}

// Seconds left until the auto-off deadline, or -1 if there is no timer (e.g. after a forced reboot)
static long RemainingSeconds(void) {
    NSString *text = [NSString stringWithContentsOfFile:kStateFile encoding:NSUTF8StringEncoding error:nil];
    NSArray *parts = [[text stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet]
                      componentsSeparatedByString:@" "];
    if (parts.count != 2) return -1;
    return MAX(0, (long)[parts[1] longLongValue] - (long)NSDate.date.timeIntervalSince1970);
}

@interface AppDelegate : NSObject <NSApplicationDelegate>
@end

@implementation AppDelegate {
    NSStatusItem *_statusItem;
    NSMenuItem *_remainingItem;
    NSTimer *_timer;
}

- (void)applicationDidFinishLaunching:(NSNotification *)notification {
    if (!SleepDisabled()) { [NSApp terminate:nil]; return; }

    _statusItem = [NSStatusBar.systemStatusBar statusItemWithLength:NSVariableStatusItemLength];
    NSMenu *menu = [NSMenu new];
    _remainingItem = [[NSMenuItem alloc] initWithTitle:@"" action:nil keyEquivalent:@""];
    [menu addItem:_remainingItem];
    [menu addItem:NSMenuItem.separatorItem];
    NSMenuItem *off = [[NSMenuItem alloc] initWithTitle:(Korean() ? @"잠자기 다시 켜기" : @"Allow Sleep Again")
                                                 action:@selector(turnOff) keyEquivalent:@""];
    off.target = self;
    [menu addItem:off];
    _statusItem.menu = menu;

    [self refresh];
    _timer = [NSTimer scheduledTimerWithTimeInterval:5 target:self selector:@selector(refresh) userInfo:nil repeats:YES];
}

- (void)refresh {
    if (!SleepDisabled()) { [NSApp terminate:nil]; return; }
    long r = RemainingSeconds();
    if (r < 0) {
        _statusItem.button.title = @"☕️";
        _remainingItem.title = Korean() ? @"자동 해제 타이머 없음" : @"No auto-off timer";
    } else {
        _statusItem.button.title = [NSString stringWithFormat:@"☕️ %ld:%02ld", r / 3600, r % 3600 / 60];
        _remainingItem.title = [NSString stringWithFormat:(Korean() ? @"자동 해제까지 %ld시간 %ld분" : @"Auto-off in %ldh %ldm"),
                                r / 3600, r % 3600 / 60];
    }
}

- (void)turnOff {
    NSString *source = [NSString stringWithFormat:
        @"do shell script (quoted form of \"%@\") & \" stop\" with administrator privileges", kHelper];
    [[[NSAppleScript alloc] initWithSource:source] executeAndReturnError:nil];
    [self refresh];
}

@end

int main(void) {
    @autoreleasepool {
        NSApplication *app = NSApplication.sharedApplication;
        AppDelegate *delegate = [AppDelegate new];
        app.delegate = delegate;
        [app setActivationPolicy:NSApplicationActivationPolicyAccessory];
        [app run];
    }
    return 0;
}
