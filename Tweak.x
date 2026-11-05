// AgoraEnhance v2 - قائمة عائمة دائرية: سرعة الصوت / للضحك (شكلي) / جودة الصوت
// يؤثر على صوتك أنت فقط. قسم الشبكة شكلي ولا يغيّر الاتصال الفعلي.

#import <UIKit/UIKit.h>
#import <objc/runtime.h>
#import <objc/message.h>

// ---------- الحالة العامة ----------
static __weak id gEngine = nil;
// AgoraAudioProfile: 1 SpeechStandard, 4 MusicHighQuality  (راجع AgoraEnumerates.h للإصدار الموجود)
// AgoraAudioScenario: 0 Default, 5 ChatRoomGaming
static NSInteger gProfile  = 4;
static NSInteger gScenario = 5;
static double    gPitch    = 1.0;   // 1.0 عادي، الحد الأقصى المدعوم 2.0
static BOOL      gDenoise  = YES;

// ---------- أدوات الاتصال بـ Agora ----------
static void applyExtras(id e) {
    if (!e) return;
    SEL vp = NSSelectorFromString(@"setLocalVoicePitch:");
    if ([e respondsToSelector:vp])
        ((int (*)(id, SEL, double))objc_msgSend)(e, vp, gPitch);
    SEL ns = NSSelectorFromString(@"enableDeepLearningDenoise:");
    if ([e respondsToSelector:ns])
        ((int (*)(id, SEL, BOOL))objc_msgSend)(e, ns, gDenoise);
}

static void applyProfile(void) {
    id e = gEngine;
    if (!e) return;
    SEL sp = NSSelectorFromString(@"setAudioProfile:scenario:");
    if ([e respondsToSelector:sp])
        ((int (*)(id, SEL, NSInteger, NSInteger))objc_msgSend)(e, sp, gProfile, gScenario);
}

// Native Objective-C runtime method replacement: no Logos, ElleKit or Substrate API.
// This is deliberately NOT fishhook: AgoraRtcEngineKit methods are Objective-C methods,
// not imported C symbols suitable for fishhook rebinding.
typedef int (*AEEnableAudioIMP)(id, SEL);
typedef int (*AESetAudioProfileIMP)(id, SEL, NSInteger, NSInteger);
typedef int (*AEJoinChannelIMP)(id, SEL, id, id, id, NSUInteger, id);
static AEEnableAudioIMP gOrigEnableAudio = NULL;
static AESetAudioProfileIMP gOrigSetAudioProfile = NULL;
static AEJoinChannelIMP gOrigJoinChannel = NULL;
static BOOL gHooksInstalled = NO;

static int AEEnableAudio(id self, SEL _cmd) {
    gEngine = self;
    return gOrigEnableAudio ? gOrigEnableAudio(self, _cmd) : -1;
}

static int AESetAudioProfile(id self, SEL _cmd, NSInteger profile, NSInteger scenario) {
    gEngine = self;
    int result = gOrigSetAudioProfile
        ? gOrigSetAudioProfile(self, _cmd, gProfile, gScenario) : -1;
    applyExtras(self);
    NSLog(@"[AgoraEnhance] profile %ld/%ld -> %ld/%ld",
          (long)profile, (long)scenario, (long)gProfile, (long)gScenario);
    return result;
}

static int AEJoinChannel(id self, SEL _cmd, id token, id channelId, id info,
                         NSUInteger uid, id options) {
    gEngine = self;
    applyProfile();
    return gOrigJoinChannel
        ? gOrigJoinChannel(self, _cmd, token, channelId, info, uid, options) : -1;
}

static BOOL AEReplaceInstanceMethod(Class cls, SEL selector, IMP replacement, IMP *original) {
    Method method = class_getInstanceMethod(cls, selector);
    if (!method) return NO;
    *original = method_setImplementation(method, replacement);
    return (*original != NULL);
}

static void AEInstallHooksWhenReady(void) {
    if (gHooksInstalled) return;
    Class cls = NSClassFromString(@"AgoraRtcEngineKit");
    if (!cls) return;
    SEL enableSel = @selector(enableAudio);
    SEL profileSel = NSSelectorFromString(@"setAudioProfile:scenario:");
    SEL joinSel = NSSelectorFromString(@"joinChannelByToken:channelId:info:uid:options:");
    // Wait until the class and all target methods are present before changing any IMP.
    if (!class_getInstanceMethod(cls, enableSel) ||
        !class_getInstanceMethod(cls, profileSel) ||
        !class_getInstanceMethod(cls, joinSel)) return;
    BOOL a = AEReplaceInstanceMethod(cls, enableSel, (IMP)AEEnableAudio,
                                     (IMP *)&gOrigEnableAudio);
    BOOL b = AEReplaceInstanceMethod(cls, profileSel, (IMP)AESetAudioProfile,
                                     (IMP *)&gOrigSetAudioProfile);
    BOOL c = AEReplaceInstanceMethod(cls, joinSel, (IMP)AEJoinChannel,
                                     (IMP *)&gOrigJoinChannel);
    gHooksInstalled = a && b && c;
    NSLog(@"[AgoraEnhance] runtime hooks %@ (enable=%d profile=%d join=%d)",
          gHooksInstalled ? @"installed" : @"failed", a, b, c);
}

// ---------- الواجهة ----------
@interface AEPassWindow : UIWindow
@end
@implementation AEPassWindow
- (UIView *)hitTest:(CGPoint)p withEvent:(UIEvent *)e {
    UIView *v = [super hitTest:p withEvent:e];
    return (v == self.rootViewController.view) ? nil : v;   // مرّر اللمس للعبة
}
@end

static UIButton *AEBtn(NSString *t, CGRect f, CGFloat r, UIColor *bg) {
    UIButton *b = [UIButton buttonWithType:UIButtonTypeCustom];
    b.frame = f;
    b.layer.cornerRadius = r;
    b.clipsToBounds = YES;
    b.backgroundColor = bg;
    [b setTitle:t forState:UIControlStateNormal];
    b.titleLabel.font = [UIFont boldSystemFontOfSize:14];
    return b;
}

static NSArray *AETitles(void) { return @[@"🔊 سرعة الصوت", @"😂 للضحك (شكلي)", @"🎚 جودة الصوت"]; }
static NSArray *AEOptions(NSInteger s) {
    if (s == 0) return @[@"x2", @"x3", @"x5"];
    if (s == 1) return @[@"📶 5G", @"📶 4G", @"⬇⬆ 1 TB/s"];
    return @[@"صوت عادي", @"جودة عالية", gDenoise ? @"إلغاء الضجيج: ✅" : @"إلغاء الضجيج: ⛔"];
}

@interface AEMenuVC : UIViewController
@property (nonatomic, strong) UIButton *fab;
@property (nonatomic, strong) NSArray<UIButton *> *secBtns;
@property (nonatomic, strong) UIView *panel;
@property (nonatomic, strong) UILabel *toastLabel;
@property (nonatomic, strong) UILabel *netLabel;
@property (nonatomic, assign) BOOL open;
@property (nonatomic, assign) NSInteger curSec;
@property (nonatomic, strong) NSMutableDictionary<NSNumber *, NSNumber *> *sel;
@end

@implementation AEMenuVC

- (void)viewDidLoad {
    [super viewDidLoad];
    self.view.backgroundColor = UIColor.clearColor;
    self.sel = [NSMutableDictionary new];
    self.curSec = -1;
    UIColor *dark = [UIColor colorWithRed:0.08 green:0.09 blue:0.14 alpha:0.92];
    CGFloat W = UIScreen.mainScreen.bounds.size.width;

    self.fab = AEBtn(@"🎛", CGRectMake(W - 72, 220, 56, 56), 28, dark);
    self.fab.titleLabel.font = [UIFont systemFontOfSize:26];
    self.fab.layer.borderWidth = 2;
    self.fab.layer.borderColor = [UIColor colorWithRed:0.3 green:0.8 blue:1 alpha:1].CGColor;
    [self.fab addTarget:self action:@selector(toggleMenu) forControlEvents:UIControlEventTouchUpInside];
    [self.fab addGestureRecognizer:[[UIPanGestureRecognizer alloc] initWithTarget:self action:@selector(drag:)]];

    NSMutableArray *arr = [NSMutableArray new];
    NSArray *icons = @[@"🔊", @"😂", @"🎚"];
    for (NSInteger i = 0; i < 3; i++) {
        UIButton *b = AEBtn(icons[i], CGRectMake(0, 0, 46, 46), 23, dark);
        b.titleLabel.font = [UIFont systemFontOfSize:22];
        b.tag = i;
        b.hidden = YES;
        [b addTarget:self action:@selector(secTapped:) forControlEvents:UIControlEventTouchUpInside];
        [self.view addSubview:b];
        [arr addObject:b];
    }
    self.secBtns = arr;
    [self.view addSubview:self.fab];

    self.netLabel = [[UILabel alloc] initWithFrame:CGRectMake(0, 0, 220, 30)];
    self.netLabel.center = CGPointMake(W / 2, 62);
    self.netLabel.textAlignment = NSTextAlignmentCenter;
    self.netLabel.font = [UIFont boldSystemFontOfSize:14];
    self.netLabel.textColor = UIColor.whiteColor;
    self.netLabel.backgroundColor = [UIColor colorWithWhite:0 alpha:0.6];
    self.netLabel.layer.cornerRadius = 15;
    self.netLabel.clipsToBounds = YES;
    self.netLabel.hidden = YES;
    self.netLabel.userInteractionEnabled = NO;
    [self.view addSubview:self.netLabel];

    self.toastLabel = [[UILabel alloc] initWithFrame:CGRectMake(20, 0, W - 40, 40)];
    self.toastLabel.textAlignment = NSTextAlignmentCenter;
    self.toastLabel.numberOfLines = 2;
    self.toastLabel.font = [UIFont systemFontOfSize:13];
    self.toastLabel.textColor = UIColor.whiteColor;
    self.toastLabel.backgroundColor = [UIColor colorWithWhite:0 alpha:0.75];
    self.toastLabel.layer.cornerRadius = 12;
    self.toastLabel.clipsToBounds = YES;
    self.toastLabel.alpha = 0;
    self.toastLabel.userInteractionEnabled = NO;
    [self.view addSubview:self.toastLabel];
}

- (void)viewDidLayoutSubviews {
    [super viewDidLayoutSubviews];
    CGSize s = self.view.bounds.size;
    self.toastLabel.center = CGPointMake(s.width / 2, s.height - 90);
    self.netLabel.center = CGPointMake(s.width / 2, 62);
}

- (void)toast:(NSString *)t {
    self.toastLabel.text = t;
    [self.toastLabel.layer removeAllAnimations];
    self.toastLabel.alpha = 1;
    [UIView animateWithDuration:0.4 delay:2.2 options:0 animations:^{ self.toastLabel.alpha = 0; } completion:nil];
}

- (void)drag:(UIPanGestureRecognizer *)g {
    CGPoint t = [g translationInView:self.view];
    CGSize s = self.view.bounds.size;
    CGFloat x = MIN(MAX(g.view.center.x + t.x, 30), s.width - 30);
    CGFloat y = MIN(MAX(g.view.center.y + t.y, 50), s.height - 50);
    g.view.center = CGPointMake(x, y);
    [g setTranslation:CGPointZero inView:self.view];
    [self layoutMenu];
}

- (void)toggleMenu {
    self.open = !self.open;
    [self layoutMenu];
}

- (void)layoutMenu {
    CGSize s = self.view.bounds.size;
    CGPoint c = self.fab.center;
    CGFloat dir = (c.y < s.height / 2) ? 1 : -1;
    for (NSInteger i = 0; i < 3; i++) {
        UIButton *b = self.secBtns[i];
        b.center = CGPointMake(c.x, c.y + dir * (i + 1) * 54);
        b.hidden = !self.open;
        b.layer.borderWidth = (self.curSec == i) ? 2 : 0;
        b.layer.borderColor = [UIColor colorWithRed:0.3 green:0.8 blue:1 alpha:1].CGColor;
    }
    if (self.panel) {
        self.panel.hidden = !self.open;
        CGFloat h = self.panel.bounds.size.height, w = self.panel.bounds.size.width;
        CGFloat px = (c.x > s.width / 2) ? (c.x - 28 - 8 - w) : (c.x + 28 + 8);
        CGFloat py = self.secBtns[self.curSec].center.y - 25;
        py = MIN(MAX(py, 10), s.height - h - 10);
        self.panel.frame = CGRectMake(px, py, w, h);
    }
}

- (void)secTapped:(UIButton *)b {
    if (self.curSec == b.tag && self.panel) {      // اضغط مرة ثانية لإغلاق اللوحة
        [self.panel removeFromSuperview];
        self.panel = nil;
        self.curSec = -1;
        [self layoutMenu];
        return;
    }
    self.curSec = b.tag;
    [self buildPanel];
}

- (BOOL)isSelectedSec:(NSInteger)s opt:(NSInteger)o {
    if (s == 2 && o == 2) return gDenoise;
    NSNumber *n = self.sel[@(s)];
    return n && n.integerValue == o;
}

- (void)buildPanel {
    [self.panel removeFromSuperview];
    NSInteger s = self.curSec;
    UIView *p = [[UIView alloc] initWithFrame:CGRectMake(0, 0, 200, 50 + 3 * 42)];
    p.backgroundColor = [UIColor colorWithRed:0.08 green:0.09 blue:0.14 alpha:0.95];
    p.layer.cornerRadius = 16;
    UILabel *t = [[UILabel alloc] initWithFrame:CGRectMake(0, 8, 200, 28)];
    t.text = AETitles()[s];
    t.textAlignment = NSTextAlignmentCenter;
    t.textColor = UIColor.whiteColor;
    t.font = [UIFont boldSystemFontOfSize:15];
    [p addSubview:t];
    NSArray *opts = AEOptions(s);
    for (NSInteger i = 0; i < 3; i++) {
        BOOL on = [self isSelectedSec:s opt:i];
        UIColor *bg = on ? [UIColor colorWithRed:0.1 green:0.6 blue:0.35 alpha:1] : [UIColor colorWithWhite:0.25 alpha:1];
        UIButton *b = AEBtn(opts[i], CGRectMake(10, 40 + i * 42, 180, 36), 10, bg);
        b.tag = i;
        [b addTarget:self action:@selector(optTapped:) forControlEvents:UIControlEventTouchUpInside];
        [p addSubview:b];
    }
    self.panel = p;
    [self.view addSubview:p];
    [self layoutMenu];
}

- (void)optTapped:(UIButton *)b {
    NSInteger s = self.curSec, o = b.tag;
    BOOL same = [self isSelectedSec:s opt:o] && !(s == 2 && o == 2);

    if (s == 0) {                                   // سرعة الصوت
        if (same) {
            [self.sel removeObjectForKey:@(s)];
            gPitch = 1.0;
            [self toast:@"السرعة: عادي"];
        } else {
            double want[3] = {2, 3, 5};
            gPitch = MIN(want[o], 2.0);
            self.sel[@(s)] = @(o);
            [self toast:(want[o] > 2.0)
                ? @"Agora يدعم حتى x2 فقط، طُبّق x2"
                : @"تم تطبيق x2"];
        }
        if (gEngine) applyExtras(gEngine);
        else [self toast:@"ادخل غرفة صوتية أولاً، وسيُطبّق عند الاتصال"];

    } else if (s == 1) {                            // للضحك: لافتة شكلية
        if (same) {
            [self.sel removeObjectForKey:@(s)];
            self.netLabel.hidden = YES;
        } else {
            self.sel[@(s)] = @(o);
            self.netLabel.text = @[@"📶 5G", @"📶 4G", @"⬇ 1 TB/s   ⬆ 1 TB/s"][o];
            self.netLabel.hidden = NO;
            [self toast:@"شكلي فقط، لا يغيّر الشبكة الفعلية 😄"];
        }

    } else {                                        // جودة الصوت
        if (o == 0) { gProfile = 1; gScenario = 0; self.sel[@(s)] = @(0); }
        else if (o == 1) { gProfile = 4; gScenario = 5; self.sel[@(s)] = @(1); }
        else { gDenoise = !gDenoise; }
        if (gEngine) { applyProfile(); applyExtras(gEngine); }
        else [self toast:@"ادخل غرفة صوتية أولاً، وسيُطبّق عند الاتصال"];
    }
    [self buildPanel];
}
@end

// ---------- التشغيل ----------
static AEPassWindow *gWin = nil;

static void AESetupUI(void) {
    dispatch_async(dispatch_get_main_queue(), ^{
        if (gWin) return;
        UIWindowScene *scene = nil;
        for (UIScene *sc in UIApplication.sharedApplication.connectedScenes) {
            if ([sc isKindOfClass:UIWindowScene.class]) { scene = (UIWindowScene *)sc; break; }
        }
        AEPassWindow *w = scene ? [[AEPassWindow alloc] initWithWindowScene:scene]
                                : [[AEPassWindow alloc] initWithFrame:UIScreen.mainScreen.bounds];
        w.windowLevel = UIWindowLevelAlert + 100;
        w.backgroundColor = UIColor.clearColor;
        w.rootViewController = [AEMenuVC new];
        w.hidden = NO;
        gWin = w;
    });
}

static void AERetryHookInstall(NSUInteger attempt) {
    if (gHooksInstalled || attempt >= 120) return;
    AEInstallHooksWhenReady();
    if (!gHooksInstalled) {
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(250 * NSEC_PER_MSEC)),
                       dispatch_get_main_queue(), ^{ AERetryHookInstall(attempt + 1); });
    }
}

__attribute__((constructor)) static void AEInit(void) {
    // The Agora framework may load after this dylib. Retry without blocking the main thread.
    dispatch_async(dispatch_get_main_queue(), ^{ AERetryHookInstall(0); });
    [[NSNotificationCenter defaultCenter]
        addObserverForName:UIApplicationDidBecomeActiveNotification object:nil
        queue:NSOperationQueue.mainQueue usingBlock:^(NSNotification *n) {
            dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(2 * NSEC_PER_SEC)),
                           dispatch_get_main_queue(), ^{ AESetupUI(); });
        }];
}
