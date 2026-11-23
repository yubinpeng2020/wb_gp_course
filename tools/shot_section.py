#!/usr/bin/env python3
"""
按 section 截图，用于网页课件改完后的渲染校验。

用法（在 wb_gp_course 目录下执行）：
    PY=/Users/pengyubin/.workbuddy/binaries/python/envs/default/bin/python3.13
    $PY tools/shot_section.py <section-id> <输出前缀> [dark|light|both]
    $PY tools/shot_section.py resource-check r83          # 深色，输出 /tmp/r83_0.png ...
    $PY tools/shot_section.py resource-check r83 both      # 深浅各一套

同时打印该 section 的高度、整页宽度、以及超过 1200px 时自动分段截图。
"""
import asyncio, os, re, sys
from playwright.async_api import async_playwright

HERE = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
URL = 'file://' + os.path.join(HERE, 'index.html')
PART_H = 1200


def balance(path):
    s = open(path, encoding='utf-8').read()
    return {
        'div': (s.count('<div'), s.count('</div>')),
        'section': (s.count('<section'), s.count('</section>')),
        'chars': len(s),
        'slides': len(re.findall(r'<section class="slide', s)),
    }


async def shoot(browser, sid, tag, light):
    pg = await browser.new_page(viewport={"width": 1440, "height": 1000})
    await pg.goto(URL)
    await pg.wait_for_timeout(600)
    if light:
        await pg.evaluate("() => document.body.classList.add('light')")
    await pg.evaluate("""(sid) => {
      document.querySelectorAll('.slide').forEach(s => {
        s.classList.remove('active'); s.style.display = 'none';
      });
      const sec = document.getElementById(sid);
      if (!sec) return;
      sec.style.display = 'block'; sec.classList.add('active');
      sec.style.height = 'auto'; sec.style.overflow = 'visible';
      document.querySelectorAll('.nav-bar,#nav-bar,.page-nav,#page-nav,.nav')
        .forEach(e => e.style.display = 'none');
    }""", sid)
    await pg.wait_for_timeout(500)
    m = await pg.evaluate("""(sid) => {
      const sec = document.getElementById(sid);
      const r = sec.getBoundingClientRect();
      return {top: Math.round(r.top), h: Math.round(r.height),
              docW: document.documentElement.scrollWidth};
    }""", sid)
    theme = 'light' if light else 'dark'
    print(theme, m)
    if m["docW"] > 1441:
        print('  ⚠ 横向溢出: docW =', m["docW"])
    n = (m["h"] + PART_H - 1) // PART_H
    for i in range(n):
        y = m["top"] + i * PART_H
        h = min(PART_H, m["h"] - i * PART_H)
        await pg.screenshot(path=f"/tmp/{tag}{'' if n == 1 else '_' + str(i)}.png",
                            clip={"x": 0, "y": max(0, y), "width": 1440, "height": h},
                            full_page=True)
    print('  parts', n)
    await pg.close()


async def main():
    if len(sys.argv) < 3:
        print(__doc__)
        return
    sid, tag = sys.argv[1], sys.argv[2]
    mode = sys.argv[3] if len(sys.argv) > 3 else 'dark'

    print('--- 静态校验 ---')
    for k, v in balance(os.path.join(HERE, 'index.html')).items():
        print(f'  {k}: {v}')

    async with async_playwright() as p:
        b = await p.chromium.launch(channel="chrome")
        if mode in ('dark', 'both'):
            await shoot(b, sid, tag, False)
        if mode in ('light', 'both'):
            await shoot(b, sid, tag + 'L', True)
        await b.close()


asyncio.run(main())
