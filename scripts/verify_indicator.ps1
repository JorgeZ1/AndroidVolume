param(
    [string]$AdbPath = 'C:\Users\Jorge\AppData\Local\Android\Sdk\platform-tools\adb.exe',
    [string]$Serial = '',
    [string]$AppId = 'com.fixbyte.floatingvolume.debug',
    [int]$ExpectedGapDp = 10
)
$ErrorActionPreference = 'Stop'
$adbArgs = if ($Serial) { @('-s', $Serial) } else { @() }

function Convert-Rect($match) {
    [pscustomobject]@{ Left=[int]$match.Groups[1].Value; Top=[int]$match.Groups[2].Value;
        Right=[int]$match.Groups[3].Value; Bottom=[int]$match.Groups[4].Value }
}

# Capture first: the indicator normally closes after 1.8 seconds.
$dump = (& $AdbPath @adbArgs shell dumpsys window windows) -join "`n"
$blocks = [regex]::Split($dump, '(?m)^  Window #')
$frames = @{}
foreach ($title in @('controls', 'indicator')) {
    $matches = @($blocks | Where-Object {
        $_ -match "FloatingVolume $title\}" -and $_ -match "package=$([regex]::Escape($AppId)) appop="
    })
    if ($matches.Count -ne 1) { throw "Expected one $title window, found $($matches.Count). Show the indicator before running this check." }
    $match = [regex]::Match($matches[0], '(?:mFrame=| frame=)\[(-?\d+),(-?\d+)\]\[(-?\d+),(-?\d+)\]')
    if (!$match.Success) { throw "No frame for $title" }
    $frames[$title] = Convert-Rect $match
}
$controls = $frames.controls
$indicator = $frames.indicator
$gap = if ($indicator.Right -le $controls.Left) { $controls.Left - $indicator.Right }
       elseif ($indicator.Left -ge $controls.Right) { $indicator.Left - $controls.Right }
       else { throw 'Indicator overlaps the controls horizontally' }

$deviceDensity = (& $AdbPath @adbArgs shell wm density) -join "`n"
$densityMatches = [regex]::Matches($deviceDensity, '(?:Physical|Override) density: (\d+)')
$density = [int]$densityMatches[$densityMatches.Count - 1].Groups[1].Value
$expected = [int][math]::Round($ExpectedGapDp * $density / 160.0)
if ([math]::Abs($gap - $expected) -gt 1) { throw "Gap=$gap px; expected=$expected px" }

$appPid = ((& $AdbPath @adbArgs shell pidof $AppId) -join '').Trim()
$logs = (& $AdbPath @adbArgs logcat -d -t 80 --pid=$appPid -s FloatingService:D) -join "`n"
$bounds = [regex]::Matches($logs, 'available=OverlayRect\(left=(\d+), top=(\d+), right=(\d+), bottom=(\d+)\)')
if ($bounds.Count -eq 0) { throw 'No safe bounds diagnostic for this process' }
$available = Convert-Rect $bounds[$bounds.Count - 1]
if ($indicator.Left -lt $available.Left -or $indicator.Top -lt $available.Top -or
    $indicator.Right -gt $available.Right -or $indicator.Bottom -gt $available.Bottom) {
    throw 'Indicator exceeds safe display bounds'
}
$margin = [int][math]::Round(8 * $density / 160.0)
$height = $indicator.Bottom - $indicator.Top
$centeredTop = $controls.Top + [int][math]::Floor(($controls.Bottom - $controls.Top) / 2.0) - [int][math]::Floor($height / 2.0)
$expectedTop = [math]::Max($available.Top + $margin, [math]::Min($centeredTop, $available.Bottom - $margin - $height))
if ([math]::Abs($indicator.Top - $expectedTop) -gt 1) { throw "Indicator Y=$($indicator.Top); expected=$expectedTop" }
[pscustomobject]@{ Controls=$controls; Indicator=$indicator; Available=$available;
    GapPixels=$gap; GapDp=$gap * 160.0 / $density; Passed=$true } | ConvertTo-Json -Compress
