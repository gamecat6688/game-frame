param(
    [string]$Godot = '',
    [string]$CompilerBin = '',
    [string]$Excel2pbSource = '',
    [switch]$SkipTables,
    [switch]$Test,
    [switch]$Headless
)
$ErrorActionPreference = 'Stop'
$root = Split-Path $PSScriptRoot -Parent
$localConfig = Join-Path $root 'tools.local.json'
if (Test-Path -LiteralPath $localConfig) {
    $settings = Get-Content -LiteralPath $localConfig -Raw | ConvertFrom-Json
    if (!$Godot) { $Godot = $settings.godot }
    if (!$CompilerBin) { $CompilerBin = $settings.compilerBin }
    if (!$Excel2pbSource) { $Excel2pbSource = $settings.excel2pbSource }
}
if (!$Godot) { $Godot = (Get-Command godot -ErrorAction Stop).Source }
$previousPath = $env:PATH
$previousCgo = $env:CGO_ENABLED
try {
    if ($CompilerBin) { $env:PATH = "$CompilerBin;$env:PATH" }
    $env:CGO_ENABLED = '1'
    foreach ($command in @('go', 'gcc', 'python', 'protoc', 'protoc-gen-go')) {
        Get-Command $command -ErrorAction Stop | Out-Null
    }
    $engineVersion = & $Godot --version
    if ($engineVersion -notmatch '^4\.7\.') { throw "This C bridge targets Godot 4.7.x; found $engineVersion" }
    New-Item -ItemType Directory -Force "$root/build", "$root/.tools", "$root/client/addons/game_bridge/bin" | Out-Null
    if (!$SkipTables) {
        if ($Excel2pbSource) {
            $lock = Get-Content "$PSScriptRoot/excel2pb.lock.json" -Raw | ConvertFrom-Json
            $commit = & git -C $Excel2pbSource rev-parse HEAD
            if ($LASTEXITCODE -ne 0 -or $commit.Trim() -ne $lock.commit) { throw "excel2pb source must be at $($lock.commit); current: $commit" }
            Push-Location $Excel2pbSource
            try {
                & go build -o "$root/.tools/excel2pb.exe" .
                if ($LASTEXITCODE -ne 0) { throw 'excel2pb build failed' }
            } finally { Pop-Location }
        }
        & "$PSScriptRoot/generate.ps1"
        & python "$PSScriptRoot/format_workbooks.py" "$root/table/xlsx"
        if ($LASTEXITCODE -ne 0) { throw 'Workbook formatting failed' }
    }
    & "$PSScriptRoot/generate_proto.ps1"
    Push-Location "$root/game"
    try {
        & go test -race ./...
        if ($LASTEXITCODE -ne 0) { throw 'Go authority tests failed' }
        & go build -buildmode=c-shared -o "$root/client/addons/game_bridge/bin/gamecore.dll" ./cmd/sharedlib
        if ($LASTEXITCODE -ne 0) { throw 'Go DLL build failed. Close running prototype processes before rebuilding.' }
        & go build -o "$root/build/server.exe" ./cmd/server
        if ($LASTEXITCODE -ne 0) { throw 'Go server build failed' }
    } finally { Pop-Location }
    & gcc -std=c11 -O2 -Wall -shared -static-libgcc "$root/bridge/godot/bridge.c" -o "$root/client/addons/game_bridge/bin/game_bridge.dll"
    if ($LASTEXITCODE -ne 0) { throw 'GDExtension bridge build failed; use a compiler installed in an ASCII-only path.' }
    $importLog = Join-Path $root 'build/godot-import.log'
    & $Godot --headless --path "$root/client" --editor --import --quit *> $importLog
    if ($LASTEXITCODE -ne 0 -or (Select-String -Path $importLog -Pattern 'SCRIPT ERROR:|ERROR:' -Quiet)) {
        Get-Content $importLog -Tail 60
        throw 'Godot import failed'
    }
    if ($Test) {
        $testArgs = @("$PSScriptRoot/test_integration.py", '--godot', $Godot)
        if ($Headless) { $testArgs += '--headless' }
        & python @testArgs
        if ($LASTEXITCODE -ne 0) { throw 'Integration smoke failed' }
    }
    Write-Host 'Build complete: open client/project.godot and press F6/F5; tools/run.ps1 starts the prototype.'
} finally {
    $env:PATH = $previousPath
    $env:CGO_ENABLED = $previousCgo
}
