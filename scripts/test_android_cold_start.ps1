param([string]$Serial, [int]$ExpectedApi, [int]$Cycles = 10)
$ErrorActionPreference = 'Stop'
$adb = 'C:\Users\Jorge\AppData\Local\Android\Sdk\platform-tools\adb.exe'
$app = 'com.fixbyte.floatingvolume.debug'
if ($Serial -notlike 'emulator-*') { throw 'Dedicated emulator required.' }
if ((& $adb -s $Serial shell getprop ro.build.version.sdk).Trim() -ne "$ExpectedApi") { throw 'API mismatch.' }
& $adb -s $Serial root | Out-Null
& $adb -s $Serial shell appops set $app SYSTEM_ALERT_WINDOW allow | Out-Null
& $adb -s $Serial shell dumpsys deviceidle whitelist "+$app" | Out-Null
& $adb -s $Serial logcat -G 8M
& $adb -s $Serial logcat -c
$baselineAcks = @(& $adb -s $Serial logcat -d -s FloatingService:D | Select-String 'foreground_start_ack').Count
for ($i=1; $i -le $Cycles; $i++) {
    & $adb -s $Serial shell am force-stop $app
    & $adb -s $Serial shell am start -W -n "$app/com.fixbyte.floatingvolume.MainActivity" | Out-Null
    # Let Flutter's first frame and accessibility root attach before asking
    # UiAutomation. Android 8 can otherwise return a null/stale root.
    Start-Sleep -Seconds 2
    $deadline = [DateTime]::UtcNow.AddSeconds(60)
    $ready = $false
    do {
        & $adb -s $Serial shell rm -f /sdcard/floating-cold.xml | Out-Null
        $dump = (& $adb -s $Serial shell uiautomator dump /sdcard/floating-cold.xml 2>&1) -join "`n"
        if ($dump -match 'UI hierchary dumped') {
            [xml]$tree = (& $adb -s $Serial shell cat /sdcard/floating-cold.xml) -join "`n"
            $switch = $tree.SelectSingleNode("//node[@package='$app' and @class='android.widget.Switch']")
            $ready = $null -ne $switch
        }
        if (!$ready) { Start-Sleep -Seconds 2 }
    } while (!$ready -and [DateTime]::UtcNow -lt $deadline)
    if (!$ready) { throw "No Home switch after cold start $i. Inspect logcat and exit-info." }
    if ($switch.checked -ne 'false') { throw 'Cold test requires the service to be disabled first.' }
    $coords = [regex]::Matches($switch.bounds, '\d+') | ForEach-Object { [int]$_.Value }
    $x = [int](($coords[0]+$coords[2])/2); $y = [int](($coords[1]+$coords[3])/2)
    & $adb -s $Serial shell input tap $x $y
    Start-Sleep -Seconds 2
    $services = (& $adb -s $Serial shell dumpsys activity services $app) -join "`n"
    if ($services -notmatch 'isForeground=true') { throw "Service not promoted at cold start $i." }
    & $adb -s $Serial shell input tap $x $y
    Start-Sleep -Seconds 2
    $services = (& $adb -s $Serial shell dumpsys activity services $app) -join "`n"
    if ($services -match '(?m)^\s+\* ServiceRecord.*FloatingVolumeService') { throw "Service still active after cold cycle $i." }
    Write-Output "Cold cycle $i/$Cycles passed on API $ExpectedApi"
}
$log = (& $adb -s $Serial logcat -d -v threadtime) -join "`n"
if ($log -match 'FATAL EXCEPTION|ANR in com.fixbyte.floatingvolume.debug|did not then call Service.startForeground') { throw 'Crash or ANR in cold-start test.' }
if ([regex]::Matches($log, 'foreground_start_ack').Count - $baselineAcks -lt $Cycles) { throw 'Insufficient new acknowledged cold starts.' }
Write-Output "PASS: $Cycles cold launch/activate/stop cycles on API $ExpectedApi"
