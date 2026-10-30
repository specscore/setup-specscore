$ErrorActionPreference = 'Stop'
$version = $env:SPECSCORE_VERSION
if ($version -notmatch '^v[0-9]+\.[0-9]+\.[0-9]+(?:-[0-9A-Za-z.-]+)?$') {
    throw 'version must be an exact release tag such as v0.55.0'
}
$expectedInput = $env:SPECSCORE_EXPECTED_SHA256
if ($expectedInput -and $expectedInput -notmatch '^[0-9a-fA-F]{64}$') {
    throw 'expected-sha256 must be 64 hexadecimal characters'
}
$osName = switch ($env:RUNNER_OS) { 'Linux' { 'linux' } 'macOS' { 'darwin' } 'Windows' { 'windows' } default { throw "unsupported runner OS: $env:RUNNER_OS" } }
$arch = switch ($env:RUNNER_ARCH) { 'X64' { 'amd64' } 'ARM64' { 'arm64' } default { throw "unsupported runner architecture: $env:RUNNER_ARCH" } }
if ($osName -eq 'windows' -and $arch -eq 'arm64') { throw 'SpecScore does not publish Windows arm64 archives' }
$number = $version.Substring(1)
$extension = if ($osName -eq 'windows') { 'zip' } else { 'tar.gz' }
$archive = "specscore_${number}_${osName}_${arch}.${extension}"
$base = "https://github.com/specscore/specscore-cli/releases/download/$version"
$tmp = Join-Path $env:RUNNER_TEMP ("setup-specscore-" + [guid]::NewGuid())
New-Item -ItemType Directory -Path $tmp | Out-Null
try {
    $archivePath = Join-Path $tmp $archive
    $manifest = Join-Path $tmp 'checksums.txt'
    Invoke-WebRequest -Uri "$base/$archive" -OutFile $archivePath
    Invoke-WebRequest -Uri "$base/specscore_${number}_checksums.txt" -OutFile $manifest
    $entries = @(Get-Content $manifest | Where-Object { $_ -match "\s$([regex]::Escape($archive))\s*$" })
    if ($entries.Count -ne 1) { throw "missing or duplicate checksum for $archive" }
    $expected = ($entries[0] -split '\s+')[0]
    if ($expected -notmatch '^[0-9a-fA-F]{64}$') { throw "invalid checksum for $archive" }
    $actual = (Get-FileHash -Algorithm SHA256 -Path $archivePath).Hash
    if ($actual -ine $expected) { throw "checksum mismatch for $archive" }
    if ($expectedInput -and $actual -ine $expectedInput) { throw "expected-sha256 mismatch for $archive" }
    $extract = Join-Path $tmp 'extract'
    New-Item -ItemType Directory -Path $extract | Out-Null
    if ($extension -eq 'zip') { Expand-Archive -Path $archivePath -DestinationPath $extract }
    else {
        & tar -xzf $archivePath -C $extract
        if ($LASTEXITCODE -ne 0) { throw 'archive extraction failed' }
    }
    $binary = if ($osName -eq 'windows') { 'specscore.exe' } else { 'specscore' }
    $source = Join-Path $extract $binary
    if (-not (Test-Path -LiteralPath $source -PathType Leaf)) { throw 'binary missing from archive' }
    $installDir = Join-Path $env:RUNNER_TEMP ("specscore-bin-" + [guid]::NewGuid())
    New-Item -ItemType Directory -Path $installDir | Out-Null
    Copy-Item -LiteralPath $source -Destination (Join-Path $installDir $binary)
    if ($osName -ne 'windows') { & chmod +x (Join-Path $installDir $binary); if ($LASTEXITCODE -ne 0) { throw 'chmod failed' } }
    Add-Content -Path $env:GITHUB_PATH -Value $installDir
    Add-Content -Path $env:GITHUB_OUTPUT -Value "version=$version"
} finally { Remove-Item -LiteralPath $tmp -Recurse -Force -ErrorAction SilentlyContinue }
