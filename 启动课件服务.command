#!/bin/bash
# ============================================================
#  手机编程应用 · 网页课件 —— 局域网服务（macOS）
#  双击运行；关掉这个窗口 = 停止服务
#  用法：双击即可。想换端口就在终端里  ./启动课件服务.command 8080
# ============================================================
cd "$(dirname "$0")" || exit 1
ROOT="$(pwd)"
PORT="${1:-8000}"

clear
echo "=================================================="
echo "   手机编程应用 · 网页课件 —— 局域网服务"
echo "   目录：$ROOT"
echo "=================================================="
echo ""

# ---------- 1) 先确认课件在不在 ----------
if [ ! -f "index.html" ]; then
    echo "  [停] 这个文件夹里没有 index.html。"
    echo "       请把本脚本和 index.html、images 放在同一个文件夹里。"
    echo ""
    read -n 1 -s -r -p "  按任意键关闭…"
    exit 1
fi

# ---------- 2) 找一个能给学生用的 IP ----------
# 优先 Wi-Fi(en0) → 有线(en1/en2…)，跳过 utun/awdl 这类虚拟网卡
pick_ip() {
    for i in en0 en1 en2 en3 en4 en5 en6; do
        ip="$(ipconfig getifaddr "$i" 2>/dev/null)"
        [ -n "$ip" ] && { echo "$ip"; return; }
    done
    ifc="$(route -n get default 2>/dev/null | awk '/interface:/{print $2; exit}')"
    if [ -n "$ifc" ]; then
        ip="$(ipconfig getifaddr "$ifc" 2>/dev/null)"
        [ -n "$ip" ] && { echo "$ip"; return; }
    fi
    for i in $(ifconfig -l 2>/dev/null); do
        case "$i" in
            utun*|awdl*|llw*|bridge*|gif*|stf*|ap1*|XHC*|anpi*) continue ;;
        esac
        ip="$(ipconfig getifaddr "$i" 2>/dev/null)"
        [ -n "$ip" ] && { echo "$ip"; return; }
    done
    echo ""
}

IP="$(pick_ip)"

echo "  学生电脑上打开："
if [ -n "$IP" ]; then
    echo "        http://$IP:$PORT/"
else
    echo "        没检测到局域网地址 —— 先连上教室 Wi-Fi 或插上网线再试"
fi
echo "  本机测试："
echo "        http://127.0.0.1:$PORT/"
echo "  --------------------------------------------------"
echo "  本机检测到的地址（上面那个不对就换一个试）："
for i in $(ifconfig -l 2>/dev/null); do
    case "$i" in
        lo0|utun*|awdl*|llw*|bridge*|gif*|stf*|ap1*|XHC*|anpi*) continue ;;
    esac
    ip="$(ipconfig getifaddr "$i" 2>/dev/null)"
    [ -n "$ip" ] && echo "        $ip   [$i]"
done
echo "  --------------------------------------------------"
echo "  打不开的话：系统设置 → 网络 → 防火墙，允许「终端」或 python3 接入"
echo "  前提：学生电脑和你这台 Mac 在同一个 Wi-Fi / 同一个网段"
echo "  --------------------------------------------------"
echo ""

# ---------- 3) 端口被占就往后挪 ----------
try_port="$PORT"
for _ in 1 2 3 4 5; do
    if ! lsof -nP -iTCP:"$try_port" -sTCP:LISTEN >/dev/null 2>&1; then
        PORT="$try_port"
        break
    fi
    echo "  端口 $try_port 被占用，换一个试试…"
    try_port=$((try_port + 1))
    PORT="$try_port"
done
if lsof -nP -iTCP:"$PORT" -sTCP:LISTEN >/dev/null 2>&1; then
    echo "  [停] 附近几个端口都被占用了。先关掉占用端口的程序，或换个端口："
    echo "       ./启动课件服务.command 9000"
    echo ""
    read -n 1 -s -r -p "  按任意键关闭…"
    exit 1
fi

# ---------- 4) 起服务（有 python3 用 python3，没有就用系统自带 ruby） ----------
echo "  正在启动服务，浏览器马上会自己打开…"
echo "  ★ 关掉这个窗口 = 停止服务"
echo ""

( sleep 1.2; open "http://127.0.0.1:$PORT/" >/dev/null 2>&1 ) &

SRV_PY=""
cleanup() {
    [ -n "$SRV_PID" ] && kill "$SRV_PID" 2>/dev/null
    [ -n "$SRV_PY" ] && rm -f "$SRV_PY" 2>/dev/null
    echo ""
    echo "  --------------------------------------------------"
    echo "  服务已停止。"
    echo "  --------------------------------------------------"
    exit 0
}
trap cleanup INT TERM

# 三十行的服务脚本，不用 -m http.server 是因为它有三处不合适：
#   1. 会乖乖把 .git 目录发给学生（课件目录本身是个 git 仓库）
#   2. 会列出没有 index.html 的目录清单
#   3. 单线程，学生浏览器开一条空连接探路时会卡住后面所有人
write_server() {
    SRV_PY="$(mktemp -t wb_serve)__srv.py"
    cat > "$SRV_PY" <<'PYEOF'
import os
import sys
from http.server import SimpleHTTPRequestHandler, ThreadingHTTPServer

ROOT = os.getcwd()


class Handler(SimpleHTTPRequestHandler):
    timeout = 15  # 空连接最多挂 15 秒，别让它一直占着

    def __init__(self, *a, **kw):
        super().__init__(*a, directory=ROOT, **kw)

    def translate_path(self, path):
        p = super().translate_path(path)
        rel = os.path.relpath(p, ROOT)
        if rel in (".", ""):
            return ROOT
        for part in rel.split(os.sep):
            if part.startswith("."):
                return os.path.join(ROOT, "__blocked__")
        return p

    def list_directory(self, path):
        # 不列目录，学生只需要打开首页
        self.send_error(403, "Forbidden")
        return None

    def log_message(self, fmt, *args):
        who = self.client_address[0] if self.client_address else ""
        if who in ("127.0.0.1", "::1"):
            return
        sys.stderr.write("  [%s] %s\n" % (who, fmt % args))


def main():
    port = int(sys.argv[1]) if len(sys.argv) > 1 else 8000
    srv = ThreadingHTTPServer(("0.0.0.0", port), Handler)
    srv.daemon_threads = True
    sys.stderr.write("  服务已启动，正在等待连接\n\n")
    try:
        srv.serve_forever()
    except KeyboardInterrupt:
        pass
    finally:
        srv.server_close()


if __name__ == "__main__":
    main()
PYEOF
}

if command -v python3 >/dev/null 2>&1; then
    write_server
    echo "  （python3，自带服务脚本）"
    python3 "$SRV_PY" "$PORT" &
    SRV_PID=$!
elif command -v python >/dev/null 2>&1; then
    echo "  （python2 -m SimpleHTTPServer）"
    python -m SimpleHTTPServer "$PORT" &
    SRV_PID=$!
elif command -v ruby >/dev/null 2>&1; then
    echo "  （ruby webrick；没找到 python3，用系统自带 ruby 顶一下）"
    ruby -run -e httpd . -p "$PORT" &
    SRV_PID=$!
else
    echo "  [停] 这台 Mac 上既没有 python3 也没有 ruby，起不了服务。"
    echo "       装一个 Python 3（python.org 或 brew install python）后重试。"
    echo ""
    read -n 1 -s -r -p "  按任意键关闭…"
    exit 1
fi

wait "$SRV_PID"
RC=$?
case "$RC" in
    0|130|143) ;;                       # 正常停止 / Ctrl+C / TERM
    *)  echo ""
        echo "  [停] 服务器异常退出（返回码 $RC）。看上面那行报错：端口被占 / 权限不足。"
        echo "       换个端口再试：./启动课件服务.command 9000"
        echo ""
        read -n 1 -s -r -p "  按任意键关闭…"
        ;;
esac
cleanup
