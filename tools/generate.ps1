param([string]$Excel2pb = "$PSScriptRoot/../.tools/excel2pb.exe")
$ErrorActionPreference = 'Stop'
$root = Split-Path $PSScriptRoot -Parent
$previousPath = $env:PATH
$previousPrefix = $env:PROTOC_GEN_GDSCRIPT_PREFIX
try {
    $env:PATH = "$PSScriptRoot;$env:PATH"
    $env:PROTOC_GEN_GDSCRIPT_PREFIX = 'res://protobuf/generated/table/'
    Push-Location $root
    & $Excel2pb -config table/excel2pb.yaml
    if ($LASTEXITCODE -ne 0) { throw 'excel2pb generation failed' }
    $generated = Join-Path $root 'game/internal/generated'
    New-Item -ItemType Directory -Force $generated | Out-Null
    Copy-Item "$root/build/tables/go/internal/generated/*.pb.go" -Destination $generated
    gofmt -w game/internal/generated game/internal/generatedloaders
    if ($LASTEXITCODE -ne 0) { throw 'gofmt failed' }
} finally {
    Pop-Location
    $env:PATH = $previousPath
    $env:PROTOC_GEN_GDSCRIPT_PREFIX = $previousPrefix
}
