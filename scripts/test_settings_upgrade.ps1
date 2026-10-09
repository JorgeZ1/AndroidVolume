param(
    [string]$Serial = 'emulator-5584',
    [string]$Apk = (Join-Path $PSScriptRoot '..\build\app\outputs\flutter-apk\app-debug.apk'),
    [int]$ExpectedApi = 29,
    [switch]$ResetOnly
)
$ErrorActionPreference = 'Stop'
if ($Serial -notlike 'emulator-*') { throw 'This fixture test must only run on a dedicated emulator.' }
$adb = 'C:\Users\Jorge\AppData\Local\Android\Sdk\platform-tools\adb.exe'
$app = 'com.fixbyte.floatingvolume.debug'
$artifact = Join-Path $PSScriptRoot '..\docs\test-artifacts\settings-sync'
function A([string[]]$Arguments) {
    $output = & $adb -s $Serial @Arguments
    if ($LASTEXITCODE -ne 0) { throw "ADB failed: $($Arguments -join ' ')" }
    return $output
}
if ((A @('shell','getprop','ro.build.version.sdk')).Trim() -ne "$ExpectedApi") { throw 'API mismatch.' }
A @('shell','appops','set',$app,'SYSTEM_ALERT_WINDOW','allow') | Out-Null
A @('shell','dumpsys','deviceidle','whitelist',"+$app") | Out-Null
function Seed {
    A @('shell','am','force-stop',$app) | Out-Null
    foreach ($kind in @('native','legacy')) {
        A @('push',"$artifact\$kind-fixture.xml","/data/local/tmp/settings-$kind.xml") | Out-Null
    }
    A @('shell','run-as',$app,'mkdir','-p','shared_prefs') | Out-Null
    A @('shell','run-as',$app,'cp','/data/local/tmp/settings-native.xml','shared_prefs/prefs.xml') | Out-Null
    A @('shell','run-as',$app,'cp','/data/local/tmp/settings-legacy.xml','shared_prefs/FlutterSharedPreferences.xml') | Out-Null
}
function Read-Prefs {
    [xml]$xml = (A @('shell','run-as',$app,'cat','shared_prefs/prefs.xml')) -join "`n"
    $values = @{}
    foreach ($node in $xml.map.ChildNodes) {
        $values[$node.name] = if ($node.LocalName -eq 'string') { $node.InnerText } else { $node.value }
    }
    return $values
}
function Open {
    A @('shell','am','force-stop',$app) | Out-Null
    A @('shell','am','start','-n',"$app/com.fixbyte.floatingvolume.MainActivity") | Out-Null
}
function Ui {
    for ($attempt=0; $attempt -lt 12; $attempt++) {
        $dump=(A @('shell','uiautomator','dump','/sdcard/settings-sync-ui.xml')) -join ''
        if ($dump -match 'UI hierchary dumped') {
            [xml]$tree=(A @('shell','cat','/sdcard/settings-sync-ui.xml')) -join ''
            if ($tree.SelectSingleNode("//node[contains(@content-desc,'Floating Volume')]")) { return $tree }
        }
        Start-Sleep -Milliseconds 500
    }
    throw 'Home did not become accessible.'
}
function Tap($Node) {
    $n=[regex]::Matches($Node.bounds,'\d+') | ForEach-Object { [int]$_.Value }
    A @('shell','input','tap',"$([int](($n[0]+$n[2])/2))","$([int](($n[1]+$n[3])/2))") | Out-Null
}
function Find([string]$Label) {
    for($i=0; $i -lt 24; $i++) {
        $tree=Ui
        $node=$tree.SelectSingleNode("//node[contains(@content-desc,'$Label')]")
        if ($node) {
            $bounds=[regex]::Matches($node.bounds,'\d+') | ForEach-Object { [int]$_.Value }
            if ($bounds[3]-$bounds[1] -ge 24) { return $node }
            if ($bounds[1] -le 180) {
                A @('shell','input','swipe','350','400','350','680','250') | Out-Null
            } else {
                A @('shell','input','swipe','350','980','350','720','250') | Out-Null
            }
            continue
        }
        A @('shell','input','swipe','350','980','350','650','250') | Out-Null
    }
    throw "Could not find $Label."
}
function Inspect-Buttons([int]$Step, [string]$Size, [string]$Phase) {
    $button=Find 'Floating buttons'
    if ($button.'content-desc' -match 'Collapsed') { Tap $button }
    Find 'Volume step per tap' | Out-Null
    $tree=Ui
    $tree.OuterXml | Out-File (Join-Path $artifact "$Phase-ui.xml") -Encoding utf8
    $labels=@($tree.SelectNodes('//node[@content-desc!=""]') | ForEach-Object { $_.'content-desc' })
    $expected = if ($Step -eq 1) { '1 level' } else { "$Step levels" }
    if ($expected -notin $labels) { throw "Visible step differs: expected $expected." }
    if ($Size -notin $labels) { throw "Visible size differs: expected $Size." }
    Write-Output "PASS $Phase UI: $expected / $Size"
}
if ($ResetOnly) {
    Open
    $button=Find 'Floating buttons'
    if ($button.'content-desc' -match 'Collapsed') { Tap $button }
    Tap (Find 'Reset this section')
    for($attempt=0;$attempt -lt 20;$attempt++) {
        $saved=Read-Prefs
        if($saved['widget_btn_gap'] -eq '10' -and $saved['widget_auto_peek'] -eq 'true' -and
            $saved['widget_vol_step'] -eq '1') { break }
        Start-Sleep -Milliseconds 150
    }
    foreach ($pair in @{widget_vol_step='1';widget_btn_size='44';widget_btn_gap='10';
        widget_auto_peek='true';widget_peek_delay='1800';widget_peek_size='20';
        widget_audio_stream='ALARM';widget_show_mixer='false';widget_ind_width='48';
        widget_ind_delay='2250'}.GetEnumerator()) {
        if ($saved[$pair.Key] -ne $pair.Value) { throw "Reset changed or failed to restore $($pair.Key)." }
    }
    Open
    Inspect-Buttons 1 '44dp' 'buttons-reset'
    $saved=Read-Prefs
    if ($saved['widget_auto_peek'] -ne 'true' -or $saved['widget_peek_delay'] -ne '1800' -or
        $saved['widget_audio_stream'] -ne 'ALARM' -or $saved['widget_ind_width'] -ne '48') {
        throw 'Cold restart undid the button reset or changed another section.'
    }
    Find 'Hide after' | Out-Null
    $tree=Ui
    if (!$tree.SelectSingleNode("//node[@content-desc='1.8 s']")) { throw 'Default delay is not shown precisely.' }
    Write-Output 'PASS: UI button reset survives a cold restart, keeps audio/indicator settings, and displays 1.8 s.'
    exit 0
}
# The installed pre-fix baseline retains step=3 but displays step=1 after a cold start.
Seed
Open
Inspect-Buttons 1 '44px' 'baseline'
if ((Read-Prefs)['widget_vol_step'] -ne '3') { throw 'Baseline did not retain native step 3.' }
Write-Output 'REPRODUCED baseline: native step 3, visible step 1 (no automatic increment).'
# Prepare known saved settings while stopped, as if left by the old installation.
Seed
for ($cycle=1; $cycle -le 3; $cycle++) {
    A @('install','-r',$Apk) | Out-Null
    Open
    Inspect-Buttons 3 '64dp' "upgrade-$cycle"
    $saved=Read-Prefs
    foreach ($pair in @{widget_vol_step='3';widget_btn_size='64';widget_btn_gap='22';
        widget_audio_stream='ALARM';widget_peek_delay='5000';widget_peek_size='24';
        widget_auto_peek='false';widget_show_mixer='false';widget_ind_height='190';
        widget_ind_width='48';widget_ind_gap='25';widget_ind_delay='2250';
        widget_ind_number='false';widget_ind_icon='false';widget_haptic='true'}.GetEnumerator()) {
        if ($saved[$pair.Key] -ne $pair.Value) { throw "Cycle $cycle changed $($pair.Key)." }
    }
    (A @('shell','run-as',$app,'cat','shared_prefs/prefs.xml')) |
        Out-File (Join-Path $artifact "upgrade-$cycle-prefs.xml") -Encoding utf8
    Write-Output "PASS upgrade ${cycle}: all asserted saved values preserved."
}
Write-Output 'PASS: baseline mismatch reproduced; three reinstall/cold-start cycles preserve the saved settings and show the effective step.'
