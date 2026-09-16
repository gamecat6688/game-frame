$ErrorActionPreference = 'Stop'
$root = Split-Path $PSScriptRoot -Parent
$previousPath = $env:PATH
$previousPrefix = $env:PROTOC_GEN_GDSCRIPT_PREFIX

function Get-ProtoInputs([string]$directory) {
    @(Get-ChildItem -LiteralPath $directory -Recurse -File -Filter '*.proto' |
        ForEach-Object { [IO.Path]::GetRelativePath($directory, $_.FullName).Replace('\', '/') } |
        Sort-Object)
}

function Sync-GeneratedFiles([string]$source, [string]$destination, [string]$filter) {
    $destination = [IO.Path]::GetFullPath($destination)
    if (!$destination.StartsWith($root + [IO.Path]::DirectorySeparatorChar, [StringComparison]::OrdinalIgnoreCase)) {
        throw "Generated output must stay inside the project: $destination"
    }
    New-Item -ItemType Directory -Force $destination | Out-Null
    $expected = @{}
    foreach ($file in Get-ChildItem -LiteralPath $source -Recurse -File -Filter $filter) {
        $relative = [IO.Path]::GetRelativePath($source, $file.FullName)
        $target = Join-Path $destination $relative
        $expected[$target] = $true
        New-Item -ItemType Directory -Force (Split-Path $target -Parent) | Out-Null
        Copy-Item -LiteralPath $file.FullName -Destination $target -Force
    }
    # Only remove obsolete generated files, never handwritten source or whole trees.
    foreach ($file in Get-ChildItem -LiteralPath $destination -Recurse -File -Filter $filter) {
        if (!$expected.ContainsKey($file.FullName)) {
            Remove-Item -LiteralPath $file.FullName
            if ($filter -eq '*.proto.gd' -and (Test-Path -LiteralPath ($file.FullName + '.uid'))) {
                Remove-Item -LiteralPath ($file.FullName + '.uid')
            }
        }
    }
}

try {
    $env:PATH = "$PSScriptRoot;$env:PATH"
    $env:PROTOC_GEN_GDSCRIPT_PREFIX = 'res://protobuf/generated/api/'
    Push-Location $root
    $shared = @(Get-ProtoInputs (Join-Path $root 'contracts/shared'))
    $private = @(Get-ProtoInputs (Join-Path $root 'contracts/server'))
    if ($shared.Count -eq 0 -or $private.Count -eq 0) { throw 'Shared and private proto inputs must not be empty' }
    $inputs = @($shared) + @($private)
    if (@($inputs | Select-Object -Unique).Count -ne $inputs.Count) {
        throw 'Shared and private proto paths must not shadow each other'
    }
    # Generate everything successfully before replacing previously working outputs.
    $stage = Join-Path $root ('build/proto-generation/' + [Guid]::NewGuid().ToString('N'))
    New-Item -ItemType Directory -Force "$stage/go", "$stage/gd", "$stage/python" | Out-Null
    & protoc -I contracts/shared -I contracts/server "--go_out=$stage/go" --go_opt=module=gameframe "--python_out=$stage/python" @inputs
    if ($LASTEXITCODE -ne 0) { throw 'Go/persistence protocol generation failed' }
    & protoc -I contracts/shared "--gdscript_out=$stage/gd" @shared
    if ($LASTEXITCODE -ne 0) { throw 'Godot protocol generation failed' }
    Sync-GeneratedFiles "$stage/go/internal/protocol" "$root/game/internal/protocol" '*.pb.go'
    Sync-GeneratedFiles "$stage/go/internal/persistence" "$root/game/internal/persistence" '*.pb.go'
    Sync-GeneratedFiles "$stage/gd" "$root/client/protobuf/generated/api" '*.proto.gd'
    Sync-GeneratedFiles "$stage/python" "$root/build/protocol" '*_pb2.py'
    Write-Host "Generated $($shared.Count) shared and $($private.Count) private proto files."
} finally {
    Pop-Location
    $env:PATH = $previousPath
    $env:PROTOC_GEN_GDSCRIPT_PREFIX = $previousPrefix
}
