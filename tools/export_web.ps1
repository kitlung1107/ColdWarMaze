param(
    [Parameter(Mandatory=$true)][string]$Godot,
    [string]$OutputDirectory = 'build/web'
)
$projectRoot = Split-Path $PSScriptRoot -Parent
$target = [System.IO.Path]::GetFullPath((Join-Path $projectRoot $OutputDirectory))
New-Item -ItemType Directory -Force -Path $target | Out-Null
& $Godot --headless --path $projectRoot --export-release Web (Join-Path $target 'index.html')
if ($LASTEXITCODE -ne 0) { throw 'Godot web export failed.' }
Copy-Item (Join-Path $projectRoot 'web/*') $target
