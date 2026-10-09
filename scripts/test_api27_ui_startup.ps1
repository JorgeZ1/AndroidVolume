param([string]$Serial = 'emulator-5582', [int]$Cycles = 30, [int]$ExpectedApi = 27)
$ErrorActionPreference = 'Stop'
$adb = 'C:\Users\Jorge\AppData\Local\Android\Sdk\platform-tools\adb.exe'
$package = 'com.fixbyte.floatingvolume.debug'
if ($Serial -notlike 'emulator-*') { throw 'This test only supports a dedicated emulator.' }
if ((& $adb -s $Serial shell getprop ro.build.version.sdk).Trim() -ne "$ExpectedApi") { throw "Expected API $ExpectedApi." }
$artifact = Join-Path $PSScriptRoot "..\docs\test-artifacts\api$ExpectedApi"
New-Item -ItemType Directory -Force $artifact | Out-Null
& $adb -s $Serial root | Out-Null
& $adb -s $Serial shell appops set $package SYSTEM_ALERT_WINDOW allow | Out-Null
& $adb -s $Serial shell dumpsys deviceidle whitelist "+$package" | Out-Null
& $adb -s $Serial shell am force-stop $package
& $adb -s $Serial shell am start -W -n "$package/com.fixbyte.floatingvolume.MainActivity"
Start-Sleep -Seconds 3
function Get-MainSwitch {
    # A cold Flutter engine on low-end/API29 emulators can take longer than the
    # usual 5-second accessibility settle window. Keep requesting fresh trees;
    # never accept a stale XML dump as a cycle result.
    for ($attempt = 0; $attempt -lt 20; $attempt++) {
        & $adb -s $Serial shell rm -f /sdcard/floating-qa.xml | Out-Null
        $dump = (& $adb -s $Serial shell uiautomator dump /sdcard/floating-qa.xml 2>&1) -join "`n"
        if ($dump -match 'UI hierchary dumped') {
            [xml]$tree = (& $adb -s $Serial shell cat /sdcard/floating-qa.xml) -join "`n"
            $node = $tree.SelectSingleNode("//node[@package='$package' and @class='android.widget.Switch']")
            if ($node) { return $node }
        }
        Start-Sleep -Seconds 1
    }
    throw 'Fresh Home accessibility tree has no main switch; no taps will be attempted.'
}
$switch = Get-MainSwitch
$coords = [regex]::Matches($switch.bounds, '\d+') | ForEach-Object { [int]$_.Value }
$x = [int](($coords[0] + $coords[2]) / 2)
$y = [int](($coords[1] + $coords[3]) / 2)
function Wait-Switch([string]$Expected) {
    $deadline = [DateTime]::UtcNow.AddSeconds(15)
    do {
        $current = Get-MainSwitch
        if ($current.checked -eq $Expected -and $current.enabled -eq 'true') { return }
    } while ([DateTime]::UtcNow -lt $deadline)
    throw "Main switch did not settle at $Expected within 15 seconds."
}
function Get-ControlsWindowCount {
    $dump = (& $adb -s $Serial shell dumpsys window windows) -join "`n"
    $blocks = [regex]::Split($dump, '(?m)^\s+Window #')
    return @($blocks | Where-Object {
        $_ -match 'FloatingVolume controls\}' -and
        $_ -match "package=$([regex]::Escape($package)) appop=" -and
        $_ -match 'mHasSurface=true'
    }).Count
}
function Wait-ControlsWindowCount([int]$Expected) {
    $deadline = [DateTime]::UtcNow.AddSeconds(8)
    do {
        $count = Get-ControlsWindowCount
        if ($count -eq $Expected) { return }
        Start-Sleep -Milliseconds 250
    } while ([DateTime]::UtcNow -lt $deadline)
    throw "Expected $Expected surfaced controls window(s), found $count."
}
if ($switch.checked -eq 'true') {
    & $adb -s $Serial shell input tap $x $y
    Wait-Switch 'false'
}
& $adb -s $Serial logcat -G 8M
& $adb -s $Serial logcat -c
$baselineAcks = @(& $adb -s $Serial logcat -d -s FloatingService:D | Select-String 'foreground_start_ack').Count
for ($i = 1; $i -le $Cycles; $i++) {
    & $adb -s $Serial shell input tap $x $y
    # The UI deliberately disables taps during startup. Wait for the confirmed
    # On state before requesting Off; a dropped busy-state tap is not a crash.
    Wait-Switch 'true'
    Wait-ControlsWindowCount 1
    & $adb -s $Serial shell input tap $x $y
    Wait-Switch 'false'
    Wait-ControlsWindowCount 0
    if ($i % 5 -eq 0) {
        if ((Get-MainSwitch).checked -ne 'false') { throw "Switch did not return to Off at cycle $i." }
        $services = (& $adb -s $Serial shell dumpsys activity services $package) -join "`n"
        # Android 8 retains an unstarred "Last ANR service" snapshot even after
        # that process has exited. Only starred active service entries count.
        if ($services -match '(?m)^\s+\* ServiceRecord.*FloatingVolumeService') { throw "Service remained active at cycle $i." }
        Write-Output "UI cycles verified: $i/$Cycles"
    }
}
Start-Sleep -Seconds 7
$log = & $adb -s $Serial logcat -d -v threadtime
$logText = $log -join "`n"
$logText | Out-File (Join-Path $artifact 'ui-30-cycles.log') -Encoding utf8
# Some legacy emulator images crash the separate uiautomator shell while
# connecting UiAutomation. Do not attribute a system-test-process crash to the
# app; require the fatal block to name our package, or an app ANR/FGS timeout.
$escapedPackage = [regex]::Escape($package)
$appFatal = $logText -match "(?s)FATAL EXCEPTION:.*?Process:\s*$escapedPackage(?:\s|$)"
$appAnr = $logText -match "ANR in\s+$escapedPackage"
$foregroundStartFailure = $logText -match 'did not then call Service\.startForeground|ForegroundServiceDidNotStartInTimeException'
if ($appFatal -or $appAnr -or $foregroundStartFailure) { throw 'Crash/ANR observed in the Floating Volume app process.' }
$acks = @($log | Select-String 'foreground_start_ack').Count
if ($acks - $baselineAcks -lt $Cycles) { throw "Only $($acks-$baselineAcks) new service starts acknowledged for $Cycles UI cycles." }
Write-Output "PASS: $Cycles UI start/stop cycles, $acks acknowledged starts, final switch Off and no active service. Host tap timing is not an exact device callback deadline."
