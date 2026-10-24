# 开源组件声明（iOS 版）

何意味 iOS 版包含下列第三方组件。完整许可证文本见同目录。

## krkrsdl3（KiriKiri 运行时）

```
名称     krkrsdl3
版本     dd1de3d2fd6a10c4f5ef8801e6649f520fc5bc3e
来源     https://github.com/krkrsdl3/krkrsdl3
构建工程 krkrsdl3_build 6059f7857bf6c56bad33a781ec0fc2cc5151b86a
许可     KiriKiri Z 三条款式（本目录 KiriKiri-Z-LICENSE.txt）

Copyright (c), W.Dee and contributors All rights reserved.
Kirikiri Z Project Contributors
Kirikiri Z 64bit Project Contributors
```

## 依赖库（经 vcpkg 引入）

```
oniguruma       BSD-2-Clause
zlib            zlib License
ffmpeg          LGPL-2.1+（启用部分组件时可能为 GPL，最终按实际编译配置核对）
libpng          libpng License
libwebp         BSD-3-Clause
libjpeg-turbo   IJG / BSD-3-Clause
libvorbis       BSD-3-Clause
opusfile        BSD-3-Clause
freetype        FreeType License (FTL) / GPLv2 二选一
plutovg         MIT
SDL3 / SDL3_ttf zlib License
glm             MIT
glad            MIT / CC0
```

> 说明：以上为源码仓库声明；最终以 vcpkg 安装目录中各包的 LICENSE 文件为准，
> 上架/分发前需要逐项核对并补全（尤其是 FFmpeg 的编译选项决定其 LGPL/GPL 归属）。

## 落地位置

iOS「设置 → 关于 → 开源许可」页面展示本文件内容 + 各许可证全文。
Android 版后续同步补一页。
