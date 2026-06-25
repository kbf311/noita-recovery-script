# Noita Recovery Script - Backup Module
# Noitaのセーブデータをバックアップするスクリプト

# エラー時に停止
$ErrorActionPreference = "Stop"

# Noitaプロセスのチェック
$noitaProcess = Get-Process -Name "noita" -ErrorAction SilentlyContinue
if ($noitaProcess) {
    Write-Host "警告: Noitaが起動中です。バックアップを中断します。" -ForegroundColor Yellow
    Write-Host "Noitaを終了してから再度実行してください。" -ForegroundColor Yellow
    exit 1
}

# セーブデータのパス
$saveDataPath = Join-Path $env:USERPROFILE "AppData\LocalLow\Nolla_Games_Noita\save00"
$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$backupDir = Join-Path $scriptDir "xml"

# バックアップディレクトリの作成（存在しない場合）
if (-not (Test-Path $backupDir)) {
    New-Item -ItemType Directory -Path $backupDir -Force | Out-Null
}

# セーブデータディレクトリの存在確認
if (-not (Test-Path $saveDataPath)) {
    Write-Host "エラー: セーブデータディレクトリが見つかりません: $saveDataPath" -ForegroundColor Red
    exit 1
}

# バックアップ対象ファイル
$playerXml = Join-Path $saveDataPath "player.xml"
$worldStateXml = Join-Path $saveDataPath "world_state.xml"

# ファイルの存在確認
if (-not (Test-Path $playerXml)) {
    Write-Host "エラー: player.xmlが見つかりません: $playerXml" -ForegroundColor Red
    exit 1
}

if (-not (Test-Path $worldStateXml)) {
    Write-Host "エラー: world_state.xmlが見つかりません: $worldStateXml" -ForegroundColor Red
    exit 1
}

Write-Host "バックアップを開始します..." -ForegroundColor Green

# ローテーションバックアップ関数（5世代分）
function Backup-WithRotation {
    param(
        [string]$FileName,
        [string]$SourcePath,
        [string]$BackupDir,
        [int]$Generations = 5
    )
    
    # 既存のバックアップを1つずつシフト
    for ($i = $Generations - 2; $i -ge 0; $i--) {
        $oldBackup = Join-Path $BackupDir "$FileName.$i"
        $newBackup = Join-Path $BackupDir "$FileName.$($i + 1)"
        
        if (Test-Path $oldBackup) {
            Move-Item -Path $oldBackup -Destination $newBackup -Force
        }
    }
    
    # 最新のバックアップを.1にコピー（既存のバックアップがある場合）
    $currentBackup = Join-Path $BackupDir $FileName
    if (Test-Path $currentBackup) {
        Copy-Item -Path $currentBackup -Destination (Join-Path $BackupDir "$FileName.1") -Force
    }
    
    # 現在のファイルをバックアップ
    Copy-Item -Path $SourcePath -Destination $currentBackup -Force
    Write-Host "$FileNameをバックアップしました。" -ForegroundColor Green
}

# player.xmlのローテーションバックアップ
Backup-WithRotation -FileName "player.xml" -SourcePath $playerXml -BackupDir $backupDir

# world_state.xmlのローテーションバックアップ
Backup-WithRotation -FileName "world_state.xml" -SourcePath $worldStateXml -BackupDir $backupDir

Write-Host "バックアップが完了しました。" -ForegroundColor Green
Write-Host "バックアップ先: $backupDir" -ForegroundColor Cyan

