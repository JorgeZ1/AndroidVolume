param([string]$Serial='emulator-5582', [int]$ExpectedApi=27)
$ErrorActionPreference='Stop'
if ($Serial -notlike 'emulator-*') { throw 'Dedicated emulator required; this test seeds preferences.' }
$adb='C:\Users\Jorge\AppData\Local\Android\Sdk\platform-tools\adb.exe'
$app='com.fixbyte.floatingvolume.debug'
$artifact=Join-Path $PSScriptRoot '..\docs\test-artifacts\settings-sync'
function A([string[]]$Arguments) {
    $output=& $adb -s $Serial @Arguments
    if ($LASTEXITCODE -ne 0) { throw "ADB failed: $($Arguments -join ' ')" }
    return $output
}
if ((A @('shell','getprop','ro.build.version.sdk')).Trim() -ne "$ExpectedApi") { throw 'API mismatch.' }
A @('root') | Out-Null
A @('wait-for-device') | Out-Null
if ((A @('shell','id','-u')).Trim() -ne '0') { throw 'Rootable QA image required for the non-exported service.' }
function Rect {
    for($i=0; $i -lt 20; $i++) {
        $dump=(A @('shell','dumpsys','window','windows')) -join "`n"
        $blocks=[regex]::Split($dump,'(?m)^\s+Window #')
        $controls=@($blocks | Where-Object {
            $_ -match 'FloatingVolume controls\}' -and $_ -match "package=$([regex]::Escape($app)) appop=" -and $_ -match 'mHasSurface=true'
        })
        if($controls.Count -eq 1) {
            $m=[regex]::Match($controls[0],'(?:mFrame=| frame=)\[(-?\d+),(-?\d+)\]\[(-?\d+),(-?\d+)\]')
            if($m.Success) { return @($m.Groups[1..4] | ForEach-Object { [int]$_.Value }) }
        }
        Start-Sleep -Milliseconds 250
    }
    throw 'Exactly one surfaced controls window was not found.'
}
function Tap-Volume([bool]$Up) {
    $r=Rect
    $fraction=if($Up){0.25}else{0.75}
    A @('shell','input','tap',"$([int](($r[0]+$r[2])/2))","$([int]($r[1]+($r[3]-$r[1])*$fraction))") | Out-Null
}
function Check([int]$Before,[int]$Target,[bool]$Up) {
    A @('shell','media','volume','--stream','3','--set',"$Before") | Out-Null
    A @('logcat','-c') | Out-Null
    Tap-Volume $Up
    for($i=0; $i -lt 15; $i++) {
        $log=(A @('logcat','-d','-s','FloatingService:D')) -join "`n"
        $requests=[regex]::Matches($log,'Volume request: stream=MEDIA before=(\d+) target=(\d+) actual=(\d+)')
        if($requests.Count) {
            $r=$requests[$requests.Count-1]
            if([int]$r.Groups[1].Value -ne $Before -or [int]$r.Groups[2].Value -ne $Target -or
                [int]$r.Groups[3].Value -ne $Target) { throw "Unexpected real volume request: $($r.Value)" }
            return $r.Value
        }
        Start-Sleep -Milliseconds 150
    }
    throw 'No real volume request was recorded for the tap.'
}
[xml]$original=(A @('shell','run-as',$app,'cat','shared_prefs/prefs.xml')) -join "`n"
$results=[Collections.Generic.List[string]]::new()
try {
    foreach($step in @(1,3,5)) {
        A @('shell','am','force-stop',$app) | Out-Null
        [xml]$prefs=$original.OuterXml
        foreach($name in @('widget_vol_step','widget_audio_stream','widget_auto_peek')) {
            $node=$prefs.map.ChildNodes | Where-Object name -eq $name
            if(!$node){throw "Saved fixture lacks $name"}
            switch($name) {
                'widget_vol_step' { $node.value="$step" }
                'widget_audio_stream' { $node.InnerText='MEDIA' }
                'widget_auto_peek' { $node.value='false' }
            }
        }
        $input=Join-Path $artifact "step-$step-input.xml"
        $prefs.OuterXml | Out-File $input -Encoding utf8
        A @('push',$input,'/data/local/tmp/settings-volume.xml') | Out-Null
        A @('shell','run-as',$app,'cp','/data/local/tmp/settings-volume.xml','shared_prefs/prefs.xml') | Out-Null
        A @('shell','am','start','-n',"$app/com.fixbyte.floatingvolume.MainActivity") | Out-Null
        A @('shell','am','start-foreground-service','-n',"$app/com.fixbyte.floatingvolume.FloatingVolumeService") | Out-Null
        Rect | Out-Null
        A @('shell','input','keyevent','KEYCODE_HOME') | Out-Null
        foreach($case in @(@{before=7;target=7+$step;up=$true},@{before=7;target=7-$step;up=$false},
            @{before=0;target=0;up=$false},@{before=15;target=15;up=$true})) {
            $result=Check $case.before $case.target $case.up
            $line="PASS step=$step $result"
            $results.Add($line)
            Write-Output $line
        }
    }
} finally {
    A @('shell','am','force-stop',$app) | Out-Null
    $restore=Join-Path $artifact 'volume-test-original-prefs.xml'
    $original.OuterXml | Out-File $restore -Encoding utf8
    A @('push',$restore,'/data/local/tmp/settings-volume-restore.xml') | Out-Null
    A @('shell','run-as',$app,'cp','/data/local/tmp/settings-volume-restore.xml','shared_prefs/prefs.xml') | Out-Null
    $results | Out-File (Join-Path $artifact 'volume-steps-results.log') -Encoding utf8
}
Write-Output 'PASS: steps 1/3/5 apply exactly in both directions outside the app and saturate at the platform limits.'
