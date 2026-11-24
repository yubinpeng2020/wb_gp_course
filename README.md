# WorkBuddy 实操课 · 网页课件

面向中职教师的 AI 培训课件（Part 2 · WorkBuddy 实操），单页 HTML 幻灯片，支持键盘翻页、深浅主题切换、字号调节。

## 在线访问

部署到 GitHub Pages 后访问：

```
https://yubinpeng2020.github.io/wb_gp_course/
```

## 本地预览

```bash
python3 -m http.server 8000
```

打开 http://localhost:8000

## 课堂上给学生看（局域网）

想让学生用自己的电脑看，用下面两个脚本之一：双击就行，不需要装任何东西。

| 系统 | 双击这个 | 靠什么起服务 |
| --- | --- | --- |
| macOS | `启动课件服务.command` | 系统自带的 python3（没有则回退 ruby） |
| Windows | `启动课件服务.bat` | 系统自带的 PowerShell，零依赖 |

启动后窗口里会打出一行 `http://192.168.x.x:8000/`，把这一行发到学生群里，学生在浏览器里打开即可（手机也行）。
关掉那个窗口 = 停止服务。想换端口：`./启动课件服务.command 9000`、`启动课件服务.bat 9000`。

学生打不开时按这个顺序排查：

1. 先在自己的电脑上试 `http://127.0.0.1:8000/`，能打开说明服务没问题；
2. 确认学生和你在同一个 Wi-Fi / 同一网段（校园网常做设备隔离，这时改连手机热点）；
3. Windows 上如果提示「防火墙没放行」，关掉窗口，右键 `启动课件服务.bat` → 以管理员身份运行；
4. macOS 上第一次运行若被拦截，系统设置 → 网络 → 防火墙，允许「终端」接入。

## 使用说明

- `←` / `→` 或 `PageUp` / `PageDown` 翻页
- 底部工具栏可调字号（A- / A+）、切换深色 / 浅色主题
- 左侧导航可直接跳转到任意章节
- 代码块右上角「复制」按钮可一键复制提示词

## 拷到 U 盘带走

双击 `打包到U盘.command`，会把课件拷到固定的 U 盘位置：

```
/Volumes/NO NAME/AI赋能中职科研能力提升培训/wb_gp_course
```

只拷运行要用的（约 28 MB）：`index.html` + `images/` + 三个启动脚本 + 自动生成的「使用说明.txt」。`.git`、`_备份_*.html`、`tools/` 都不拷。U 盘没插时会自动让你重新选目录。

两个实现细节（踩过坑）：

- U 盘是 **FAT32**，macOS 直接覆盖同名文件会报 `Operation not permitted`（rsync 先写临时名再 rename 这一步在 FAT32 上会失败）。所以脚本一律**先删再拷**，`index.html` 和 `images/` 每次整份重拷，顺带保证 U 盘上的图和源目录完全一致。
- `chmod`、Finder 打开目录都会让 macOS 往 FAT32 写 `._xxx` 影子文件，在 Windows 上显示成看不懂的东西。拷完会统一清掉。

## 目录结构

```
index.html      课件主文件（单文件，样式与脚本内嵌）
images/         课件截图与图标资源
.nojekyll       跳过 GitHub Pages 的 Jekyll 处理
启动课件服务.command / .bat / server.ps1   局域网服务（macOS / Windows）
打包到U盘.command                           打包到固定 U 盘位置
```

## 更新课件

`index.html` 就是唯一的工作副本，直接改它、直接在这里提交，不再从别处同步。

（`03_课件成品/Part2_实操网页课件/` 是历史存档，已停止同步，不要再改那里。）
