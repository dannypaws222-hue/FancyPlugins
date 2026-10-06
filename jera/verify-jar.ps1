# Checks a FancyNpcs jar for JeraCraft's Folia 1.21.11 / Java 21 servers.
#   A: every class is Java 21 or older (class-file major <= 65)
#   B: Npc_1_21_11.update() null-checks the custom_model attribute before containsKey
#   C: no CamelAttributes class calls Bukkit.getScheduler() (throws on Folia)
# Exit 0 = all pass, 1 = any fail. Usage: powershell -File jera\verify-jar.ps1 -Jar <path>
param(
    [Parameter(Mandatory = $true)][string]$Jar,
    [string]$JavaHome = 'C:\Program Files\Eclipse Adoptium\jdk-21.0.11.10-hotspot'
)
$ErrorActionPreference = 'Stop'
$Jar = (Resolve-Path $Jar).Path
$javap = Join-Path $JavaHome 'bin\javap.exe'
if (-not (Test-Path $javap)) { Write-Output "javap not found at $javap (pass -JavaHome)"; exit 1 }
$failed = $false

Add-Type -AssemblyName System.IO.Compression.FileSystem
$zip = [IO.Compression.ZipFile]::OpenRead($Jar)
try {
    # A: bytes 6-7 of a class file are its big-endian major version.
    $bad = @()
    $camel = @()
    $buf = New-Object byte[] 8
    foreach ($e in $zip.Entries) {
        if (-not $e.FullName.EndsWith('.class')) { continue }
        if ($e.FullName -match '/attributes/CamelAttributes(\$.*)?\.class$') {
            $camel += ($e.FullName -replace '\.class$', '' -replace '/', '.')
        }
        $s = $e.Open()
        try {
            $n = 0
            while ($n -lt 8) { $r = $s.Read($buf, $n, 8 - $n); if ($r -le 0) { break }; $n += $r }
        } finally { $s.Dispose() }
        $major = if ($n -eq 8) { $buf[6] * 256 + $buf[7] } else { -1 }
        if ($major -gt 65 -or $major -lt 0) { $bad += "$($e.FullName) (major $major)" }
    }
} finally { $zip.Dispose() }

if ($bad.Count -gt 0) {
    $failed = $true
    Write-Output "FAIL A: $($bad.Count) class(es) newer than Java 21 or unreadable:"
    $bad | Select-Object -First 10 | ForEach-Object { Write-Output "  $_" }
}

# B: inside update(Player, boolean), the ldc "custom_model" must be followed by an
# ifnull before the next Map.containsKey.
$npc = & $javap -c -p -cp $Jar 'de.oliver.fancynpcs.v1_21_11.Npc_1_21_11' 2>&1
$inUpdate = $false; $sawLdc = $false; $guarded = $false; $result = 'no custom_model lookup found'
foreach ($line in $npc) {
    if ($line -match '^  \S.*\(.*\);$') { $inUpdate = $line -match ' update\(org\.bukkit\.entity\.Player, boolean\);$'; continue }
    if (-not $inUpdate) { continue }
    if ($line -match 'String custom_model$') { $sawLdc = $true; $guarded = $false; continue }
    if ($sawLdc -and $line -match '\sifnull\s') { $guarded = $true; continue }
    if ($sawLdc -and $line -match 'java/util/Map\.containsKey') {
        $result = if ($guarded) { 'ok' } else { 'containsKey reached without ifnull' }
        break
    }
}
if ($result -ne 'ok') { $failed = $true; Write-Output "FAIL B: Npc_1_21_11.update(): $result" }

# C: Bukkit.getScheduler() throws UnsupportedOperationException on Folia.
if ($camel.Count -eq 0) {
    $failed = $true; Write-Output 'FAIL C: no CamelAttributes class found'
} else {
    foreach ($c in $camel) {
        $code = & $javap -c -p -cp $Jar $c 2>&1
        if ($code -match 'org/bukkit/Bukkit\.getScheduler') { $failed = $true; Write-Output "FAIL C: $c calls Bukkit.getScheduler()" }
    }
}

if ($failed) { exit 1 }
Write-Output "OK: $Jar passes A (Java 21), B (custom_model guard), C (Folia camel)"
exit 0
