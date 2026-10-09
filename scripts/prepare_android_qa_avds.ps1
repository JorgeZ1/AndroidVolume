param([int[]]$Apis = @(24,25,26,28,29,30,31,32,33,34,35,37))
$ErrorActionPreference = 'Stop'
$sdk = 'C:\Users\Jorge\AppData\Local\Android\Sdk'
$avdRoot = 'D:\AndroidQA\FloatingVolume\avds'
$iniRoot = 'C:\Users\Jorge\.android\avd'
foreach ($api in $Apis) {
    $tag = if ($api -eq 37) { 'google_apis_playstore_ps16k' } else { 'google_apis' }
    $image = Join-Path $sdk "system-images\android-$api.0\$tag\x86_64"
    if ($api -ne 37) { $image = Join-Path $sdk "system-images\android-$api\$tag\x86_64" }
    if (!(Test-Path (Join-Path $image 'source.properties'))) { Write-Warning "API $api image not ready: $image"; continue }
    $name = "FloatingVolume_QA_API$api"
    $dir = Join-Path $avdRoot "$name.avd"
    $ini = Join-Path $iniRoot "$name.ini"
    if ((Test-Path $dir) -or (Test-Path $ini)) { Write-Output "Preserving existing AVD: $name"; continue }
    New-Item -ItemType Directory -Force $dir | Out-Null
    $ram = if ($api -ge 31) { 3072 } else { 1536 }
    $content = @"
avd.ini.encoding=UTF-8
AvdId=$name
avd.ini.displayname=Floating Volume QA API $api
abi.type=x86_64
hw.cpu.arch=x86_64
hw.cpu.ncore=2
hw.ramSize=$ram
hw.lcd.width=720
hw.lcd.height=1280
hw.lcd.density=320
hw.gpu.enabled=yes
hw.gpu.mode=auto
hw.keyboard=yes
hw.audioInput=no
hw.audioOutput=no
hw.camera.back=none
hw.camera.front=none
hw.device.name=pixel_2
hw.device.manufacturer=Google
hw.initialOrientation=Portrait
disk.dataPartition.size=6G
fastboot.forceColdBoot=yes
fastboot.forceFastBoot=no
PlayStore.enabled=$(if ($api -eq 37) { 'yes' } else { 'no' })
image.sysdir.1=$image\
tag.id=$(if ($api -eq 37) { 'google_apis_playstore' } else { 'google_apis' })
tag.display=$(if ($api -eq 37) { 'Google APIs PlayStore' } else { 'Google APIs' })
target=android-$api
showDeviceFrame=no
skin.dynamic=yes
"@
    Set-Content -LiteralPath (Join-Path $dir 'config.ini') -Value $content -Encoding ascii
    Set-Content -LiteralPath $ini -Value "avd.ini.encoding=UTF-8`npath=$dir`npath.rel=avd\$name.avd`ntarget=android-$api`n" -Encoding ascii
    Write-Output "Prepared isolated AVD $name with $ram MiB guest RAM."
}
