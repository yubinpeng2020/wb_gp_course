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

## 使用说明

- `←` / `→` 或 `PageUp` / `PageDown` 翻页
- 底部工具栏可调字号（A- / A+）、切换深色 / 浅色主题
- 左侧导航可直接跳转到任意章节
- 代码块右上角「复制」按钮可一键复制提示词

## 目录结构

```
index.html      课件主文件（单文件，样式与脚本内嵌）
images/         课件截图与图标资源
.nojekyll       跳过 GitHub Pages 的 Jekyll 处理
```

## 更新课件

课件源文件位于本地：

```
03_课件成品/Part2_实操网页课件/Part2_WorkBuddy实操网页课件.html
```

同步到本仓库：

```bash
cp "../03_课件成品/Part2_实操网页课件/Part2_WorkBuddy实操网页课件.html" index.html
rsync -a --exclude='.DS_Store' "../03_课件成品/Part2_实操网页课件/images/" images/
git add -A && git commit -m "更新课件" && git push
```
