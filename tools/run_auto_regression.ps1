# 全自动回归：GUT 全量 + 完整流程冒烟
# 用法：在项目根目录执行
#   powershell -File tools/run_auto_regression.ps1
# 可选：
#   -GodotPath "E:\path\to\Godot_console.exe"
#   -SkipGut / -SkipSmoke

param(
  [string]$GodotPath = "",
  [switch]$SkipGut,
  [switch]$SkipSmoke
)

$ErrorActionPreference = "Continue"
$root = Split-Path -Parent (Split-Path -Parent $MyInvocation.MyCommand.Path)
if (-not $GodotPath) {
  $candidates = @(
    "E:\programs\Godot_v4.3-stable_mono_win64\Godot_v4.3-stable_mono_win64_console.exe",
    "E:\programs\Godot_v4.3-stable_mono_win64\Godot_v4.3-stable_mono_win64.exe",
    (Get-Command godot -ErrorAction SilentlyContinue).Source
  )
  foreach ($c in $candidates) {
    if ($c -and (Test-Path $c)) { $GodotPath = $c; break }
  }
}
if (-not $GodotPath -or -not (Test-Path $GodotPath)) {
  Write-Host "[REG] 未找到 Godot，请用 -GodotPath 指定" -ForegroundColor Red
  exit 2
}

$logDir = Join-Path $root ".auto_regression"
New-Item -ItemType Directory -Force -Path $logDir | Out-Null
$summary = Join-Path $logDir "summary.txt"
Remove-Item $summary -ErrorAction SilentlyContinue

function Write-Sum([string]$line) {
  Add-Content -Path $summary -Value $line
  Write-Host $line
}

Write-Sum "=== 山河策 全自动回归 $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') ==="
Write-Sum "Godot: $GodotPath"
Write-Sum "Project: $root"

# 1) 导入
Write-Sum "`n--- [1/3] 资源导入 ---"
$importLog = Join-Path $logDir "import.log"
$p = Start-Process -FilePath $GodotPath -ArgumentList @("--headless","--path",$root,"--import") -RedirectStandardOutput $importLog -RedirectStandardError "$importLog.err" -PassThru -NoNewWindow
$p.WaitForExit(180000) | Out-Null
Write-Sum "import exit=$($p.ExitCode)"

# 2) GUT 全量（按文件前缀并行度 1）
$gutFail = 0
if (-not $SkipGut) {
  Write-Sum "`n--- [2/3] GUT 单元测试 ---"
  $tests = Get-ChildItem (Join-Path $root "tests\unit") -Filter "test_*.gd" | Sort-Object Name
  foreach ($t in $tests) {
    $tag = $t.BaseName
    $log = Join-Path $logDir "$tag.log"
    Remove-Item $log, "$log.err" -ErrorAction SilentlyContinue
    $args = @(
      "--headless","--path",$root,
      "-s","addons/gut/gut_cmdln.gd",
      "-gdir=res://tests/unit",
      "-gprefix=$($t.Name)",
      "-ginclude_subdirs=0",
      "-gexit","-glog=1"
    )
    $timeoutMs = 180000
    if ($tag -in @("test_game_manager","test_main_turn_ui","test_city_manager")) {
      $timeoutMs = 300000
    }
    $proc = Start-Process -FilePath $GodotPath -ArgumentList $args -RedirectStandardOutput $log -RedirectStandardError "$log.err" -PassThru -NoNewWindow
    $done = $proc.WaitForExit($timeoutMs)
    if (-not $done) {
      $proc.Kill()
      Write-Sum "[GUT][TIMEOUT] $tag"
      $gutFail++
      continue
    }
    $out = Get-Content $log -ErrorAction SilentlyContinue
    $scriptErr = 0
    if (Test-Path "$log.err") {
      $scriptErr = @(Get-Content "$log.err" | Select-String "SCRIPT ERROR").Count
    }
    $failedLine = $out | Select-String "failing tests" | Select-Object -Last 1
    $allPass = $out | Select-String "All tests passed" | Select-Object -Last 1
    if ($allPass -and $scriptErr -eq 0) {
      Write-Sum "[GUT][OK] $tag"
    } else {
      Write-Sum "[GUT][FAIL] $tag script_err=$scriptErr $failedLine"
      $gutFail++
    }
  }
} else {
  Write-Sum "`n--- [2/3] GUT 已跳过 ---"
}

# 3) 完整流程冒烟
$smokeFail = 0
if (-not $SkipSmoke) {
  Write-Sum "`n--- [3/3] 完整流程冒烟 ---"
  $smokeLog = Join-Path $logDir "smoke.log"
  Remove-Item $smokeLog, "$smokeLog.err" -ErrorAction SilentlyContinue
  $sargs = @("--headless","--path",$root,"-s","res://tests/smoke/full_flow_smoke.gd")
  $sp = Start-Process -FilePath $GodotPath -ArgumentList $sargs -RedirectStandardOutput $smokeLog -RedirectStandardError "$smokeLog.err" -PassThru -NoNewWindow
  $sdone = $sp.WaitForExit(180000)
  if (-not $sdone) {
    $sp.Kill()
    Write-Sum "[SMOKE][TIMEOUT]"
    $smokeFail = 1
  } else {
    $sout = Get-Content $smokeLog -ErrorAction SilentlyContinue
    $serr = 0
    if (Test-Path "$smokeLog.err") {
      $serr = @(Get-Content "$smokeLog.err" | Select-String "SCRIPT ERROR").Count
    }
    $sout | Select-String "\[SMOKE\]" | ForEach-Object { Write-Sum $_.Line }
    if ($sp.ExitCode -eq 0 -and $serr -eq 0) {
      Write-Sum "[SMOKE][OK] exit=0 script_err=0"
    } else {
      Write-Sum "[SMOKE][FAIL] exit=$($sp.ExitCode) script_err=$serr"
      $smokeFail = 1
    }
  }
} else {
  Write-Sum "`n--- [3/3] 冒烟已跳过 ---"
}

Write-Sum "`n=== 结果：GUT失败=$gutFail Smoke失败=$smokeFail ==="
if ($gutFail -eq 0 -and $smokeFail -eq 0) {
  Write-Sum "ALL GREEN"
  exit 0
}
Write-Sum "HAS FAILURES — 详见 $logDir"
exit 1
