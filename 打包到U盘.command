#!/bin/bash
# ============================================================
#  双击这个文件 → 把网页课件拷到 U 盘
#  只拷「运行要用」的东西（约 28 MB）：index.html + images/ + 三个启动脚本
#  不拷 .git、_备份_*.html、tools/（都是开发用的）
#  固定目标见下面 FIXED_DEST；那个盘没插时会自动弹窗让你另选
# ============================================================
cd "$(dirname "$0")" || exit 1
SRC="$(pwd)"

# ★ 固定目标：平时插这个 U 盘双击就行
FIXED_DEST="/Volumes/NO NAME/AI赋能中职科研能力提升培训/wb_gp_course"

clear
echo "=================================================="
echo "   手机编程应用 · 网页课件 → 打包到 U 盘"
echo "   来源：$SRC"
echo "=================================================="
echo ""

# ---------- 0) 先确认课件本身在 ----------
if [ ! -f "index.html" ]; then
    echo "  [停] 这个文件夹里没有 index.html。"
    echo "       请把本脚本和 index.html、images 放在同一个文件夹里。"
    echo ""
    read -n 1 -s -r -p "  按任意键关闭…"
    exit 1
fi
if [ ! -d "images" ]; then
    echo "  [停] 这个文件夹里没有 images 目录，课件会全是缺图占位。"
    echo ""
    read -n 1 -s -r -p "  按任意键关闭…"
    exit 1
fi

# ---------- 1) 定目标 ----------
DEST=""
if [ -n "$1" ]; then
    DEST="$1"                                  # 命令行/测试时直接给完整目标
elif [ -n "$PACK_TARGET" ]; then
    DEST="$PACK_TARGET"
elif [ -d "/Volumes/NO NAME" ]; then           # 固定那个 U 盘在，直接用
    DEST="$FIXED_DEST"
    echo "目标（固定）：$DEST"
else
    echo "没找到固定目标 /Volumes/NO NAME，改成自动找盘…"
    CAND=""
    N=0
    for v in /Volumes/*; do
        [ -d "$v" ] || continue
        name="$(basename "$v")"
        [ "$name" = "Macintosh HD" ] && continue
        [ -w "$v" ] || continue
        CAND="$v"; N=$((N+1))
    done
    if [ "$N" -eq 1 ]; then
        DEST="$CAND/AI赋能中职科研能力提升培训/wb_gp_course"
        echo "检测到可移动磁盘：$CAND"
        printf "就拷到 %s ？[Y/n] " "$DEST"
        read -r ans
        case "$ans" in
            n|N) DEST="" ;;
        esac
    fi
    if [ -z "$DEST" ]; then
        echo "请在弹出的窗口里选择 U 盘（或目标文件夹）…"
        PICK="$(osascript -e 'POSIX path of (choose folder with prompt "选择 U 盘（或目标文件夹）")' 2>/dev/null)"
        PICK="${PICK%/}"
        [ -n "$PICK" ] && DEST="$PICK/wb_gp_course"
    fi
    if [ -z "$DEST" ]; then
        echo ""
        echo "没有选中目标，已取消。"
        read -n 1 -s -r -p "  按任意键关闭…"
        exit 1
    fi
fi

DEST="${DEST%/}"

# 防呆：目标不能是课件目录本身，也不能在它里面（否则会自己拷自己）
case "$DEST" in
    "$SRC"|"$SRC"/*)
        echo ""
        echo "  [停] 目标是课件目录本身（$DEST），已取消。"
        echo "       把脚本放在要拷出去的目录之外，或换个目标。"
        read -n 1 -s -r -p "  按任意键关闭…"
        exit 1 ;;
esac

if [ -d "$DEST" ] && [ -n "$(ls -A "$DEST" 2>/dev/null)" ]; then
    echo ""
    echo "注意：$DEST 里已经有东西，会整份覆盖（index.html 与 images 重新拷一遍）。"
    printf "继续？[Y/n] "
    read -r ans
    case "$ans" in
        n|N) echo "已取消。"; read -n 1 -s -r -p "  按任意键关闭…"; exit 1 ;;
    esac
fi
mkdir -p "$DEST" || { echo "  [停] 建目录失败：$DEST"; read -n 1 -s -r -p "  按任意键关闭…"; exit 1; }

echo ""
echo "正在拷贝到：$DEST"
echo ""

# ------------------------------------------------------------
# 为什么要「先删再拷」而不是直接覆盖：
# U 盘是 FAT32，macOS 往 FAT32 上覆盖同名文件时，rsync 会先写临时名再 rename，
# 这一步在 FAT32 上会报 Operation not permitted（第二次打包时试过，图全没拷过去）。
# 所以这里一律先删掉目标、再从干净状态拷，顺带保证 U 盘上的图和源目录完全一致。
# ------------------------------------------------------------

# ---------- 2) 拷 index.html ----------
rm -f "$DEST/index.html" 2>/dev/null
cp -X index.html "$DEST/" || {
    echo "  [停] index.html 拷贝失败。U 盘可能满了，或者被占用。"
    read -n 1 -s -r -p "  按任意键关闭…"
    exit 1
}
echo "  网页 1 个（index.html，$(du -h index.html | awk '{print $1}')）"

# ---------- 3) 拷 images ----------
rm -rf "$DEST/images" 2>/dev/null
mkdir -p "$DEST/images"
cp -RX images/. "$DEST/images/" 2>/dev/null || cp -R images/. "$DEST/images/" 2>/dev/null
find "$DEST/images" -name '.DS_Store' -exec rm -f {} + 2>/dev/null
echo "  图片 $(ls -1 "$DEST/images" 2>/dev/null | wc -l | tr -d ' ') 个"

# ---------- 4) 拷三个启动脚本（mac / windows 都要带） ----------
srv=0
for f in 启动课件服务.command 启动课件服务.bat server.ps1; do
    if [ -f "$f" ]; then
        rm -f "$DEST/$f" 2>/dev/null
        cp -X "$f" "$DEST/" && srv=$((srv+1))
    fi
done
# FAT32 上 chmod 可能不生效（挂载时就是可执行的），失败也不影响
chmod +x "$DEST/启动课件服务.command" 2>/dev/null
echo "  启动脚本 $srv 个"

if [ "$srv" -lt 3 ]; then
    echo "  ⚠ 少拷了启动脚本（应该 3 个）——检查本目录下的 启动课件服务.command / .bat / server.ps1"
fi

# ---------- 5) 生成「使用说明.txt」（GBK + CRLF，Windows 记事本直接能读） ----------
if command -v iconv >/dev/null 2>&1; then
    TMP_TXT="$(mktemp -t wb_readme)"
    cat > "$TMP_TXT" <<'TXT'
AI赋能中职科研能力提升培训 - 网页课件
==========================================

【教室里怎么用（Windows 电脑）】
1. 插上 U 盘 → AI赋能中职科研能力提升培训 → wb_gp_course
2. 双击「启动课件服务.bat」
3. 窗口里会显示一行  http://192.168.x.x:8000/
   把这一行发到学生群，学生用浏览器打开就行（手机也可以）
4. 关掉那个黑窗口 = 停止服务

【学生打不开，按这个顺序查】
1. 先在你自己电脑上打开 http://127.0.0.1:8000/ ，能开说明服务没问题
2. 确认学生和你连的是同一个 Wi-Fi（校园网常做设备隔离，这时改连手机热点）
3. 若窗口提示「防火墙没放行」：关掉窗口，右键「启动课件服务.bat」→ 以管理员身份运行

【在 Mac 上】
双击「启动课件服务.command」。

【注意】
不要单独把 index.html 发给别人，图片都在 images 文件夹里，要整个文件夹一起拷。
TXT
    rm -f "$DEST/使用说明.txt" 2>/dev/null
    if iconv -f UTF-8 -t GBK "$TMP_TXT" 2>/dev/null | awk '{printf "%s\r\n", $0}' > "$DEST/使用说明.txt"; then
        echo "  使用说明 1 个"
    else
        echo "  ⚠ 使用说明.txt 生成失败（不影响使用）"
    fi
    rm -f "$TMP_TXT"
fi

# ---------- 5.5) 清掉 macOS 在 FAT32 上留下的 ._ 影子文件 ----------
# chmod 改权限、Finder 打开过目录，都会让 macOS 往 FAT32 写 AppleDouble 文件，
# 在 Windows 上会显示成「._启动课件服务.command」这种看不懂的东西，直接删掉。
find "$DEST" -maxdepth 2 \( -name "._*" -o -name ".DS_Store" \) -exec rm -f {} + 2>/dev/null

echo ""
echo "--------------------------------------------------"
printf "完成。合计 %s\n" "$(du -sh "$DEST" 2>/dev/null | awk '{print $1}')"
echo "U 盘上的位置：$DEST"
echo "（index.html 与 images 每次整份重拷；其他文件同名覆盖）"
echo ""

# ---------- 6) 拷后自检：页面上引用了、但 U 盘里没有的图 ----------
if command -v python3 >/dev/null 2>&1; then
    miss=$(cd "$DEST" && python3 - <<'PY' 2>/dev/null
import glob, os, re, urllib.parse, unicodedata
N = lambda s: unicodedata.normalize('NFC', s)
ref = set()
for f in glob.glob('*.html'):
    s = open(f, encoding='utf-8', errors='ignore').read()
    for m in re.finditer(r'(?:src|href)="((?:images|vendor)/[^"]+)"', s):
        ref.add(N(urllib.parse.unquote(m.group(1)).split('?')[0]))
have = {N(os.path.relpath(os.path.join(r, f), '.').replace('\\', '/'))
        for r, _, fs in os.walk('.') for f in fs}
print(len([p for p in ref if p not in have]))
PY
)
    echo "自检：页面引用但没拷到的图片 $miss 张（多数是课件里本来就留着的缺图占位，属正常）"
fi

echo "--------------------------------------------------"
echo "教室里（Windows）：插 U 盘 → 进 wb_gp_course 文件夹 → 双击「启动课件服务.bat」"
echo "学生访问窗口里显示的那个 http://IP:8000/ 地址"
echo "--------------------------------------------------"

[ -z "$1" ] && open "$DEST" 2>/dev/null
echo ""
read -n 1 -s -r -p "  按任意键关闭这个窗口…"
