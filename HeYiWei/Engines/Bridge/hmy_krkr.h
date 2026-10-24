//
//  hmy_krkr.h
//  何意味 iOS 版 ←→ krkrsdl3 的最小 C 接口契约
//
//  设计依据见 docs/KRKR_IOS_HOST.md：
//    - 引擎入口是 SDL3 回调式（SDL_AppInit/Event/Iterate/Quit，environ/sdl3/sdl3_app.cpp）
//    - 游戏目录通过 argv[1] 传入（core/utils/TVPSettings.cpp:253）
//    - 存档写到 <游戏目录>/savedata/（同文件 :273）
//
//  当前状态：**只有契约，没有实现**。实现要等 macOS 上编出 arm64 库之后写
//  hmy_krkr_host.mm。Swift 侧不得在未实现时假装启动成功。
//

#ifndef HMY_KRKR_H
#define HMY_KRKR_H

#ifdef __cplusplus
extern "C" {
#endif

/// 引擎运行结束（正常退出/失败）后的回调；会在主线程调用。
typedef void (*hmy_krkr_finished_cb)(int exit_code, const char *message);

/// 启动引擎并接管当前 UI（内部调用 SDL_EnterAppMainCallbacks，阻塞直到游戏结束）。
///
/// @param game_dir  游戏根目录的 UTF-8 绝对路径（里面应能直接找到 startup.tjs 或 data.xp3）。
///                  必须在调用期间保持可读可写（存档写到 <game_dir>/savedata/）。
/// @param cb        结束时回调，可为 NULL。
/// @return 0 = 已启动（回调里再给最终结果）；非 0 = 立即失败（参数非法/目录不可访问）。
int hmy_krkr_run(const char *game_dir, hmy_krkr_finished_cb cb);

/// 请求退出当前游戏（等价于引擎的退出事件）。
void hmy_krkr_request_quit(void);

/// 引擎是否正在运行（0/1）。用于 SwiftUI 侧判断卡片是否可点。
int hmy_krkr_is_running(void);

/// 指定承载游戏画面的 UIViewController（传 `(void *)UIViewController*`，可为 NULL）。
/// 之所以用 void* 是为了让这个头文件保持纯 C、不依赖 UIKit。
/// 必须在主线程、且 hmy_krkr_run 之前调用。
void hmy_krkr_set_presenter(void *ui_view_controller);

#ifdef __cplusplus
}
#endif

#endif /* HMY_KRKR_H */
