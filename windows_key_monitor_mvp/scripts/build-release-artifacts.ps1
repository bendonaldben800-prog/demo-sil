param(
    [string]$Configuration = "Release",
    [string]$AppName = "key-monitor",
    [string[]]$Runtimes = @("win-x64", "win-arm64")
)

$ErrorActionPreference = "Stop"

$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$projectRoot = Split-Path -Parent $scriptDir
$projectFile = Join-Path $projectRoot "windows_key_monitor_mvp.csproj"
$artifactsRoot = Join-Path $projectRoot "artifacts"
$distRoot = Join-Path $artifactsRoot "dist"

if (-not (Get-Command dotnet -ErrorAction SilentlyContinue)) {
    throw ".NET SDK was not found. Install .NET 8 SDK first."
}

if (-not (Test-Path $projectFile)) {
    throw "Could not find project file at $projectFile"
}

Write-Host "Restoring project..." -ForegroundColor Cyan
dotnet restore $projectFile

New-Item -ItemType Directory -Force -Path $artifactsRoot | Out-Null
New-Item -ItemType Directory -Force -Path $distRoot | Out-Null

foreach ($runtime in $Runtimes) {
    $publishDir = Join-Path $artifactsRoot $runtime
    $zipPath = Join-Path $distRoot "$AppName-$runtime.zip"
    $hashPath = "$zipPath.sha256.txt"

    if (Test-Path $publishDir) {
        Remove-Item -Recurse -Force $publishDir
    }

    if (Test-Path $zipPath) {
        Remove-Item -Force $zipPath
    }

    if (Test-Path $hashPath) {
        Remove-Item -Force $hashPath
    }

    Write-Host "Publishing $runtime..." -ForegroundColor Cyan
    dotnet publish $projectFile `
        -c $Configuration `
        -r $runtime `
        --self-contained true `
        -p:PublishSingleFile=true `
        -o $publishDir

    Write-Host "Creating archive $zipPath..." -ForegroundColor Cyan
    Compress-Archive -Path (Join-Path $publishDir "*") -DestinationPath $zipPath -Force

    $hash = (Get-FileHash $zipPath -Algorithm SHA256).Hash.ToLower()
    "$hash  $(Split-Path -Leaf $zipPath)" | Set-Content -Path $hashPath -NoNewline
}

Write-Host ""
Write-Host "Done. Release artifacts:" -ForegroundColor Green
Get-ChildItem $distRoot | Select-Object Name, Length, LastWriteTime