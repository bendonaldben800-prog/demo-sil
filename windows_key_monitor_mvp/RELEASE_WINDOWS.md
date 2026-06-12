# Windows Release Flow

This project includes a GitHub Actions workflow that builds Windows artifacts for x64 and ARM64.

Workflow file:
- .github/workflows/windows-artifacts.yml

## What it produces

For each architecture:
- Portable bundle: key-monitor-win-x64.zip or key-monitor-win-arm64.zip
- Installer: key-monitor-win-x64-setup.exe or key-monitor-win-arm64-setup.exe
- SHA256 files for both bundles and installers

## How to run

1. Push your changes to GitHub.
2. Open Actions and run Build Windows Artifacts manually.
3. Optionally provide a release tag value (example: v0.1.0) to generate URL hints.

## Manual RDP / Windows machine flow

If you have access to a Windows machine over RDP, you can build the release files without GitHub.

1. Copy the folder [windows_key_monitor_mvp](windows_key_monitor_mvp) to the Windows machine.
2. Install the .NET 8 SDK.
3. Install Inno Setup 6 (only required when building installers).
   - Example: `choco install innosetup -y`
4. Open PowerShell in the copied [windows_key_monitor_mvp](windows_key_monitor_mvp) folder.
5. Run:

```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\build-release-artifacts.ps1 -BuildInstaller
```

The script produces these files in `artifacts\dist`:

- `key-monitor-win-x64.zip`
- `key-monitor-win-x64.zip.sha256.txt`
- `key-monitor-win-x64-setup.exe`
- `key-monitor-win-x64-setup.exe.sha256.txt`
- `key-monitor-win-arm64.zip`
- `key-monitor-win-arm64.zip.sha256.txt`
- `key-monitor-win-arm64-setup.exe`
- `key-monitor-win-arm64-setup.exe.sha256.txt`

## Recommended publish flow

1. Create and publish a GitHub Release with tag like v0.1.0.
2. The workflow uploads build artifacts to that release.
3. Copy resulting URLs into download_portal/manifest.json:
   - windows-x64 url
   - windows-arm64 url
4. Copy SHA256 values from .sha256.txt files into checksum fields.
5. Prefer setup `.exe` URLs for end users. Keep `.zip` for portable/debug distribution.

## URL format

When using GitHub Releases, URLs normally look like this:

https://github.com/OWNER/REPO/releases/download/v0.1.0/key-monitor-win-x64-setup.exe
https://github.com/OWNER/REPO/releases/download/v0.1.0/key-monitor-win-arm64-setup.exe
