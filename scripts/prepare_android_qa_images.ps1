param([int[]]$Apis = @(24,26,29,31,33,34,35,37))
$ErrorActionPreference = 'Stop'
$sdk = 'C:\Users\Jorge\AppData\Local\Android\Sdk'
$cache = 'D:\AndroidQA\FloatingVolume\downloads'
New-Item -ItemType Directory -Force $cache | Out-Null
foreach ($api in $Apis) {
    $repoName = if ($api -eq 37) { 'google_apis_playstore' } else { 'google_apis' }
    $repoUrl = "https://dl.google.com/android/repository/sys-img/$repoName/sys-img2-4.xml"
    [xml]$repo = (Invoke-WebRequest $repoUrl).Content
    $version = if ($api -eq 37) { '37.0' } else { "$api" }
    $tag = if ($api -eq 37) { 'google_apis_playstore_ps16k' } else { 'google_apis' }
    $package = "system-images;android-$version;$tag;x86_64"
    $node = $repo.SelectSingleNode("//*[local-name()='remotePackage' and @path='$package']")
    if (!$node) { throw "Official package unavailable: $package" }
    $target = Join-Path $sdk "system-images\android-$version\$tag\x86_64"
    if (Test-Path (Join-Path $target 'source.properties')) { Write-Output "Already installed: $package"; continue }
    $archive = $node.archives.archive.complete
    $zip = Join-Path $cache ([string]$archive.url)
    Write-Output "Downloading API $api ($($archive.size) bytes)"
    & curl.exe --fail --location --retry 5 --retry-all-errors --retry-delay 2 --continue-at - --output $zip "https://dl.google.com/android/repository/sys-img/$repoName/$($archive.url)"
    if ($LASTEXITCODE -ne 0) { throw "Download failed: API $api" }
    if ((Get-Item $zip).Length -ne [long]$archive.size) { throw "Size mismatch: API $api" }
    $expectedHash = [string]$archive.checksum.'#text'
    if ((Get-FileHash $zip -Algorithm SHA1).Hash -ne $expectedHash) { throw "Official checksum mismatch: API $api" }
    $staging = Join-Path $cache "extract-$api-$([guid]::NewGuid().ToString('N'))"
    Expand-Archive -LiteralPath $zip -DestinationPath $staging
    $source = Join-Path $staging 'x86_64'
    if (!(Test-Path (Join-Path $source 'source.properties'))) { throw "Unexpected archive layout: API $api" }
    $resolvedTarget = [IO.Path]::GetFullPath($target)
    if (!$resolvedTarget.StartsWith("$sdk\system-images\", [StringComparison]::OrdinalIgnoreCase)) { throw 'Install target escaped SDK system-images.' }
    if (Test-Path $target) { throw "Existing incomplete target requires inspection: $target" }
    New-Item -ItemType Directory -Force (Split-Path $target) | Out-Null
    Move-Item -LiteralPath $source -Destination $target
    Write-Output "Installed and checksum verified: $package"
}
