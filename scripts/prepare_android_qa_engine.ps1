$ErrorActionPreference='Stop'
$root='D:\AndroidQA\FloatingVolume\engine'
$cache='D:\AndroidQA\FloatingVolume\downloads'
New-Item -ItemType Directory -Force $cache | Out-Null
if(Test-Path "$root\emulator\emulator.exe"){Write-Output "Existing isolated emulator: $root"; exit 0}
[xml]$repo=(Invoke-WebRequest 'https://dl.google.com/android/repository/repository2-3.xml').Content
$package=$repo.SelectSingleNode("//*[local-name()='remotePackage' and @path='emulator']")
$archive=@($package.archives.archive | Where-Object 'host-os' -eq 'windows')[0].complete
if(!$archive){throw 'Official Windows emulator archive unavailable.'}
$zip=Join-Path $cache ([string]$archive.url)
Write-Output "Preparing isolated emulator $($package.revision.major).$($package.revision.minor).$($package.revision.micro); shared SDK engine stays unchanged."
& curl.exe --silent --show-error --fail --location --retry 3 --continue-at - --output $zip "https://dl.google.com/android/repository/$($archive.url)"
if($LASTEXITCODE -ne 0){throw 'Emulator download failed.'}
if((Get-Item $zip).Length -ne [long]$archive.size){throw 'Emulator archive size mismatch.'}
if((Get-FileHash $zip -Algorithm SHA1).Hash -ne [string]$archive.checksum.'#text'){throw 'Official emulator checksum mismatch.'}
if(Test-Path $root){throw 'Incomplete isolated engine requires inspection before overwrite.'}
Expand-Archive -LiteralPath $zip -DestinationPath $root
if(!(Test-Path "$root\emulator\emulator.exe")){throw 'Unexpected official emulator archive layout.'}
& "$root\emulator\emulator.exe" -version
