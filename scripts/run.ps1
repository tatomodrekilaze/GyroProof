$ErrorActionPreference = "Stop"

$projectRoot = Split-Path -Parent $PSScriptRoot
$localTools = Join-Path $projectRoot "..\..\work\gyroproof-toolchains"
$leanBin = Join-Path $localTools "lean-4.19.0-windows\bin"
$juliaExe = Join-Path $localTools "julia-1.13.1\bin\julia.exe"

if (-not (Test-Path (Join-Path $leanBin "lake.exe"))) {
    $lakeCommand = Get-Command lake -ErrorAction Stop
    $leanBin = Split-Path -Parent $lakeCommand.Source
}

if (-not (Test-Path $juliaExe)) {
    $juliaCommand = Get-Command julia -ErrorAction Stop
    $juliaExe = $juliaCommand.Source
}

$env:PATH = $leanBin + ";" + $env:PATH
$env:MATHLIB_CACHE_DIR = Join-Path $projectRoot ".cache\mathlib"
New-Item -ItemType Directory -Force -Path $env:MATHLIB_CACHE_DIR | Out-Null

Push-Location $projectRoot
try {
    if (-not (Test-Path ".lake\packages\mathlib")) {
        & (Join-Path $leanBin "lake.exe") update
        if ($LASTEXITCODE -ne 0) { throw "Lake dependency setup failed." }
    }

    & (Join-Path $leanBin "lake.exe") build
    if ($LASTEXITCODE -ne 0) { throw "Lean build failed." }

    & $juliaExe --project=. scripts\phase_ledger.jl `
        --dt 0.1 --steps 100 --omega 1.0 `
        --output results\phase_ledger.csv --svg results\phase_ledger.svg
    if ($LASTEXITCODE -ne 0) { throw "Julia simulation failed." }
}
finally {
    Pop-Location
}
