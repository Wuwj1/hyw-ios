//
//  hmy_krkr_host.mm
//  何意味 iOS 版 的 KRKR 宿主层（第一版）
//
//  设计依据（全部来自上游源码，见 docs/KRKR_IOS_HOST.md）：
//    - 引擎主循环在 environ/sdl3/sdl3_app.cpp：
//        SDL_AppInit(appstate, argc, argv)   行 198
//        SDL_AppEvent(appstate, event)       行 425
//        SDL_AppIterate(appstate)            行 543
//        SDL_AppQuit(appstate, result)       行 561
//    - 游戏目录 = argv[1]（core/utils/TVPSettings.cpp:253）
//    - 存档 = <游戏目录>/savedata/（同文件 :273）
//
//  为什么不用 SDL_EnterAppMainCallbacks()：
//    SDL3 的 src/main/ios/SDL_sysmain_callbacks.m:76 原注释写着
//      "SDL_RunApp will land in UIApplicationMain, which calls SDL_main from
//       postFinishLaunch, which calls this."
//    也就是说它假设自己跑在 UIApplicationMain 里；而且结束时走的是
//      exit((rc == SDL_APP_FAILURE) ? 1 : 0);
//    —— 直接杀进程，不可能"退出游戏回到何意味"。
//    因此本宿主**自己驱动**这四个回调（与 SDL 在 iOS 上的做法一致：CADisplayLink
//    每帧调一次 iterate），不经过 SDL_main / UIApplicationMain。
//
//  待 Mac 验证的点全部标了 TODO(MAC-n)，不要当作已成立。
//

#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#import <AVFoundation/AVFoundation.h>
#import <QuartzCore/CADisplayLink.h>

#include <SDL3/SDL.h>

#include <sys/stat.h>
#include <unistd.h>
#include <atomic>
#include <string>
#include <vector>

#include "hmy_krkr.h"

@class HMYKrkrLinkProxy;   // CADisplayLink 的回调目标（文件末尾实现）

// ---------------------------------------------------------------------------
// krkrsdl3 的四个回调。
// 它们是 environ/sdl3/sdl3_app.cpp 里的 C++ 函数（非 extern "C"），
// 这里用 C++ 链接声明；宿主编译时**必须把 sdl3_entry.cpp 排除**，
// 否则会和它自带的 main() 冲突（上游注释：iOS 要套壳就别加那个文件）。
// ---------------------------------------------------------------------------
extern "C++" SDL_AppResult SDL_AppInit(void **appstate, int argc, char *argv[]);
extern "C++" SDL_AppResult SDL_AppIterate(void *appstate);
extern "C++" SDL_AppResult SDL_AppEvent(void *appstate, SDL_Event *event);
extern "C++" void SDL_AppQuit(void *appstate, SDL_AppResult result);

// ---------------------------------------------------------------------------
// 状态：整个生命周期都在主线程，除 g_running / g_quitRequested 用原子量
// ---------------------------------------------------------------------------
namespace {

std::atomic<bool> g_running{false};
std::atomic<bool> g_quitRequested{false};

void *g_appstate = nullptr;                 // 引擎侧传出的私有状态
CADisplayLink *g_link = nil;                // 每帧驱动
__weak UIViewController *g_presenter = nil; // 何意味给出的承载 VC
UIViewController *g_engineVC = nil;         // SDL 自己创建的 rootViewController
hmy_krkr_finished_cb g_callback = nullptr;

// argv 必须在引擎运行期间一直有效（TVPParseArguments 会保存指针）
std::string g_gameDir;
std::vector<char *> g_argv;

// SDL 的 UIWindow（iOS 上 SDL 自己 new 一个 UIWindow，见 SDL_uikitwindow.m:203）
UIWindow *g_sdlWindow = nil;

constexpr const char *kTag = "[hmy_krkr]";

void hmy_finish(SDL_AppResult result, const char *message);

// 目录校验：存在、是目录、能读到内容
bool hmy_validate_dir(const char *path, std::string *whyNot) {
    if (path == nullptr || path[0] == '\0') {
        if (whyNot) *whyNot = "游戏目录为空";
        return false;
    }
    struct stat st {};
    if (::stat(path, &st) != 0) {
        if (whyNot) *whyNot = std::string("目录不存在：") + path;
        return false;
    }
    if (!S_ISDIR(st.st_mode)) {
        if (whyNot) *whyNot = std::string("不是目录：") + path;
        return false;
    }
    // 引擎自己也会检查，但提前给出可读原因（TVPSettings.cpp 只写日志）
    NSString *dir = [NSString stringWithUTF8String:path];
    NSFileManager *fm = [NSFileManager defaultManager];
    BOOL hasStartup = [fm fileExistsAtPath:[dir stringByAppendingPathComponent:@"startup.tjs"]];
    BOOL hasXp3 = NO;
    for (NSString *name in [fm contentsOfDirectoryAtPath:dir error:nil]) {
        if ([[name lowercaseString] hasSuffix:@".xp3"]) { hasXp3 = YES; break; }
    }
    if (!hasStartup && !hasXp3) {
        if (whyNot) *whyNot = "目录里没有 startup.tjs 也没有 .xp3（不像 KRKR 游戏）";
        return false;
    }
    // 存档要写到 <游戏目录>/savedata/，必须有写权限
    if (::access(path, W_OK) != 0) {
        if (whyNot) *whyNot = "游戏目录不可写，引擎无法建立 savedata";
        return false;
    }
    return true;
}

// SDL 在 iOS 上自己创建 UIWindow，我们从窗口属性里取出来挂到 UIKit 层级
bool hmy_attach_sdl_window(UIViewController *presenter) {
    int count = 0;
    SDL_Window **windows = SDL_GetWindows(&count);
    if (windows == nullptr || count <= 0) {
        NSLog(@"%s 没有拿到 SDL 窗口", kTag);
        return false;
    }
    SDL_PropertiesID props = SDL_GetWindowProperties(windows[0]);
    if (props == 0) return false;

    UIWindow *uiWindow = (__bridge UIWindow *)SDL_GetPointerProperty(
        props, SDL_PROP_WINDOW_UIKIT_WINDOW_POINTER, nullptr);
    if (uiWindow == nil) {
        NSLog(@"%s 窗口属性里没有 UIKIT_WINDOW_POINTER", kTag);
        return false;
    }
    g_sdlWindow = uiWindow;
    g_engineVC = uiWindow.rootViewController;
    if (g_engineVC == nil) {
        NSLog(@"%s SDL 窗口没有 rootViewController", kTag);
        return false;
    }

    // TODO(MAC-3)：SDL 的 window 自己会 makeKeyAndVisible，可能和 SwiftUI 的窗口抢 key。
    //              这里先不主动 makeKey，只把它的 VC 以全屏形式弹出来。
    g_engineVC.modalPresentationStyle = UIModalPresentationFullScreen;
    [presenter presentViewController:g_engineVC animated:NO completion:nil];
    return true;
}

// 每帧：抽事件 → 交给引擎 → 跑一帧
void hmy_tick(CADisplayLink *link) {
    if (!g_running.load(std::memory_order_acquire)) return;

    // 用户点了"退出"：合成一个 SDL_QUIT 交给引擎，让它自己走正常退出流程
    if (g_quitRequested.exchange(false, std::memory_order_acq_rel)) {
        SDL_Event quit{};
        quit.type = SDL_EVENT_QUIT;
        SDL_AppEvent(g_appstate, &quit);
    }

    SDL_Event event;
    while (SDL_PollEvent(&event)) {
        if (SDL_AppEvent(g_appstate, &event) != SDL_APP_CONTINUE) {
            hmy_finish(SDL_APP_SUCCESS, nullptr);
            return;
        }
    }

    SDL_AppResult rc = SDL_AppIterate(g_appstate);
    if (rc != SDL_APP_CONTINUE) {
        hmy_finish(rc, nullptr);
    }
}

// 收尾：停驱动 → 引擎退出清理 → 收回 UI → 回调 Swift
void hmy_finish(SDL_AppResult result, const char *message) {
    if (!g_running.exchange(false, std::memory_order_acq_rel)) return;   // 防重入

    [g_link invalidate];
    g_link = nil;

    if (g_appstate != nullptr) {
        SDL_AppQuit(g_appstate, result);   // sdl3_app.cpp:561
        g_appstate = nullptr;
    }

    UIViewController *presenter = g_presenter;
    UIViewController *engineVC = g_engineVC;
    g_engineVC = nil;
    g_sdlWindow = nil;

    // TODO(MAC-4)：SDL 窗口销毁顺序（SDL_AppQuit 里是否会 destroy window）
    //              没验证；如果出现野指针/崩溃，这里要改成先 dismiss 再 quit。
    void (^afterDismiss)(void) = ^{
        if (presenter != nil && engineVC != nil && engineVC.presentingViewController != nil) {
            [presenter dismissViewControllerAnimated:NO completion:^{
                if (g_callback) {
                    hmy_krkr_finished_cb cb = g_callback;
                    g_callback = nullptr;
                    cb(result == SDL_APP_SUCCESS ? 0 : 1, message);
                }
            }];
        } else if (g_callback) {
            hmy_krkr_finished_cb cb = g_callback;
            g_callback = nullptr;
            cb(result == SDL_APP_SUCCESS ? 0 : 1, message);
        }
    };

    // 恢复横竖屏限制（引擎侧 TVPSetGameRunningOrientation(false) 会在 AppQuit 里调，
    // 这里再兜一次，避免退出后整个 App 被锁在横屏）
    // TODO(MAC-5)：确认 TVPSetGameRunningOrientation 是否真的在 AppQuit 路径上
    if (@available(iOS 16.0, *)) {
        UIWindowScene *scene = presenter.view.window.windowScene;
        if (scene != nil) {
            UIWindowSceneGeometryPreferencesIOS *pref =
                [[UIWindowSceneGeometryPreferencesIOS alloc]
                    initWithInterfaceOrientations:UIInterfaceOrientationMaskAll];
            [scene requestGeometryUpdateWithPreferences:pref errorHandler:^(NSError *e) {}];
        }
    }
    afterDismiss();
}

}  // namespace

// ---------------------------------------------------------------------------
// C ABI 实现
// ---------------------------------------------------------------------------

extern "C" void hmy_krkr_set_presenter(void *uiViewController) {
    g_presenter = (__bridge UIViewController *)uiViewController;
}

extern "C" int hmy_krkr_is_running(void) {
    return g_running.load(std::memory_order_acquire) ? 1 : 0;
}

extern "C" void hmy_krkr_request_quit(void) {
    if (g_running.load(std::memory_order_acquire)) {
        g_quitRequested.store(true, std::memory_order_release);
    }
}

extern "C" int hmy_krkr_run(const char *game_dir, hmy_krkr_finished_cb cb) {
    // 防重复启动
    if (g_running.load(std::memory_order_acquire)) {
        NSLog(@"%s 已经在运行，忽略重复启动", kTag);
        return -1;
    }
    // 所有 UIKit / SDL 调用都必须在主线程（SDL 的 iOS 视频驱动要求主线程）
    if (![NSThread isMainThread]) {
        NSLog(@"%s hmy_krkr_run 必须在主线程调用", kTag);
        if (cb) cb(1, "hmy_krkr_run must be called on the main thread");
        return -2;
    }
    if (g_presenter == nil) {
        NSLog(@"%s 没有设置 presenter，不知道该把游戏画面挂在谁身上", kTag);
        if (cb) cb(1, "presenter not set");
        return -3;
    }
    std::string whyNot;
    if (!hmy_validate_dir(game_dir, &whyNot)) {
        NSLog(@"%s 参数校验失败：%s", kTag, whyNot.c_str());
        if (cb) cb(1, whyNot.c_str());
        return -4;
    }

    // 组装 argv：argv[0] 是"程序名"，argv[1] 必须是游戏目录（TVPSettings.cpp:253）
    g_gameDir = game_dir;
    g_argv.clear();
    g_argv.push_back(const_cast<char *>("krkrsdl3"));
    g_argv.push_back(const_cast<char *>(g_gameDir.c_str()));
    g_argv.push_back(nullptr);

    g_callback = cb;
    g_quitRequested.store(false, std::memory_order_release);

    // 音频：按 Playback 设置，否则静音键/混音会出问题
    // TODO(MAC-6)：确认引擎内部（sdl3_audio.cpp → SDL3 → AVAudioSession）是否会自己设置；
    //              若会，这里可能重复设置，需要看日志决定保留哪边。
    AVAudioSession *session = [AVAudioSession sharedInstance];
    [session setCategory:AVAudioSessionCategoryPlayback error:nil];
    [session setActive:YES error:nil];

    // 让 SDL 知道我们没走 SDL_main（SDL_main.h:544）
    SDL_SetMainReady();

    g_running.store(true, std::memory_order_release);

    // 真正进入引擎：它会自己 SDL_Init(VIDEO|AUDIO) + 建窗 + 初始化渲染
    // （sdl3_app.cpp:211-236）
    void *appstate = nullptr;
    SDL_AppResult rc = SDL_AppInit(&appstate, static_cast<int>(g_argv.size()) - 1, g_argv.data());
    g_appstate = appstate;

    if (rc != SDL_APP_CONTINUE) {
        // 初始化失败（目录找不到/窗口创建失败/渲染后端全挂）
        NSLog(@"%s SDL_AppInit 失败 rc=%d", kTag, (int)rc);
        hmy_finish(rc, "引擎初始化失败（看 savedata 里的日志）");
        return -5;
    }

    if (!hmy_attach_sdl_window(g_presenter)) {
        // 拿到窗口但挂不上：这是 TODO(MAC-3) 的典型症状
        NSLog(@"%s 无法把 SDL 画面挂到 UIKit", kTag);
        hmy_finish(SDL_APP_FAILURE, "无法显示游戏画面（SDL 窗口挂载失败）");
        return -6;
    }

    // 用 CADisplayLink 驱动，和 SDL 自己在 iOS 上的做法一致
    // （src/main/ios/SDL_sysmain_callbacks.m:45）
    // TODO(MAC-7)：如果真机帧率异常/掉帧，改成 CADisableMinimumFrameDurationOnPhone=true
    g_link = [CADisplayLink displayLinkWithTarget:[HMYKrkrLinkProxy shared]
                                         selector:@selector(onFrame:)];
    [g_link addToRunLoop:[NSRunLoop mainRunLoop] forMode:NSRunLoopCommonModes];

    NSLog(@"%s 引擎已启动 dir=%s", kTag, g_gameDir.c_str());
    return 0;
}

// ---------------------------------------------------------------------------
// CADisplayLink 需要一个 ObjC 目标对象来回调 C++ 函数
// ---------------------------------------------------------------------------
@interface HMYKrkrLinkProxy : NSObject
+ (instancetype)shared;
- (void)onFrame:(CADisplayLink *)link;
@end

@implementation HMYKrkrLinkProxy
+ (instancetype)shared {
    static HMYKrkrLinkProxy *proxy = nil;
    static dispatch_once_t once;
    dispatch_once(&once, ^{ proxy = [[HMYKrkrLinkProxy alloc] init]; });
    return proxy;
}
- (void)onFrame:(CADisplayLink *)link { hmy_tick(link); }
@end
