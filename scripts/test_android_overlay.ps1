param([string]$Serial, [int]$ExpectedApi, [int]$Rotations=20, [int]$Gestures=30, [int]$RaceTrials=0, [switch]$SkipAudioChecks)
$ErrorActionPreference = 'Stop'
$adb='C:\Users\Jorge\AppData\Local\Android\Sdk\platform-tools\adb.exe'
$app='com.fixbyte.floatingvolume.debug'
if ($Serial -notlike 'emulator-*') { throw 'Dedicated emulator required.' }
if ((& $adb -s $Serial shell getprop ro.build.version.sdk).Trim() -ne "$ExpectedApi") { throw 'API mismatch.' }
$artifact=Join-Path $PSScriptRoot "..\docs\test-artifacts\api$ExpectedApi"
New-Item -ItemType Directory -Force $artifact | Out-Null
function A([string[]]$Command) { & $adb -s $Serial @Command }
function Ui {
    for($attempt=0;$attempt -lt 8;$attempt++) {
        $result=(A @('shell','uiautomator','dump','/sdcard/overlay-qa.xml')) -join "`n"
        if($result -match 'UI hierchary dumped') {
            [xml]$tree=(A @('shell','cat','/sdcard/overlay-qa.xml')) -join "`n"
            if($tree.SelectNodes("//node[@package='$app' and @class='android.widget.Switch']").Count -ge 4){return $tree}
        }
        Start-Sleep -Seconds 1
    }
    throw 'No fresh Home UI dump; stale XML cannot certify switch changes.'
}
function Set-Switch([int]$Index,[bool]$Value) {
    $tree=Ui
    $nodes=$tree.SelectNodes("//node[@package='$app' and @class='android.widget.Switch']")
    if ($nodes.Count -le $Index) { throw "Switch $Index missing on Home." }
    $node=$nodes[$Index]
    if ($node.checked -eq $Value.ToString().ToLowerInvariant()) { return }
    if ($node.enabled -ne 'true') { throw 'Switch is busy; cannot count this as a tap.' }
    $n=[regex]::Matches($node.bounds,'\d+') | ForEach-Object { [int]$_.Value }
    A @('shell','input','tap',"$([int](($n[0]+$n[2])/2))","$([int](($n[1]+$n[3])/2))") | Out-Null
    Start-Sleep -Seconds 1
    $verified=(Ui).SelectNodes("//node[@package='$app' and @class='android.widget.Switch']")[$Index]
    if($verified.checked -ne $Value.ToString().ToLowerInvariant()){throw "Switch $Index did not change to $Value."}
}
function Control-Rect {
    $dump=(A @('shell','dumpsys','window','windows')) -join "`n"
    $blocks=[regex]::Split($dump,'(?m)^\s+Window #')
    $controls=@($blocks | Where-Object { $_ -match 'FloatingVolume controls\}' -and $_ -match "package=$([regex]::Escape($app)) appop=" })
    if ($controls.Count -ne 1) { throw "Expected 1 controls window, got $($controls.Count)." }
    $m=[regex]::Match($controls[0],'(?:mFrame=| frame=)\[(-?\d+),(-?\d+)\]\[(-?\d+),(-?\d+)\]')
    if (!$m.Success) { throw 'Controls frame unavailable.' }
    return @{Left=[int]$m.Groups[1].Value;Top=[int]$m.Groups[2].Value;Right=[int]$m.Groups[3].Value;Bottom=[int]$m.Groups[4].Value}
}
function Tap-Volume([bool]$Up) {
    $r=Control-Rect
    $x=[int](($r.Left+$r.Right)/2)
    $fraction=if($Up){0.25}else{0.75}
    $y=[int]($r.Top+($r.Bottom-$r.Top)*$fraction)
    A @('shell','input','tap',"$x","$y") | Out-Null
}
A @('shell','am','start','-W','-n',"$app/com.fixbyte.floatingvolume.MainActivity") | Out-Null
Start-Sleep -Seconds 2
Set-Switch 3 $false # no automatic retraction while measuring geometry
Set-Switch 1 $false # permit gesture movement
Set-Switch 2 $false # measure our own indicator, not OEM panel
Set-Switch 0 $true
A @('shell','input','keyevent','KEYCODE_HOME') | Out-Null
Start-Sleep -Seconds 2
if(!$SkipAudioChecks) {
    A @('logcat','-c') | Out-Null
    (A @('shell','dumpsys','audio')) | Out-File (Join-Path $artifact 'audio-before.txt') -Encoding utf8
    Tap-Volume $false
    Start-Sleep -Milliseconds 200
    Tap-Volume $true
    & (Join-Path $PSScriptRoot 'verify_indicator.ps1') -Serial $Serial
    (A @('shell','dumpsys','audio')) | Out-File (Join-Path $artifact 'audio-after.txt') -Encoding utf8
    $log=(A @('logcat','-d','-s','FloatingService:D')) -join "`n"
    $requests=[regex]::Matches($log,'Volume request: stream=MEDIA before=(\d+) target=(\d+) actual=(\d+)')
    if ($requests.Count -lt 2) { throw 'Expected two real STREAM_MUSIC requests from the floating buttons on Home.' }
    if (!@($requests | Where-Object { $_.Groups[1].Value -ne $_.Groups[3].Value -and $_.Groups[2].Value -eq $_.Groups[3].Value }).Count) { throw 'No confirmed real media-volume change.' }
    Write-Output "PASS: media volume changes on Home, actual AudioManager values and indicator geometry (API $ExpectedApi)."
}
$oldAutoRotate=(A @('shell','settings','get','system','accelerometer_rotation')) -join ''
$oldRotation=(A @('shell','settings','get','system','user_rotation')) -join ''
try {
    # Pixel Launcher fixes phone Home to portrait. Rotate a resizable Activity,
    # and assert actual display orientation instead of counting settings writes.
    A @('shell','am','start','-W','-n',"$app/com.fixbyte.floatingvolume.MainActivity") | Out-Null
    A @('shell','settings','put','system','accelerometer_rotation','0') | Out-Null
    A @('shell','settings','put','system','user_rotation','0') | Out-Null
    Start-Sleep -Seconds 2
    $portraitBaseline=Control-Rect
    for($i=1;$i -le $Rotations;$i++) {
        A @('shell','settings','put','system','user_rotation',"$($i%2)") | Out-Null
        $deadline=[DateTime]::UtcNow.AddSeconds(10)
        do {
            $inputDump=(A @('shell','dumpsys','input')) -join "`n"
            $orientation=[regex]::Match($inputDump,'SurfaceOrientation:\s*(\d+)')
            if($orientation.Success -and [int]$orientation.Groups[1].Value -eq $i%2){break}
            Start-Sleep -Milliseconds 200
        } while([DateTime]::UtcNow -lt $deadline)
        if(!$orientation.Success -or [int]$orientation.Groups[1].Value -ne $i%2){throw "Display did not actually rotate on cycle $i."}
        Start-Sleep -Milliseconds 500
        $settleDeadline=[DateTime]::UtcNow.AddSeconds(10)
        do {
            $current=Control-Rect
            $settled=if($i%2 -eq 0){
                $current.Left -eq $portraitBaseline.Left -and
                    $current.Right -eq $portraitBaseline.Right -and
                    [Math]::Abs($current.Top-$portraitBaseline.Top) -le 2
            }elseif($portraitBaseline.Left -le 2){
                $current.Left -le 2
            }else{$current.Right -gt $portraitBaseline.Right}
            if($settled){break}
            Start-Sleep -Milliseconds 200
        }while([DateTime]::UtcNow -lt $settleDeadline)
        if(!$settled){throw "Controls did not settle after rotation $i : portrait baseline=$($portraitBaseline.Top), actual=$($current.Top)."}
        Tap-Volume ($i%2 -eq 0)
        # changeVolume posts indicator attachment back to the main looper; on
        # slow legacy API images a same-frame dumpsys can run before the window
        # manager has surfaced it. Wait for the actual overlay, not a fixed delay.
        $indicatorDeadline=[DateTime]::UtcNow.AddSeconds(3)
        do {
            $windowDump=(A @('shell','dumpsys','window','windows')) -join "`n"
            $indicatorVisible=$windowDump -match "(?s)FloatingVolume indicator\}.*?package=$([regex]::Escape($app)) appop="
            if($indicatorVisible){break}
            Start-Sleep -Milliseconds 100
        }while([DateTime]::UtcNow -lt $indicatorDeadline)
        if(!$indicatorVisible){throw "Indicator overlay did not appear after volume tap on rotation $i (API $ExpectedApi)."}
        & (Join-Path $PSScriptRoot 'verify_indicator.ps1') -Serial $Serial
        if($i%5 -eq 0){Write-Output "Rotation checks $i/$Rotations on API $ExpectedApi"}
    }
} finally {
    if($oldAutoRotate -eq 'null'){A @('shell','settings','delete','system','accelerometer_rotation') | Out-Null}
    else{A @('shell','settings','put','system','accelerometer_rotation',"$oldAutoRotate") | Out-Null}
    if($oldRotation -eq 'null'){A @('shell','settings','delete','system','user_rotation') | Out-Null}
    else{A @('shell','settings','put','system','user_rotation',"$oldRotation") | Out-Null}
}
Start-Sleep -Seconds 2
for($i=1;$i -le $Gestures;$i++) {
    $r=Control-Rect
    $x=[int](($r.Left+$r.Right)/2); $y=[int]($r.Top+($r.Bottom-$r.Top)*0.25)
    A @('shell','input','swipe',"$x","$y","$x","$y",'600') | Out-Null
    # Sequential long-press/drag coverage, not a precision 550ms race injection.
    A @('shell','input','swipe',"$x","$y",'360',"$($y+30)",'300') | Out-Null
    Start-Sleep -Milliseconds 500
    $null=Control-Rect
    $overlays=@()
    for($attempt=0;$attempt -lt 6;$attempt++) {
        $dump=(A @('shell','dumpsys','window','windows')) -join "`n"
        $blocks=[regex]::Split($dump,'(?m)^\s+Window #')
        $overlays=@($blocks | Where-Object {
            $_ -match "package=$([regex]::Escape($app)) appop=" -and
            $_ -match '(?:ty=(?:2002|2038)\b|ty=APPLICATION_OVERLAY\b)' -and
            $_ -match 'mHasSurface=true'
        })
        if($overlays.Count -eq 1){break}
        if($overlays.Count -gt 1){throw "Found $($overlays.Count) surfaced app overlays after drag $i."}
        Start-Sleep -Milliseconds 250
    }
    if($overlays.Count -ne 1){throw "Expected controls window to remain after drag $i; none was surfaced after 1.5 seconds."}
    if($i%5 -eq 0){Write-Output "Sequential gesture checks $i/$Gestures on API $ExpectedApi"}
}
$raceResults = [System.Collections.Generic.List[string]]::new()
if($RaceTrials -gt 0) {
    # ADB's `input swipe` always ends its pointer before another command starts,
    # so it cannot reproduce the reported hold-then-drag race in one gesture.
    # The dedicated, rooted emulator exposes its touchscreen as event1; inject
    # one continuous pointer stream and move shortly after the 550 ms menu timer.
    $touchDevices=(A @('shell','getevent','-lp')) -join "`n"
    if($touchDevices -notmatch '(?s)event1.*?name:\s+"qwerty2".*?ABS_MT_POSITION_X') {
        throw 'Precision gesture injection requires the dedicated AVD qwerty2 touchscreen at /dev/input/event1.'
    }
    $inputState=(A @('shell','dumpsys','input')) -join "`n"
    # dumpsys may list the virtual touch device before qwerty2. Parse the
    # calibration from qwerty2 itself; using the first global scale sends
    # coordinates near the upper-left corner on some AVD images (API 28).
    $touchBlockMatch=[regex]::Match($inputState,'(?s)Device\s+\d+: qwerty2(?<touch>.*?)(?=\r?\n\s*Device\s+\d+:|\z)')
    if(!$touchBlockMatch.Success){throw 'qwerty2 calibration block unavailable in dumpsys input.'}
    $touchBlock=$touchBlockMatch.Groups['touch'].Value
    $scaleXMatches=[regex]::Matches($touchBlock,'(?m)^\s*XScale:\s*([0-9.]+)')
    $scaleYMatches=[regex]::Matches($touchBlock,'(?m)^\s*YScale:\s*([0-9.]+)')
    if($scaleXMatches.Count -lt 2 -or $scaleYMatches.Count -lt 2){throw 'Touchscreen coordinate scale unavailable.'}
    # The final scales belong to the Touch Input Mapper; the first pair belongs
    # to qwerty2's pointer mapper and is different on API 28.
    $scaleX=[double]::Parse($scaleXMatches[$scaleXMatches.Count-1].Groups[1].Value,[System.Globalization.CultureInfo]::InvariantCulture)
    $scaleY=[double]::Parse($scaleYMatches[$scaleYMatches.Count-1].Groups[1].Value,[System.Globalization.CultureInfo]::InvariantCulture)
    if($scaleX -le 0 -or $scaleY -le 0){throw 'Invalid touchscreen coordinate scale.'}
    # Schedule injection/UI work can lag the nominal 550 ms coroutine delay,
    # especially on first boot/API 28. Move just after the menu is expected to
    # have attached instead of racing ahead and measuring a canceled long press.
    $delays=@(620,635,650,665,680,700,725)
    $attachedTrials=0
    $raceArtifact=Join-Path $artifact 'quick-menu-race.log'
    $apkPath=Join-Path $PSScriptRoot '..\build\app\outputs\flutter-apk\app-debug.apk'
    $apkHash=(Get-FileHash -LiteralPath $apkPath -Algorithm SHA256).Hash
    $raceResults.Add("API=$ExpectedApi serial=$Serial APK_SHA256=$apkHash")
    for($trial=1;$trial -le $RaceTrials;$trial++) {
        $holdMs=$delays[($trial-1)%$delays.Count]
        $r=Control-Rect
        $x=[int](($r.Left+$r.Right)/2)
        $y=[int]($r.Top+($r.Bottom-$r.Top)*0.28)
        $dx=24; $dy=18
        $rawX=[int][Math]::Round($x/$scaleX)
        $rawY=[int][Math]::Round($y/$scaleY)
        $rawMoveX=[int][Math]::Round(($x+$dx)/$scaleX)
        $rawMoveY=[int][Math]::Round(($y+$dy)/$scaleY)
        $holdSeconds=([double]$holdMs/1000).ToString('0.000',[System.Globalization.CultureInfo]::InvariantCulture)
        A @('logcat','-c') | Out-Null
        $injection=@"
sendevent /dev/input/event1 3 47 0
sendevent /dev/input/event1 3 57 1
sendevent /dev/input/event1 3 53 $rawX
sendevent /dev/input/event1 3 54 $rawY
sendevent /dev/input/event1 3 48 8
sendevent /dev/input/event1 3 58 512
sendevent /dev/input/event1 1 330 1
sendevent /dev/input/event1 0 0 0
sleep $holdSeconds
sendevent /dev/input/event1 3 53 $rawMoveX
sendevent /dev/input/event1 3 54 $rawMoveY
sendevent /dev/input/event1 0 0 0
sleep 0.080
sendevent /dev/input/event1 3 58 0
sendevent /dev/input/event1 3 57 -1
sendevent /dev/input/event1 1 330 0
sendevent /dev/input/event1 0 0 0
"@ -replace "`r?`n",'; '
        # Send a single shell command through adb. Base64 preserves the script
        # and its argument boundaries across Windows PowerShell/adb quoting.
        $encodedInjection=[Convert]::ToBase64String([Text.Encoding]::UTF8.GetBytes($injection))
        $remoteInjection="echo $encodedInjection | base64 -d | sh"
        $injectOutput=(A @('shell',$remoteInjection)) -join "`n"
        if($injectOutput -match 'sendevent:|Permission denied|not found') {throw "Touch injection failed on race trial $trial : $injectOutput"}
        Start-Sleep -Milliseconds 350
        $gestureLog=(A @('logcat','-d','-s','FloatingService:D')) -join "`n"
        $menuAttached=$gestureLog -match 'Quick menu attached; active windows=1'
        $menuRemoved=$gestureLog -match 'Quick menu removal: attached=true removed=true active windows=0'
        if($menuAttached){$attachedTrials++}
        if($menuAttached -and !$menuRemoved){throw "Menu attached but was not synchronously removed by drag at $holdMs ms (trial $trial).`n$gestureLog"}
        $overlayCount=0
        for($attempt=0;$attempt -lt 8;$attempt++) {
            $dump=(A @('shell','dumpsys','window','windows')) -join "`n"
            $blocks=[regex]::Split($dump,'(?m)^\s+Window #')
            $active=@($blocks | Where-Object {
                $_ -match "package=$([regex]::Escape($app)) appop=" -and
                $_ -match '(?:ty=(?:2002|2038)\b|ty=APPLICATION_OVERLAY\b)' -and
                $_ -match 'mHasSurface=true'
            })
            $overlayCount=$active.Count
            if($overlayCount -eq 1){break}
            if($overlayCount -gt 1){throw "Orphan/duplicate app overlay after race trial $trial ($holdMs ms): $overlayCount surfaces.`n$gestureLog"}
            Start-Sleep -Milliseconds 200
        }
        if($overlayCount -ne 1){throw "Controls overlay disappeared after race trial $trial ($holdMs ms).`n$gestureLog"}
        $result="trial=$trial hold=${holdMs}ms menuAttached=$menuAttached menuRemoved=$menuRemoved overlays=$overlayCount"
        $raceResults.Add($result)
        Write-Output $result
    }
    $minimumAttached=[Math]::Min(3,$RaceTrials)
    if($attachedTrials -lt $minimumAttached){throw "Only $attachedTrials/$RaceTrials trials observed the quick menu; exact race coverage is insufficient (minimum=$minimumAttached)."}
    $raceResults.Add("PASS: $RaceTrials continuous hold-and-drag trials; $attachedTrials showed and removed the quick menu; one controls overlay remained after every trial.")
    $raceResults | Out-File $raceArtifact -Encoding utf8
}
$log=(A @('logcat','-d','-v','threadtime')) -join "`n"
$log | Out-File (Join-Path $artifact 'overlay-cases.log') -Encoding utf8
if($log -match 'FATAL EXCEPTION|ANR in com.fixbyte.floatingvolume.debug|did not then call Service.startForeground'){throw 'Crash/ANR detected during overlay cases.'}
A @('shell','am','start','-W','-n',"$app/com.fixbyte.floatingvolume.MainActivity") | Out-Null
Set-Switch 0 $false
Set-Switch 3 $true
Write-Output "PASS: $Rotations measured rotations, $Gestures sequential gestures and $RaceTrials precision hold/drag race trials."
