# ================================================================
#  手机编程应用 · 网页课件 —— 局域网服务（Windows）
#  只用 Windows 自带的 PowerShell，不需要装任何东西
#  由「启动课件服务.bat」调用；也可手动：
#      powershell -ExecutionPolicy Bypass -File server.ps1 -Port 8000
# ================================================================

param([int]$Port = 8000)

$ErrorActionPreference = "Continue"

$root = $PSScriptRoot
if (-not $root) { $root = Split-Path -Parent $MyInvocation.MyCommand.Definition }
if (-not $root) { $root = (Get-Location).Path }
$root = (Resolve-Path $root).Path

# ---------- 1) 找一个能给学生用的 IP ----------
# 装了 VMware / VirtualBox / WSL / VPN 的机器上常有好几个地址，
# 取到 192.168.56.1 这类虚拟网卡学生是连不上的，这里按名字排掉。
function Test-VirtualName([string]$name) {
    if (-not $name) { return $true }
    $n = $name.ToLower()
    $keys = @('vmware','virtualbox','vethernet','hyper-v','loopback','bluetooth',
              'tap-','openvpn','wireguard','docker','wsl','npcap','zerotier','tailscale')
    foreach ($k in $keys) { if ($n.Contains($k)) { return $true } }
    return $false
}

$cand = @()
try {
    $routes = Get-NetRoute -DestinationPrefix '0.0.0.0/0' -ErrorAction SilentlyContinue | Sort-Object RouteMetric
    foreach ($r in $routes) {
        $ips = @()
        try {
            $ips = @(Get-NetIPAddress -AddressFamily IPv4 -InterfaceIndex $r.InterfaceIndex -ErrorAction SilentlyContinue)
        } catch { $ips = @() }
        foreach ($a in $ips) {
            if ($a.IPAddress -notlike '169.254*' -and $a.IPAddress -ne '127.0.0.1') {
                $cand += [pscustomobject]@{ IP = $a.IPAddress; Alias = $a.InterfaceAlias }
            }
        }
    }
} catch { }

if ($cand.Count -eq 0) {
    try {
        foreach ($a in Get-NetIPAddress -AddressFamily IPv4 -ErrorAction SilentlyContinue) {
            if ($a.IPAddress -notlike '169.254*' -and $a.IPAddress -ne '127.0.0.1') {
                $cand += [pscustomobject]@{ IP = $a.IPAddress; Alias = $a.InterfaceAlias }
            }
        }
    } catch { }
}

$ip = ""
foreach ($c in $cand) {
    if (-not (Test-VirtualName $c.Alias)) { $ip = $c.IP; break }
}
if (-not $ip -and $cand.Count -gt 0) { $ip = $cand[0].IP }

# 兜底：老系统没有 Get-NetIPAddress，就直接读 ipconfig
if (-not $ip -or $ip -eq "127.0.0.1") {
    try {
        $lines = & ipconfig 2>$null
        foreach ($l in $lines) {
            if ($l -match "IPv4") {
                $m = [regex]::Match($l, "(\d{1,3}(\.\d{1,3}){3})")
                if ($m.Success) {
                    $c = $m.Groups[1].Value
                    if ($c -notlike "169.254*" -and $c -ne "127.0.0.1") { $ip = $c; break }
                }
            }
        }
    } catch { }
}
if (-not $ip) { $ip = "127.0.0.1" }

Write-Host ""
Write-Host "  =============================================="
Write-Host "   手机编程应用 · 网页课件 —— 局域网服务"
Write-Host "  =============================================="
Write-Host "   学生电脑上打开：  http://$($ip):$Port/"
Write-Host "   本机测试：        http://127.0.0.1:$Port/"
Write-Host "  ----------------------------------------------"
Write-Host "   本机检测到的地址（上面那个不对就换一个试）："
foreach ($c in $cand) {
    $mark = "  "
    if ($c.IP -eq $ip) { $mark = "->" }
    $tag = ""
    if (Test-VirtualName $c.Alias) { $tag = "  (虚拟网卡，学生连不上)" }
    Write-Host "   $mark $($c.IP)   [$($c.Alias)]$tag"
}
Write-Host "   学生打不开时，先让他们照「本机测试」那条地址在自己电脑上打开，"
Write-Host "   能开说明服务没问题，问题在防火墙 / 是不是同一个 Wi-Fi。"
Write-Host "  ----------------------------------------------"

# ---------- 2) 防火墙放行（成功最好，失败也不影响本机） ----------
$ruleName = "课件局域网服务 $Port"
$fwOK = $false
try {
    & netsh advfirewall firewall add rule name="$ruleName" dir=in action=allow protocol=TCP localport=$Port 2>$null | Out-Null
    if ($LASTEXITCODE -eq 0) { $fwOK = $true }
    else {
        & netsh advfirewall firewall show rule name="$ruleName" 2>$null | Out-Null
        if ($LASTEXITCODE -eq 0) { $fwOK = $true }
    }
} catch { }

if ($fwOK) {
    Write-Host "   防火墙：已放行 TCP $Port"
} else {
    Write-Host "   防火墙：没放行成功，学生可能打不开"
    Write-Host "           右键这个 bat -> 以管理员身份运行，就会自动放行"
}
Write-Host "  ----------------------------------------------"
Write-Host ""

# ---------- 3) 起服务 ----------
$listener = New-Object System.Net.Sockets.TcpListener([System.Net.IPAddress]::Any, $Port)
try {
    $listener.Start()
} catch {
    Write-Host "  [失败] 端口 $Port 起不来：$($_.Exception.Message)"
    Write-Host "  先看看是不是被别的程序占了：netstat -ano | findstr $Port"
    Read-Host "  回车退出"
    exit 1
}

Write-Host "  服务已启动，正在等待连接（关掉这个窗口 = 停止服务）"
Write-Host ""

function Get-ContentType([string]$ext) {
    switch ($ext) {
        ".html" { return "text/html; charset=utf-8" }
        ".htm"  { return "text/html; charset=utf-8" }
        ".css"  { return "text/css; charset=utf-8" }
        ".js"   { return "application/javascript; charset=utf-8" }
        ".json" { return "application/json; charset=utf-8" }
        ".md"   { return "text/plain; charset=utf-8" }
        ".png"  { return "image/png" }
        ".jpg"  { return "image/jpeg" }
        ".jpeg" { return "image/jpeg" }
        ".gif"  { return "image/gif" }
        ".webp" { return "image/webp" }
        ".svg"  { return "image/svg+xml" }
        ".ico"  { return "image/x-icon" }
        ".woff2" { return "font/woff2" }
        ".woff" { return "font/woff" }
        ".ttf"  { return "font/ttf" }
        ".pdf"  { return "application/pdf" }
        ".mp4"  { return "video/mp4" }
        ".docx" { return "application/vnd.openxmlformats-officedocument.wordprocessingml.document" }
        ".pptx" { return "application/vnd.openxmlformats-officedocument.presentationml.presentation" }
        default { return "application/octet-stream" }
    }
}

function Send-Bytes($stream, [string]$head, [byte[]]$body, [bool]$isHead) {
    $hb = [System.Text.Encoding]::UTF8.GetBytes($head)
    $stream.Write($hb, 0, $hb.Length)
    if (-not $isHead -and $body -and $body.Length -gt 0) {
        $stream.Write($body, 0, $body.Length)
    }
}

# ---------- 4) 一条连接的处理 ----------
# 写成函数而不是塞进 while 里，是为了能用 return 提前收工：
# PowerShell 在 try 块里用 continue 有几个版本相关的坑，return 没有。
function Send-Plain($stream, [string]$status, [string]$text, [bool]$isHead) {
    $msg = [System.Text.Encoding]::UTF8.GetBytes($text)
    $head = "HTTP/1.1 $status`r`nContent-Type: text/plain; charset=utf-8`r`nContent-Length: $($msg.Length)`r`nConnection: close`r`n`r`n"
    Send-Bytes $stream $head $msg $isHead
}

function Handle-Client($client) {
    $stream = $null
    try {
        $stream = $client.GetStream()

        # 读请求头（读到空行为止）
        $buffer = New-Object byte[] 8192
        $sb = New-Object System.Text.StringBuilder
        $got = $false
        while (-not $got) {
            $n = $stream.Read($buffer, 0, $buffer.Length)
            if ($n -le 0) { break }
            [void]$sb.Append([System.Text.Encoding]::UTF8.GetString($buffer, 0, $n))
            if ($sb.ToString().Contains("`r`n`r`n")) { $got = $true }
            if ($sb.Length -gt 32768) { break }
        }

        $req = $sb.ToString()
        if (-not $req) { return }
        $requestLine = ($req -split "`r`n")[0]
        if (-not $requestLine) { return }

        $parts = $requestLine -split " "
        if ($parts.Length -lt 2) { return }
        $method = $parts[0].ToUpper()
        $rawPath = $parts[1]
        $isHead = ($method -eq "HEAD")

        $path = $rawPath.Split("?")[0].Split("#")[0]
        if (-not $path -or $path -eq "/") { $path = "/index.html" }
        try { $path = [System.Uri]::UnescapeDataString($path) } catch { }
        $path = $path.TrimStart("/")
        $path = $path -replace "/", "\"

        # 一点点探路用的小接口
        if ($path -eq "__ping") {
            Send-Plain $stream "200 OK" "ok" $isHead
            return
        }

        # 不让访问 .git 这类隐藏目录
        if ($path.StartsWith(".")) {
            Send-Plain $stream "404 Not Found" "404 Not Found" $isHead
            return
        }

        $file = Join-Path $root $path
        # 越权检查：不让 ../ 跳出课件目录
        $full = ""
        try { $full = [System.IO.Path]::GetFullPath($file) } catch { $full = "" }
        if (-not $full -or -not $full.StartsWith($root, [System.StringComparison]::OrdinalIgnoreCase)) {
            Send-Plain $stream "403 Forbidden" "403 Forbidden" $isHead
            Write-Host ("  [403] {0}" -f $path)
            return
        }

        # 目录自动找 index.html
        if (Test-Path $full -PathType Container) {
            $full = Join-Path $full "index.html"
        }

        if (-not (Test-Path $full -PathType Leaf)) {
            Send-Plain $stream "404 Not Found" ("404 Not Found: " + $path) $isHead
            Write-Host ("  [404] {0}" -f $path)
            return
        }

        $bytes = [System.IO.File]::ReadAllBytes($full)
        $ct = Get-ContentType ([System.IO.Path]::GetExtension($full).ToLower())
        $head2 = "HTTP/1.1 200 OK`r`nContent-Type: $ct`r`nContent-Length: $($bytes.Length)`r`nCache-Control: no-cache`r`nConnection: close`r`n`r`n"
        Send-Bytes $stream $head2 $bytes $isHead

        # 只打印外网来的访问，本机自己测试不刷屏
        $who = ""
        try { $who = $client.Client.RemoteEndPoint.Address.ToString() } catch { }
        if ($who -and $who -ne "127.0.0.1" -and $who -ne "::1") {
            Write-Host ("  [{0}] {1}" -f $who, $path)
        }
    } catch {
        # 超时、学生刷新页面时断开，都是常态，不打整段堆栈
        $msg = $_.Exception.Message
        if ($msg -notmatch "超时|timed out|终止|aborted|forced|远程主机|An existing connection") {
            Write-Host ("  [异常] " + $msg)
        }
    } finally {
        if ($stream) { try { $stream.Close() } catch { } }
        if ($client) { try { $client.Close() } catch { } }
    }
}

# ---------- 5) 收连接 ----------
while ($true) {
    $client = $null
    try {
        $client = $listener.AcceptTcpClient()
    } catch {
        break
    }

    # 关键：先卡一个读超时。浏览器有时会先开一条连接探路（preconnect）却不发数据，
    # 不设超时的话，一条空连接就能把整个服务卡住，学生端表现为「一直在转圈」。
    try {
        $client.ReceiveTimeout = 5000
        $client.SendTimeout = 15000
    } catch { }

    Handle-Client $client
}

Write-Host ""
Write-Host "  服务已停止。"
