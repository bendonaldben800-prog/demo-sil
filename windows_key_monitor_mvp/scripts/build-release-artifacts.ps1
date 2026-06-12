param(
    [string]$Configuration = "Release",
    [string]$AppName = "key-monitor",
    [string[]]$Runtimes = @("win-x64", "win-arm64"),
    [switch]$BuildInstaller,
    [string]$MainExeName = "windows_key_monitor_mvp.exe",
    [string]$AppVersion = "0.1.0"
)

$ErrorActionPreference = "Stop"

$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$projectRoot = Split-Path -Parent $scriptDir
$projectFile = Join-Path $projectRoot "windows_key_monitor_mvp.csproj"
$artifactsRoot = Join-Path $projectRoot "artifacts"
$distRoot = Join-Path $artifactsRoot "dist"
$installerScript = Join-Path $projectRoot "scripts\\installer\\windows-installer.iss"
$innoCompiler = "C:\\Program Files (x86)\\Inno Setup 6\\ISCC.exe"

if (-not (Get-Command dotnet -ErrorAction SilentlyContinue)) {
    throw ".NET SDK was not found. Install .NET 8 SDK first."
}

if (-not (Test-Path $projectFile)) {
    throw "Could not find project file at $projectFile"
}

if ($BuildInstaller) {
    if (-not (Test-Path $installerScript)) {
        throw "Installer script not found at $installerScript"
    }

    if (-not (Test-Path $innoCompiler)) {
        throw "Inno Setup was not found at $innoCompiler. Install Inno Setup 6 or run without -BuildInstaller."
    }
}

Write-Host "Restoring project..." -ForegroundColor Cyan
dotnet restore $projectFile

New-Item -ItemType Directory -Force -Path $artifactsRoot | Out-Null
New-Item -ItemType Directory -Force -Path $distRoot | Out-Null

foreach ($runtime in $Runtimes) {
    $publishDir = Join-Path $artifactsRoot $runtime
    $zipPath = Join-Path $distRoot "$AppName-$runtime.zip"
    $hashPath = "$zipPath.sha256.txt"
    $setupName = "$AppName-$runtime-setup.exe"
    $setupPath = Join-Path $distRoot $setupName
    $setupHashPath = "$setupPath.sha256.txt"

    if (Test-Path $publishDir) {
        Remove-Item -Recurse -Force $publishDir
    }

    if (Test-Path $zipPath) {
        Remove-Item -Force $zipPath
    }

    if (Test-Path $hashPath) {
        Remove-Item -Force $hashPath
    }

    if (Test-Path $setupPath) {
        Remove-Item -Force $setupPath
    }

    if (Test-Path $setupHashPath) {
        Remove-Item -Force $setupHashPath
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

    if ($BuildInstaller) {
        Write-Host "Building installer $setupName..." -ForegroundColor Cyan
        & $innoCompiler `
            "/DAppName=$AppName" `
            "/DAppVersion=$AppVersion" `
            "/DMainExeName=$MainExeName" `
            "/DArch=$runtime" `
            "/DSourceDir=$publishDir" `
            "/DOutputDir=$distRoot" `
            "/DOutputBaseFilename=$AppName-$runtime-setup" `
            $installerScript

        if ($LASTEXITCODE -ne 0) {
            throw "Inno Setup failed for runtime $runtime"
        }

        $setupHash = (Get-FileHash $setupPath -Algorithm SHA256).Hash.ToLower()
        "$setupHash  $setupName" | Set-Content -Path $setupHashPath -NoNewline
    }
}

Write-Host ""
Write-Host "Done. Release artifacts:" -ForegroundColor Green
Get-ChildItem $distRoot | Select-Object Name, Length, LastWriteTime
