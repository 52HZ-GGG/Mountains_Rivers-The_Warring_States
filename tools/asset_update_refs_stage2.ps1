# asset_update_refs_stage2.ps1
# 阶段2：美术资源整理——批量替换代码/场景/tools 中的 res:// 路径
# 映射规则（与阶段1的 git mv 一一对应）：
#   res://photos/terrain/  -> res://assets/terrain/
#   res://photos/city/     -> res://assets/tiles/
#   res://photos/event/    -> res://assets/events/
#   res://photos/unit/     -> res://assets/units/portraits/
#   res://photos/portrait/ -> res://assets/units/portraits_hires/
#   res://photos/logo/     -> res://assets/ui/logo/
#   res://assets/sprites/units/effects/ -> res://assets/units/effects/
#   res://assets/sprites/units/         -> res://assets/units/animations/
# 注意替换顺序：先替换 effects 再替换通用前缀（避免 assets/sprites/units/effects 被误替换成 animations/effects）
# 用法：pwsh tools/asset_update_refs_stage2.ps1 [-WhatIf]

param([switch]$WhatIf)

$ErrorActionPreference = "Stop"
$root = (Resolve-Path ".").Path
$dry = [bool]$WhatIf
if ($dry) { Write-Host "=== DRY-RUN（仅预览，不写入） ===" }

# 替换映射（有序）
$map = @(
    @{ From = "res://photos/terrain/";  To = "res://assets/terrain/" },
    @{ From = "res://photos/city/";     To = "res://assets/tiles/" },
    @{ From = "res://photos/event/";    To = "res://assets/events/" },
    @{ From = "res://photos/unit/";     To = "res://assets/units/portraits/" },
    @{ From = "res://photos/portrait/"; To = "res://assets/units/portraits_hires/" },
    @{ From = "res://photos/logo/";     To = "res://assets/ui/logo/" },
    @{ From = "res://assets/sprites/units/effects/"; To = "res://assets/units/effects/" },
    @{ From = "res://assets/sprites/units/";         To = "res://assets/units/animations/" }
)

# 扫描文本文件（代码/场景/主题/shader/工程配置）
$scanFiles = New-Object System.Collections.Generic.List[string]
foreach ($ext in @("*.gd", "*.tscn", "*.tres", "*.gdshader")) {
    Get-ChildItem -Path $root -Recurse -Filter $ext -File -ErrorAction SilentlyContinue |
        Where-Object { $_.FullName -notmatch "\\\.godot\\|\\\.git\\|\\addons\\gut\\|\\tools\\asset_" } |
        ForEach-Object { $scanFiles.Add($_.FullName) }
}
if (Test-Path (Join-Path $root "project.godot")) { $scanFiles.Add((Join-Path $root "project.godot")) }

$changedFiles = @()
$totalReplace = 0
foreach ($f in $scanFiles | Sort-Object -Unique) {
    $content = Get-Content -Path $f -Raw -Encoding UTF8
    $orig = $content
    $count = 0
    foreach ($rule in $map) {
        $n = ([regex]::Matches($content, [regex]::Escape($rule.From))).Count
        if ($n -gt 0) {
            $content = $content.Replace($rule.From, $rule.To)
            $count += $n
            if (-not $dry) {
                Write-Host ("  [{0}] {1}  x{2}" -f $rule.From, $f.Substring($root.Length).TrimStart("\"), $n)
            }
        }
    }
    if ($count -gt 0) {
        $changedFiles += $f
        $totalReplace += $count
        if (-not $dry) {
            Set-Content -Path $f -Value $content -Encoding UTF8 -NoNewline
        }
    }
}

Write-Host "=== 修改文件数: $($changedFiles.Count)，总替换数: $totalReplace ==="
if ($dry) { $changedFiles | ForEach-Object { Write-Host ("  将修改: " + $_.Substring($root.Length).TrimStart("\")) } }
