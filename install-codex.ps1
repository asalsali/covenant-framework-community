# Copyright (c) 2026 Alex Salsali (d/b/a Covenant Foundation)
# Licensed under the Covenant Public License v1.0
# See LICENSE for details

[CmdletBinding()]
param(
    [string]$Repo = "https://github.com/asalsali/covenant-framework.git"
)

$ErrorActionPreference = "Stop"

Write-Host ""
Write-Host "  COVENANT FRAMEWORK - Codex adapter installation"
Write-Host "  ================================================="
Write-Host ""

$tmp = Join-Path ([System.IO.Path]::GetTempPath()) ("covenant-" + [System.Guid]::NewGuid().ToString("N"))
$source = Join-Path $tmp "covenant"

try {
    git clone --depth 1 --quiet $Repo $source

    $items = @(
        "AGENTS.md",
        ".codex",
        ".agents/skills",
        "CLAUDE.md",
        "core",
        "registry",
        "memory"
    )

    foreach ($item in $items) {
        $src = Join-Path $source $item
        $dst = Join-Path (Get-Location) $item
        if (-not (Test-Path $src)) {
            continue
        }

        if (Test-Path $dst) {
            Write-Host "  !  $item exists - leaving it unchanged"
            continue
        }

        $parent = Split-Path $dst -Parent
        if ($parent -and -not (Test-Path $parent)) {
            New-Item -ItemType Directory -Force -Path $parent | Out-Null
        }
        Copy-Item -Recurse -Force $src $dst
        Write-Host "  +  installed $item"
    }

    Write-Host ""
    Write-Host "  Installation complete."
    Write-Host "  Run: codex -C $(Get-Location)"
    Write-Host ""
}
finally {
    if (Test-Path $tmp) {
        Remove-Item -Recurse -Force $tmp
    }
}
