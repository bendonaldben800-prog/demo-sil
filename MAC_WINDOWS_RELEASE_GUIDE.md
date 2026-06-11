# Mac-first Windows Release Guide

This guide lets you produce Windows download files while working from macOS.

## What is already in this repo

- Windows build workflow: [.github/workflows/windows-artifacts.yml](.github/workflows/windows-artifacts.yml)
- Website manifest to update: [download_portal/manifest.json](download_portal/manifest.json)
- Windows release notes: [windows_key_monitor_mvp/RELEASE_WINDOWS.md](windows_key_monitor_mvp/RELEASE_WINDOWS.md)

## Current blocker on this machine

This workspace is currently not a git repository, and GitHub CLI is not installed.

## Path A: No CLI (works with browser only)

1. Create a new GitHub repo in the browser.
2. In this folder, initialize git and push:

```bash
git init
git add .
git commit -m "Initial cross-platform monitor + windows workflow"
git branch -M main
git remote add origin https://github.com/OWNER/REPO.git
git push -u origin main
```

3. In GitHub, open Actions and run workflow Build Windows Artifacts.
4. Create and publish a release tag such as v0.1.0.
5. Re-run the same workflow or publish release again to attach assets.
6. Download the four files from release assets:
   - key-monitor-win-x64.zip
   - key-monitor-win-x64.zip.sha256.txt
   - key-monitor-win-arm64.zip
   - key-monitor-win-arm64.zip.sha256.txt

## Path B: With GitHub CLI on macOS

1. Install GitHub CLI:

```bash
brew install gh
gh auth login
```

2. Create repo and push:

```bash
git init
git add .
git commit -m "Initial cross-platform monitor + windows workflow"
git branch -M main
gh repo create OWNER/REPO --public --source . --remote origin --push
```

3. Create release from macOS:

```bash
gh release create v0.1.0 --title "v0.1.0" --notes "Windows artifacts release"
```

4. Trigger workflow manually:

```bash
gh workflow run windows-artifacts.yml -f release_tag=v0.1.0
```

5. Monitor run:

```bash
gh run list --workflow windows-artifacts.yml
gh run view --log
```

## Update download manifest

1. Generate URLs with helper script:

```bash
bash scripts/macos/windows_release_urls.sh OWNER REPO v0.1.0
```

2. Read downloaded checksum files:

```bash
bash scripts/macos/read_windows_checksums.sh ~/Downloads/windows-assets
```

3. Paste URLs and checksums into [download_portal/manifest.json](download_portal/manifest.json).

## Notes

- You do not need a local Windows machine to build the Windows files if GitHub Actions is used.
- You should still test runtime behavior on a real Windows machine before production rollout.
