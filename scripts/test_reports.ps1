param([string]$ArtifactDirectory = 'docs/test-artifacts')
$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName System.Drawing
$directory = New-Item -ItemType Directory -Force -Path $ArtifactDirectory
$service = Get-Content lib/src/services/report_service.dart -Raw
$key = [regex]::Match($service, "static const _anon\s*=\s*'([^']+)'").Groups[1].Value
$base = 'https://clxclwegjkqvveuyzmaf.supabase.co'
$headers = @{ Authorization="Bearer $key"; apikey=$key }
$images = @()
foreach ($index in 1..2) {
  $bitmap = [System.Drawing.Bitmap]::new(480,240)
  $graphics = [System.Drawing.Graphics]::FromImage($bitmap)
  $font = [System.Drawing.Font]::new('Arial',24)
  try {
    $graphics.Clear($(if ($index -eq 1) { [System.Drawing.Color]::DarkBlue } else { [System.Drawing.Color]::DarkGreen }))
    $graphics.DrawString("Floating Volume`nTEST IMAGE $index`nNo personal data",$font,[System.Drawing.Brushes]::White,20,25)
    $path = Join-Path $directory.FullName "report-$index.png"
    $bitmap.Save($path,[System.Drawing.Imaging.ImageFormat]::Png)
    $images += @{ mime='image/png'; data=[Convert]::ToBase64String([IO.File]::ReadAllBytes($path)) }
  } finally { $graphics.Dispose(); $font.Dispose(); $bitmap.Dispose() }
}
$id = [guid]::NewGuid().ToString()
$payload = @{ id=$id; category='other'; description='INTEGRATION TEST: two synthetic images, no personal user data.'; images=$images;
 diagnostics=@{ manufacturer='TEST'; model='Synthetic integration test'; app_version='0.0.9+10'; android_sdk=33; version_code=10 } }
$json = $payload | ConvertTo-Json -Depth 8 -Compress
$reply = Invoke-WebRequest "$base/functions/v1/submit-report" -Method Post -Headers $headers -ContentType 'application/json' -Body $json
if ($reply.StatusCode -ne 201) { throw 'Report was not created' }
$response = $reply.Content | ConvertFrom-Json
if ($response.id -ne $id) { throw 'Wrong report ID' }
$replay = Invoke-WebRequest "$base/functions/v1/submit-report" -Method Post -Headers $headers -ContentType 'application/json' -Body $json
if ($replay.StatusCode -ne 200) { throw 'Idempotent retry failed' }
$payload.id = [guid]::NewGuid().ToString()
$payload.images = @($images[0],$images[1],$images[0])
$invalid = Invoke-WebRequest "$base/functions/v1/submit-report" -Method Post -Headers $headers -ContentType 'application/json' -Body ($payload | ConvertTo-Json -Depth 8 -Compress) -SkipHttpErrorCheck
if ($invalid.StatusCode -ne 400) { throw 'Three images were not rejected' }
$read = Invoke-WebRequest "$base/rest/v1/support_reports?select=id" -Headers $headers -SkipHttpErrorCheck
if ($read.StatusCode -notin @(401,403)) { throw 'Report table accessible through public key' }
$private = Invoke-WebRequest "$base/storage/v1/object/public/report-images/$id/1.png" -SkipHttpErrorCheck
if ($private.StatusCode -eq 200) { throw 'Image is publicly accessible' }
[pscustomobject]@{ ReportId=$id; ImagesSent=2; Replay=$replay.StatusCode; ThreeImagesRejected=$invalid.StatusCode; PublicTableDenied=$read.StatusCode; PublicImageDenied=$private.StatusCode } | ConvertTo-Json -Compress
