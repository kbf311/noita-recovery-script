@echo off
setlocal
chcp 932 > nul

REM 実行ファイルのディレクトリへ移動
cd /d "%~dp0"

REM PowerShellスクリプトの実行
powershell.exe -ExecutionPolicy Bypass -File "%~dp0Backup-Noita.ps1"
if %ERRORLEVEL% NEQ 0 (
    pause
)

echo.
echo 処理が完了しました。
pause
