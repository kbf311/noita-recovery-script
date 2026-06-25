# Noita Recovery Script - Restore Module
# Noitaのセーブデータを復元・修正するスクリプト

# エラー時に停止
$ErrorActionPreference = "Stop"

# Noitaプロセスのチェック
$noitaProcess = Get-Process -Name "noita" -ErrorAction SilentlyContinue
if ($noitaProcess) {
    Write-Host "警告: Noitaが起動中です。復元を中断します。" -ForegroundColor Yellow
    Write-Host "Noitaを終了してから再度実行してください。" -ForegroundColor Yellow
    exit 1
}

# セーブデータのパス
$saveDataPath = Join-Path $env:USERPROFILE "AppData\LocalLow\Nolla_Games_Noita\save00"
$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$backupDir = Join-Path $scriptDir "xml"

# 復元先ディレクトリの存在確認
if (-not (Test-Path $saveDataPath)) {
    Write-Host "エラー: 復元先ディレクトリが存在しません: $saveDataPath" -ForegroundColor Red
    exit 1
}

# バックアップファイルのパス
$backupPlayerXml = Join-Path $backupDir "player.xml"
$backupWorldStateXml = Join-Path $backupDir "world_state.xml"

# バックアップファイルの存在確認
if (-not (Test-Path $backupPlayerXml)) {
    Write-Host "エラー: バックアップファイルが見つかりません: $backupPlayerXml" -ForegroundColor Red
    exit 1
}

if (-not (Test-Path $backupWorldStateXml)) {
    Write-Host "エラー: バックアップファイルが見つかりません: $backupWorldStateXml" -ForegroundColor Red
    exit 1
}

Write-Host "復元を開始します..." -ForegroundColor Green

# player.xmlの復元と修正
$targetPlayerXml = Join-Path $saveDataPath "player.xml"

# バックアップからplayer.xmlを読み込み
$playerDoc = New-Object System.Xml.XmlDocument
$playerDoc.PreserveWhitespace = $true
$playerDoc.Load($backupPlayerXml)

# 座標とステータスの修正
# Entity要素を取得（name属性でplayerを識別、または単にEntity要素を取得）
$playerNode = $playerDoc.SelectSingleNode("//Entity[@name='DEBUG_NAME:player']")
if (-not $playerNode) {
    # フォールバック: Entity要素を直接取得
    $playerNode = $playerDoc.SelectSingleNode("//Entity")
}

if ($playerNode) {
    # 座標の設定
    $transformNode = $playerNode.SelectSingleNode("./_Transform")
    if (-not $transformNode) {
        # フォールバック: 直接検索
        $transformNode = $playerDoc.SelectSingleNode("//_Transform")
    }
    
    if ($transformNode) {
        $transformNode.SetAttribute("position.x", "227")
        $transformNode.SetAttribute("position.y", "-79.0028")
        Write-Host "座標を更新しました: position.x=227, position.y=-79.0028" -ForegroundColor Green
    } else {
        Write-Host "警告: _Transform要素が見つかりませんでした。" -ForegroundColor Yellow
    }
    
    # ステータスの設定（DamageModelComponent要素の属性として設定）
    $damageModelComponent = $playerNode.SelectSingleNode("./DamageModelComponent")
    if (-not $damageModelComponent) {
        # フォールバック: 直接検索
        $damageModelComponent = $playerDoc.SelectSingleNode("//DamageModelComponent")
    }
    
    if ($damageModelComponent) {
        $damageModelComponent.SetAttribute("hp", "4")
        $damageModelComponent.SetAttribute("max_hp", "4")
        $damageModelComponent.SetAttribute("max_hp_cap", "0")
        $damageModelComponent.SetAttribute("max_hp_old", "0")
        Write-Host "ステータスを更新しました: hp=4, max_hp=4, max_hp_cap=0, max_hp_old=0" -ForegroundColor Green
    } else {
        Write-Host "警告: DamageModelComponent要素が見つかりませんでした。" -ForegroundColor Yellow
    }
    
    # AbilityComponentのmNextFrameUsableとmReloadNextFrameUsableをゼロに設定
    $abilityComponents = $playerDoc.SelectNodes("//AbilityComponent[@mNextFrameUsable or @mReloadNextFrameUsable]")
    if ($abilityComponents -and $abilityComponents.Count -gt 0) {
        $updatedCount = 0
        foreach ($abilityComponent in $abilityComponents) {
            if ($abilityComponent.HasAttribute("mNextFrameUsable")) {
                $abilityComponent.SetAttribute("mNextFrameUsable", "0")
                $updatedCount++
            }
            if ($abilityComponent.HasAttribute("mReloadNextFrameUsable")) {
                $abilityComponent.SetAttribute("mReloadNextFrameUsable", "0")
                $updatedCount++
            }
        }
        Write-Host "AbilityComponentのフレーム値をリセットしました。($updatedCount個の属性を更新)" -ForegroundColor Green
    } else {
        Write-Host "警告: AbilityComponent要素が見つかりませんでした。" -ForegroundColor Yellow
    }
} else {
    Write-Host "エラー: Entity要素が見つかりませんでした。" -ForegroundColor Red
}

# 修正したplayer.xmlを保存
$playerDoc.Save($targetPlayerXml)
Write-Host "player.xmlを復元・修正しました。" -ForegroundColor Green

# world_state.xmlのPerk情報の移植
$targetWorldStateXml = Join-Path $saveDataPath "world_state.xml"

# 現在のworld_state.xmlが存在するか確認
if (-not (Test-Path $targetWorldStateXml)) {
    Write-Host "警告: 現在のworld_state.xmlが見つかりません。バックアップから完全に復元します。" -ForegroundColor Yellow
    Copy-Item -Path $backupWorldStateXml -Destination $targetWorldStateXml -Force
    Write-Host "world_state.xmlを復元しました。" -ForegroundColor Green
    Write-Host "復元が完了しました。" -ForegroundColor Green
    exit 0
}

# バックアップと現在のworld_state.xmlを読み込み
$backupWorldStateDoc = New-Object System.Xml.XmlDocument
$backupWorldStateDoc.PreserveWhitespace = $true
$backupWorldStateDoc.Load($backupWorldStateXml)

$currentWorldStateDoc = New-Object System.Xml.XmlDocument
$currentWorldStateDoc.PreserveWhitespace = $true
$currentWorldStateDoc.Load($targetWorldStateXml)

# 移植するPerkのリスト（WorldStateComponent要素の属性として存在）
$perksToTransfer = @(
    "perk_gold_is_forever",
    "perk_hp_drop_chance",
    "perk_infinite_spells",
    "perk_rats_player_friendly",
    "perk_trick_kills_blood_money"
)

# WorldStateComponent要素を取得
$backupWorldStateComponent = $backupWorldStateDoc.SelectSingleNode("//WorldStateComponent")
$currentWorldStateComponent = $currentWorldStateDoc.SelectSingleNode("//WorldStateComponent")

if ($backupWorldStateComponent -and $currentWorldStateComponent) {
    # Perk情報の移植（WorldStateComponent要素の属性として設定）
    $perksTransferred = 0
    foreach ($perkName in $perksToTransfer) {
        # バックアップからPerk属性の値を取得
        if ($backupWorldStateComponent.HasAttribute($perkName)) {
            $perkValue = $backupWorldStateComponent.GetAttribute($perkName)
            # 現在のworld_state.xmlのWorldStateComponentに属性を設定
            $currentWorldStateComponent.SetAttribute($perkName, $perkValue)
            $perksTransferred++
            Write-Host "Perk属性を更新しました: $perkName=$perkValue" -ForegroundColor Green
        } else {
            Write-Host "警告: バックアップにPerk属性が見つかりませんでした: $perkName" -ForegroundColor Yellow
        }
    }
    Write-Host "world_state.xmlのPerk情報を移植しました。($perksTransferred個のPerk属性)" -ForegroundColor Green
} else {
    Write-Host "警告: WorldStateComponent要素が見つかりませんでした。" -ForegroundColor Yellow
    $perksTransferred = 0
}

# 修正したworld_state.xmlを保存
$currentWorldStateDoc.Save($targetWorldStateXml)

Write-Host "復元が完了しました。" -ForegroundColor Green

