# asset_migrate_stage1.ps1
# 阶段1：美术资源整理——按目标结构 git mv 被引用资源
# 映射规则（用户已认可的目标结构草案）：
#   photos/terrain/*.png            -> assets/terrain/
#   photos/city/tile_city_*_capital -> assets/tiles/
#   photos/event/event_*.png        -> assets/events/
#   photos/unit/unit_*.png          -> assets/units/portraits/
#   photos/portrait/portrait_monarch_*_hires.png -> assets/units/portraits_hires/
#   photos/logo/logo_shanhece.png   -> assets/ui/logo/
# 用法：pwsh tools/asset_migrate_stage1.ps1 [-WhatIf]

param([switch]$WhatIf)

$ErrorActionPreference = "Stop"
$root = (Resolve-Path ".").Path
$dry = [bool]$WhatIf
if ($dry) { Write-Host "=== DRY-RUN（仅预览，不执行） ===" }

# 从基线引用清单提取被引用的具体 photos 文件（排除动态模板 %s）
$refFile = Join-Path $root "docs\程序进度\asset-ref-inventory.txt"
$refs = Get-Content $refFile | ForEach-Object { ($_ -split "`t")[0] } |
    Where-Object { $_ -like "photos/*" -and $_ -notmatch "%" } |
    Sort-Object -Unique

# 映射：源目录 -> 目标目录
$rules = @(
    @{ From = "photos/terrain/"; To = "assets/terrain/" },
    @{ From = "photos/city/";    To = "assets/tiles/" },
    @{ From = "photos/event/";   To = "assets/events/" },
    @{ From = "photos/unit/";    To = "assets/units/portraits/" },
    @{ From = "photos/logo/";    To = "assets/ui/logo/" }
)
# photos/portrait：monarch 立绘为动态模板（faction_select.gd %s），7 国全部迁移
$portraitMonarchs = Get-ChildItem (Join-Path $root "photos\portrait") -Filter "portrait_monarch_*_hires.png" -File |
    ForEach-Object { "photos/portrait/" + $_.Name }

$moves = New-Object System.Collections.Generic.List[object]
$allSrc = @($refs) + @($portraitMonarchs) | Sort-Object -Unique
foreach ($r in $allSrc) {
    $src = Join-Path $root ($r -replace "/", "\")
    if (-not (Test-Path $src)) { continue }
    $destDir = $null
    foreach ($rule in $rules) {
        if ($r.StartsWith($rule.From)) { $destDir = $rule.To; break }
    }
    if ($null -eq $destDir) {
        if ($r -like "photos/portrait/portrait_monarch_*") { $destDir = "assets/units/portraits_hires/" }
    }
    if ($null -eq $destDir) { Write-Host "[跳过-无规则] $r"; continue }
    $destPath = $destDir + (Split-Path $r -Leaf)
    $moves.Add(@{ Src = $r; Dst = $destPath; SrcAbs = $src })
}

# 预览
Write-Host "=== 将移动 $($moves.Count) 个被引用文件 ==="
foreach ($m in $moves) { Write-Host ("  {0}  ->  {1}" -f $m.Src, $m.Dst) }

if ($dry) { return }

# 创建目标目录
$targetDirs = $moves | ForEach-Object { Split-Path (Join-Path $root ($_.Dst -replace "/", "\")) -Parent } | Sort-Object -Unique
foreach ($d in $targetDirs) { New-Item -ItemType Directory -Force -Path $d | Out-Null }

# 执行 git mv（连同 .import 一起移动）
$fail = 0
foreach ($m in $moves) {
    $srcAbs = $m.SrcAbs
    $dstAbs = Join-Path $root ($m.Dst -replace "/", "\")
    $importSrc = $srcAbs + ".import"
    $importDst = $dstAbs + ".import"
    $srcRel = $m.Src -replace "/", "\"
    $dstRel = $m.Dst -replace "/", "\"
    # 移动本体
    & git mv $srcRel $dstRel 2>&1 | Out-Null
    if ($LASTEXITCODE -ne 0) { Write-Host "[FAIL] git mv $srcRel -> $dstRel"; $fail++ }
    # 移动 .import（若存在）
    if (Test-Path $importSrc) {
        & git mv ($srcRel + ".import") ($dstRel + ".import") 2>&1 | Out-Null
        if ($LASTEXITCODE -ne 0) { Write-Host "[WARN] git mv .import $srcRel"; $fail++ }
    }
}
Write-Host "=== 完成，失败数: $fail ==="
