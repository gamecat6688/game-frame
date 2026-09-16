param([switch]$Server, [string]$Godot = '')
$ErrorActionPreference = 'Stop'
$root = Split-Path $PSScriptRoot -Parent
Push-Location $root
try {
    if ($Server) {
        & "$root/build/server.exe" -listen 127.0.0.1:18080 -save "$root/runtime/server.pb"
    } else {
        if (!$Godot -and (Test-Path "$root/tools.local.json")) {
            $Godot = (Get-Content "$root/tools.local.json" -Raw | ConvertFrom-Json).godot
        }
        if (!$Godot) { $Godot = (Get-Command godot -ErrorAction Stop).Source }
        & $Godot --path "$root/client"
    }
    if ($LASTEXITCODE -ne 0) { throw 'Prototype process exited with an error' }
} finally { Pop-Location }
