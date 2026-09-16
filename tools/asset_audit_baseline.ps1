# asset_audit_baseline.ps1
# 阶段0：美术资源整理——基线冻结审计
# 生成三份清单到 docs/程序进度/：
#   1. asset-ref-inventory.txt     所有 res:// 资源引用（含引用方与行号）
#   2. asset-file-inventory.txt    git 跟踪的全部文件清单
#   3. asset-cross-report.txt      引用 vs 文件 交叉分析（被引用/未引用/缺失）
# 用法：pwsh tools/asset_audit_baseline.ps1

$ErrorActionPreference = "Stop"
$root = (Resolve-Path ".").Path
$outDir = Join-Path $root "docs\程序进度"
New-Item -ItemType Directory -Force -Path $outDir | Out-Null

$refOut   = Join-Path $outDir "asset-ref-inventory.txt"
$fileOut  = Join-Path $outDir "asset-file-inventory.txt"
$crossOut = Join-Path $outDir "asset-cross-report.txt"

# ---------- 1. 收集所有 res:// 资源引用 ----------
# 扫描包含资源路径的文本文件（代码/场景/主题/工程配置）
$scanExts = @("*.gd", "*.tscn", "*.tres", "*.gdshader", "project.godot", "*.json")
$scanFiles = New-Object System.Collections.Generic.List[string]
foreach ($ext in $scanExts) {
    if ($ext -eq "*.gd" -or $ext -eq "*.tscn" -or $ext -eq "*.tres" -or $ext -eq "*.gdshader") {
        Get-ChildItem -Path $root -Recurse -Filter $ext -File -ErrorAction SilentlyContinue |
            Where-Object { $_.FullName -notmatch "\\\.godot\\|\\\.git\\|\\addons\\gut\\" } |
            ForEach-Object { $scanFiles.Add($_.FullName) }
    }
}
if (Test-Path (Join-Path $root "project.godot")) { $scanFiles.Add((Join-Path $root "project.godot")) }
Get-ChildItem -Path (Join-Path $root "data") -Filter "*.json" -File -ErrorAction SilentlyContinue |
    ForEach-Object { $scanFiles.Add($_.FullName) }

# res:// 路径提取正则：res:// 后跟 非空白/引号 的资源路径
$refRegex = 'res://([^\s"''`\)\]]+)'
$refs = New-Object System.Collections.Generic.List[string]  # 记录: 路径<TAB>文件<TAB>行号<TAB>原文

foreach ($f in $scanFiles | Sort-Object -Unique) {
    $rel = $f.Substring($root.Length).TrimStart("\").Replace("\", "/")
    $lines = Get-Content -Path $f -Encoding UTF8 -ErrorAction SilentlyContinue
    for ($i = 0; $i -lt $lines.Count; $i++) {
        $line = $lines[$i]
        $ms = [regex]::Matches($line, $refRegex)
        foreach ($m in $ms) {
            $refs.Add(("{0}`t{1}`t{2}`t{3}" -f $m.Groups[1].Value, $rel, ($i + 1), $line.Trim()))
        }
    }
}

$refs | Sort-Object -Unique | Set-Content -Path $refOut -Encoding UTF8
Write-Host ("[OK] 引用清单: {0} 条 -> {1}" -f $refs.Count, $refOut)

# ---------- 2. 文件清单（git 跟踪 + 实际存在） ----------
$tracked = git ls-files 2>$null
$tracked | Set-Content -Path $fileOut -Encoding UTF8
Write-Host ("[OK] 文件清单: {0} 条 -> {1}" -f $tracked.Count, $fileOut)

# ---------- 3. 交叉分析 ----------
$uniqueRefs = $refs | ForEach-Object { ($_ -split "`t")[0] } | Sort-Object -Unique
# 动态模板路径（含 %s 占位符）单独归类
$dynamic = $uniqueRefs | Where-Object { $_ -match "%s|%[0-9]" }
$concrete = $uniqueRefs | Where-Object { $_ -notmatch "%s|%[0-9]" }

$ok = @(); $missing = @()
foreach ($r in $concrete) {
    $p = Join-Path $root ($r -replace "/", "\")
    if (Test-Path $p) { $ok += $r } else { $missing += $r }
}

$allFiles = @()
foreach ($tf in $tracked) { $allFiles += ($tf -replace "/", "\") }
$fileSet = New-Object System.Collections.Generic.HashSet[string]
foreach ($af in $allFiles) { [void]$fileSet.Add($af.ToLower()) }

$unreferenced = @()
foreach ($tf in $allFiles) {
    $t = $tf.ToLower()
    $isAsset = ($t -like "photos\*" -or $t -like "assets\*")
    if (-not $isAsset) { continue }
    $base = $tf.Split("\")[-1]
    $hit = $concrete | Where-Object { ($_ -replace "/", "\").ToLower() -eq $t }
    if ($null -eq $hit -or $hit.Count -eq 0) {
        # 也按文件名匹配（动态引用场景，如 effect_frames 扫描目录）
        $nameHit = $concrete | Where-Object { (Split-Path $_ -Leaf).ToLower() -eq $base.ToLower() }
        if ($null -eq $nameHit -or $nameHit.Count -eq 0) {
            $unreferenced += $tf
        }
    }
}

$sb = New-Object System.Text.StringBuilder
[void]$sb.AppendLine("=== 美术资源整理 基线交叉分析 ===")
[void]$sb.AppendLine("生成时间: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')")
[void]$sb.AppendLine("")
[void]$sb.AppendLine("--- A. 具体路径引用且文件存在 (OK, $($ok.Count)) ---")
$ok | ForEach-Object { [void]$sb.AppendLine($_ ) }
[void]$sb.AppendLine("")
[void]$sb.AppendLine("--- B. 具体路径引用但文件缺失 (MISSING, $($missing.Count)) ---")
$missing | ForEach-Object { [void]$sb.AppendLine($_ ) }
[void]$sb.AppendLine("")
[void]$sb.AppendLine("--- C. 动态模板路径 (含 %s/%d 占位符, $($dynamic.Count)) ---")
$dynamic | ForEach-Object { [void]$sb.AppendLine($_ ) }
[void]$sb.AppendLine("")
[void]$sb.AppendLine("--- D. photos/ 与 assets/ 下未被任何具体引用命中的文件 ($($unreferenced.Count)) ---")
$unreferenced | ForEach-Object { [void]$sb.AppendLine($_ ) }

$sb.ToString() | Set-Content -Path $crossOut -Encoding UTF8
Write-Host ("[OK] 交叉报告: OK={0} MISSING={1} 动态={2} 未引用={3} -> {4}" -f $ok.Count, $missing.Count, $dynamic.Count, $unreferenced.Count, $crossOut)
