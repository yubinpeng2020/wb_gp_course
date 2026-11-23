# tools

改完 `index.html` 后的校验脚本。不依赖任何账号，换账号照旧可用。

## shot_section.py

```bash
PY=/Users/pengyubin/.workbuddy/binaries/python/envs/default/bin/python3.13
$PY tools/shot_section.py <section-id> <输出前缀> [dark|light|both]
```

同时做两件事：

1. **静态校验**：打印 `div` / `section` 标签配平、字符数、slide 数
2. **渲染校验**：只显示目标 section，无缝导出整段截图到 `/tmp/<前缀>.png`（超过 1200px 自动分段），并检查是否横向溢出

依赖：playwright + 本机 Chrome（`channel="chrome"`）。

### 模板要点

- 先把其它 slide 的 `active` 去掉并 `display:none`，目标 slide 设 `height:auto;overflow:visible`
- 必须 `full_page=True` 才能用 `clip`
- 浅色主题是 `document.body.classList.add('light')`，**不是** `data-theme`
- 无头 Chrome 最小窗宽 500px；要看 390px 需临时注入 `body{width:390px}`

### h2 里的 emoji 是单色剪影，不是坏图

`h2` 用了 `background:linear-gradient(...)` + `background-clip:text` + `-webkit-text-fill-color:transparent`，
所有彩色 emoji 都会被压成"渐变填充的字形剪影"。挑 emoji 只看**剪影轮廓能不能认出来**：
🔍 🚀 🧠 ⭐ ⚠ 没问题；`🚨`（≈纯色圆角块）、`🗺`（≈一张白卡片）读起来像坏图。

临时验证：注入 `h2{background:none!important;-webkit-text-fill-color:currentColor!important;}` 再看。
