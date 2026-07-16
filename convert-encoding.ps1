param(
  [Parameter(Mandatory=$true)][string]$InputFile,
  [string]$OutputFile = "",
  [ValidateSet("Auto","ToUtf8","ToEucKr")][string]$Mode = "Auto",
  [switch]$NoBom
)

$ErrorActionPreference = "Stop"

$cp949 = [System.Text.Encoding]::GetEncoding(949)
$utf8Strict = New-Object System.Text.UTF8Encoding($false, $true)

$bytes = [System.IO.File]::ReadAllBytes($InputFile)

# Detect source encoding: BOM first, then strict UTF-8 decode, else CP949
if ($bytes.Length -ge 3 -and $bytes[0] -eq 0xEF -and $bytes[1] -eq 0xBB -and $bytes[2] -eq 0xBF) {
  $srcEnc = "UTF-8 (BOM)"
  $text = $utf8Strict.GetString($bytes, 3, $bytes.Length - 3)
} else {
  try {
    $text = $utf8Strict.GetString($bytes)
    $srcEnc = "UTF-8"
  } catch {
    $text = $cp949.GetString($bytes)
    $srcEnc = "EUC-KR(CP949)"
  }
}

if ($text.Contains([char]0xFFFD)) {
  Write-Warning "This file already contains replacement characters (broken text). Those characters cannot be recovered - re-export from the scale if possible."
}

if ($Mode -eq "Auto") {
  $Mode = if ($srcEnc -like "UTF-8*") { "ToEucKr" } else { "ToUtf8" }
}

if ($OutputFile -eq "") {
  $dir  = [System.IO.Path]::GetDirectoryName($InputFile)
  $name = [System.IO.Path]::GetFileNameWithoutExtension($InputFile)
  $ext  = [System.IO.Path]::GetExtension($InputFile)
  $suffix = if ($Mode -eq "ToUtf8") { "_utf8" } else { "_euckr" }
  $OutputFile = [System.IO.Path]::Combine($dir, "$name$suffix$ext")
}

if ($Mode -eq "ToUtf8") {
  $outEnc = New-Object System.Text.UTF8Encoding((-not $NoBom))
  $outName = "UTF-8"
} else {
  $roundTrip = $cp949.GetString($cp949.GetBytes($text))
  if ($roundTrip -ne $text) {
    Write-Warning "Some characters cannot be represented in EUC-KR and will be written as '?'."
  }
  $outEnc = $cp949
  $outName = "EUC-KR(CP949)"
}

[System.IO.File]::WriteAllBytes($OutputFile, $outEnc.GetBytes($text))

Write-Host ("Source encoding : {0}" -f $srcEnc)
Write-Host ("Converted to    : {0}" -f $outName)
Write-Host ("Output file     : {0}" -f $OutputFile)
