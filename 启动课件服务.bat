@echo off
chcp 936 >nul
title 手机编程应用 · 网页课件 - 局域网服务
cd /d "%~dp0"

echo ================================================
echo    手机编程应用 · 网页课件 - 局域网访问服务
echo    （关闭本窗口 = 停止服务）
echo ================================================
echo.
echo   学生电脑上打开窗口里给出的那个 http://192.168.x.x 地址
echo   学生打不开时，先在自己电脑上试 http://127.0.0.1:8000/
echo   能打开说明服务没问题，问题在防火墙或不在同一个 Wi-Fi
echo.

set PORT=8000
if not "%~1"=="" set PORT=%~1

powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0server.ps1" -Port %PORT%
set RC=%ERRORLEVEL%
echo.
if not "%RC%"=="0" echo 服务异常退出（代码 %RC%），把上面的提示发我。
echo 如果提示防火墙没放行：关掉本窗口，右键这个 bat - 以管理员身份运行
echo.
pause
