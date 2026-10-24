# SDL3 iOS 生命周期调查与结论

日期：2026-10-23 ｜ 对象：SDL3（release-3.2.x）+ krkrsdl3

## 一、结论

| 问题 | 结论 |
|---|---|
| `SDL_EnterAppMainCallbacks()` 能在 SwiftUI 跑起来之后当普通函数调用吗 | **不能** |
| 那 krkrsdl3 能不能嵌进何意味 | **能**，但要绕开 SDL 的 main 回调封装，自己驱动引擎的四个回调 |
| 阻塞点在哪里 | `SDL_RunApp` → `UIApplicationMain`；`SDL_EnterAppMainCallbacks` 退出时 `exit()` |

## 二、证据（SDL3 源码原文）

### 1. `SDL_sysmain_callbacks.m`（src/main/ios/）

```objc
// SDL_RunApp will land in UIApplicationMain, which calls SDL_main from
// postFinishLaunch, which calls this.
// When we return from here, we're living in the RunLoop, and a CADisplayLink
// is firing regularly for us.
int SDL_EnterAppMainCallbacks(int argc, char* argv[], SDL_AppInit_func appinit,
                              SDL_AppIterate_func appiter, SDL_AppEvent_func appevent,
                              SDL_AppQuit_func appquit)
{
    SDL_AppResult rc = SDL_InitMainCallbacks(argc, argv, appinit, appiter, appevent, appquit);
    if (rc == SDL_APP_CONTINUE) {
        globalDisplayLink = [[SDLIosMainCallbacksDisplayLink alloc] init:appiter quitfunc:appquit];
        ...
        return 0;  // falls all the way out of SDL_main, UIApplicationMain keeps running
    }
    SDL_QuitMainCallbacks(rc);
    exit((rc == SDL_APP_FAILURE) ? 1 : 0);
    return 1;
}
```

两个致命点：

1. 它假设自己是在 `UIApplicationMain` 启动流程里被调用的（`postFinishLaunch` → `SDL_main`）。
   SwiftUI App 已经在跑的时候再调，等于在这个进程里再走一遍 SDL 的 app 启动假设。
2. 引擎结束（`SDL_APP_SUCCESS` / `SDL_APP_FAILURE`）时它执行 `exit()` —— **直接终止进程**。
   我们要的「退出游戏回到何意味」在这个 API 下根本不存在。

### 2. `SDL_uikitappdelegate.m:42-62`

```objc
int SDL_RunApp(int argc, char* argv[], SDL_main_func mainFunction, void * reserved)
{
    ...
    UIApplicationMain(argc, argv, nil, [SDLUIKitDelegate getAppDelegateClassName]);
    ...
}
```

`SDL_RunApp` 就是 `SDL_MAIN_USE_CALLBACKS` 下 `main()` 会走到的地方；它调用 `UIApplicationMain`。
我们的 App 里 `UIApplicationMain` 已经由 SwiftUI 调过了 —— 这就是「双 UIApplicationMain」的出处。

### 3. SDL 自己的 iOS 循环模型

`SDL_sysmain_callbacks.m:45-71`：`CADisplayLink` 每帧调 `SDL_IterateMainCallbacks(true)`，
即 iterate 由 RunLoop 驱动，**不是阻塞式 while 循环**。
这一点对我们有利：我们完全可以自己挂一个 CADisplayLink，逐帧调引擎的 `SDL_AppIterate`。

## 三、krkrsdl3 的四个回调是「普通函数」

`environ/sdl3/sdl3_app.cpp` 里：

```cpp
SDL_AppResult SDL_AppInit(void** appstate, int argc, char* argv[])   // 198
SDL_AppResult SDL_AppEvent(void* appstate, SDL_Event* event)         // 425
SDL_AppResult SDL_AppIterate(void* appstate)                         // 543
void          SDL_AppQuit(void* appstate, SDL_AppResult result)      // 561
```

它们不依赖 SDL_main 的胶水：`SDL_AppInit` 内部自己完成
`SDL_Init(SDL_INIT_VIDEO | SDL_INIT_AUDIO)`（:211）、建窗（:218）、初始化渲染后端（:234）。
所以宿主可以：

```
SDL_SetMainReady()
SDL_AppInit(&state, argc, argv)     ← 自己调
CADisplayLink 每帧：
    SDL_PollEvent → SDL_AppEvent
    SDL_AppIterate
结束时 SDL_AppQuit(window 清理由引擎自己做)
```

这正是 `hmy_krkr_host.mm` 的实现方式。

## 四、画面怎么显示

SDL3 在 iOS 上**自己 new 一个 UIWindow**（`SDL_uikitwindow.m:203`）：

```objc
UIWindow *uiwindow = [[SDL_uikitwindow alloc] initWithFrame:CGRectMake(...)];
...
data.uiwindow.rootViewController = ...   // :353 附近
```

并且公开了窗口属性键（`SDL_video.h:1549`）：

```c
#define SDL_PROP_WINDOW_UIKIT_WINDOW_POINTER  "SDL.window.uikit.window"
```

所以宿主取画面的方式（**不需要改引擎**）：

```objc
SDL_Window **wins = SDL_GetWindows(&count);
SDL_PropertiesID props = SDL_GetWindowProperties(wins[0]);
UIWindow *uiWindow = SDL_GetPointerProperty(props, SDL_PROP_WINDOW_UIKIT_WINDOW_POINTER, NULL);
UIViewController *vc = uiWindow.rootViewController;
[presenter presentViewController:vc animated:NO completion:nil];
```

这也直接支撑了你要的第二方案：**SwiftUI → present 一个专门的 VC → SDL 视图挂在里面**。

## 五、退出路径

引擎退出时（`SDL_AppIterate` 返回非 `SDL_APP_CONTINUE`，或收到 `SDL_EVENT_QUIT`）：

```
hmy_finish()
  → invalidate CADisplayLink
  → SDL_AppQuit(state, result)
  → dismiss SDL 的 VC
  → 回调 Swift（exit_code, message）
```

**不会 exit()**，进程还活着，所以能回到何意味 —— 这正是验收 B 要求的东西。

## 六、仍需 Mac 验证的边界（不猜）

| 编号 | 待验证点 | 失败时的最小改动边界 |
|---|---|---|
| MAC-1 | `SDL_AppInit` 自己调用时，SDL 是否要求 AppDelegate 是 `SDLUIKitDelegate` | 若是：宿主里接管 UIApplicationDelegate 转发，或改用 SDL 的 delegate 分类；不动引擎 |
| MAC-2 | 非 `SDL_RunApp` 路径下 SDL 是否注册了生命周期观察（前后台/内存警告） | 若缺：宿主手动转发 `UIApplication` 通知给 SDL；不动引擎 |
| MAC-3 | SDL 的 UIWindow 自己 makeKeyAndVisible，可能抢 key window | 改为把 `rootViewController.view` 加进容器 VC，而不是 present |
| MAC-4 | `SDL_AppQuit` 与窗口/VC 的销毁顺序 | 调整宿主顺序（先 dismiss 再 quit） |
| MAC-5 | 横竖屏锁定（`TVPSetGameRunningOrientation`）与 Info.plist 的配合 | 改 Info.plist 允许的方向 + 宿主恢复 |
| MAC-6 | AVAudioSession 是否与引擎内部重复设置 | 只保留一边 |
| MAC-7 | CADisplayLink 帧率 / 高刷 | Info.plist `CADisableMinimumFrameDurationOnPhone` |
| MAC-8 | `sdl3_entry.cpp` 必须从宿主编译里排除（否则重复 main） | 构建脚本 |

## 七、对验收 A / B 的界定

- **验收 A**：官方 `krkrsdl3.app` 在 iPhone 上打开 Documents 里的游戏能出画面。
  它走的是 SDL 自己的 `UIApplicationMain` + `SDL_RunApp` 路径，**证明不了**能嵌入。
- **验收 B**：何意味 SwiftUI → 卡片 → `hmy_krkr_run` → 游戏画面 → 退出 → 回何意味。
  真正的未知点集中在 MAC-1/2/3/4（AppDelegate、生命周期、窗口归属、销毁顺序），
  引擎本身和渲染链路与 A 相同。

A 通过只说明「引擎能在 iOS 跑」；B 才是产品形态，两者的失败原因完全不同。
