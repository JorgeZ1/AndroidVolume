param([string]$Serial = 'emulator-5582', [int]$Cycles = 20, [switch]$WaitForPromotion, [int]$ExpectedApi = 27)
$ErrorActionPreference = 'Stop'
$adb = 'C:\Users\Jorge\AppData\Local\Android\Sdk\platform-tools\adb.exe'
$package = 'com.fixbyte.floatingvolume.debug'
$component = "$package/com.fixbyte.floatingvolume.FloatingVolumeService"
$startCommand = if ($ExpectedApi -lt 26) { 'startservice' } else { 'start-foreground-service' }
if ($Serial -notlike 'emulator-*') { throw 'This test only supports an emulator.' }
$api = (& $adb -s $Serial shell getprop ro.build.version.sdk).Trim()
if ($api -ne "$ExpectedApi") { throw "Expected API $ExpectedApi, found $api" }
& $adb -s $Serial root
& $adb -s $Serial wait-for-device
& $adb -s $Serial shell appops set $package SYSTEM_ALERT_WINDOW allow
& $adb -s $Serial shell dumpsys deviceidle whitelist "+$package"
& $adb -s $Serial shell am start -W -n "$package/com.fixbyte.floatingvolume.MainActivity"
Start-Sleep -Seconds 3
& $adb -s $Serial logcat -G 8M
& $adb -s $Serial logcat -c
$baselineAcks = @(& $adb -s $Serial logcat -d -s FloatingService:D | Select-String 'foreground_start_ack').Count
for ($i = 1; $i -le $Cycles; $i++) {
    & $adb -s $Serial shell am $startCommand -n $component
    if ($LASTEXITCODE -ne 0) { throw "Start failed on cycle $i" }
    if ($WaitForPromotion) {
        $deadline = [DateTime]::UtcNow.AddSeconds(8)
        do {
            $acks = @(& $adb -s $Serial logcat -d -s FloatingService:D | Select-String 'foreground_start_ack').Count
            if ($acks -ge ($baselineAcks + $i)) { break }
            Start-Sleep -Milliseconds 50
        } while ([DateTime]::UtcNow -lt $deadline)
        if ($acks -lt ($baselineAcks + $i)) { throw "No foreground acknowledgement on cycle $i" }
    }
    Start-Sleep -Milliseconds 100
    & $adb -s $Serial shell am stopservice -n $component
    Start-Sleep -Milliseconds 150
}
Start-Sleep -Seconds 7
$log = & $adb -s $Serial logcat -d -v threadtime
$failure = $log | Select-String 'FATAL EXCEPTION|did not then call Service.startForeground|ForegroundServiceDidNotStartInTimeException'
$failure
if ($failure) { throw 'Crash observed: inspect the emulator logcat.' }
Write-Output "Completed $Cycles direct service start/stop cycles without the timeout in this run. WaitForPromotion=$WaitForPromotion. This is not a Samsung/OEM reproduction and does not exercise the Flutter switch event flow."
