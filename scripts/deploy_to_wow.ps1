# deploy_to_wow.ps1
# Validates (syntax + lint + tests), then copies the addon into a local
# World of Warcraft AddOns folder.
#
# The deployed TOC gets a "-dev" suffix so local test builds don't look like
# a public release version.

[CmdletBinding()]
param(
    [string[]]$WowAddonPaths = @(
        "D:\Battle.NET\World Of Warcraft\_retail_\Interface\AddOns\TurmoilsAddon",
        "D:\Battle.NET\World Of Warcraft\_ptr_\Interface\AddOns\TurmoilsAddon"
    ),
    [switch]$NoDevSuffix,
    [switch]$ValidateOnly
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$scriptRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
$repoRoot   = Split-Path -Parent $scriptRoot
$tocPath    = Join-Path $repoRoot "TurmoilsAddon.toc"

if (-not (Test-Path -LiteralPath $tocPath -PathType Leaf)) {
    throw "Could not find TurmoilsAddon.toc at $tocPath"
}

function Get-Lua51Executable {
    $candidates = @()
    $luaCommand = Get-Command "lua.exe" -ErrorAction SilentlyContinue
    if ($luaCommand) { $candidates += $luaCommand.Source }
    if ($env:ProgramFiles) { $candidates += (Join-Path $env:ProgramFiles "Lua\5.1\lua.exe") }
    if (${env:ProgramFiles(x86)}) {
        $candidates += (Join-Path ${env:ProgramFiles(x86)} "Lua\5.1\lua.exe")
    }

    foreach ($candidate in $candidates | Select-Object -Unique) {
        if (-not (Test-Path -LiteralPath $candidate -PathType Leaf)) { continue }
        $startInfo = [System.Diagnostics.ProcessStartInfo]::new()
        $startInfo.FileName = $candidate
        $startInfo.Arguments = "-v"
        $startInfo.UseShellExecute = $false
        $startInfo.CreateNoWindow = $true
        $startInfo.RedirectStandardOutput = $true
        $startInfo.RedirectStandardError = $true

        $process = [System.Diagnostics.Process]::new()
        $process.StartInfo = $startInfo
        try {
            [void]$process.Start()
            $versionText = ($process.StandardOutput.ReadToEnd() + $process.StandardError.ReadToEnd()).Trim()
            $process.WaitForExit()
            if ($process.ExitCode -eq 0 -and $versionText -match '^Lua 5\.1(?:\.|\s)') {
                return $candidate
            }
        } finally {
            $process.Dispose()
        }
    }
    return $null
}

function Get-LuacheckExecutable {
    $candidates = @()
    $command = Get-Command "luacheck.exe" -ErrorAction SilentlyContinue
    if ($command) { $candidates += $command.Source }
    if ($env:LOCALAPPDATA) {
        $candidates += (Join-Path $env:LOCALAPPDATA "Programs\Luacheck\luacheck.exe")
    }

    foreach ($candidate in $candidates | Select-Object -Unique) {
        if (Test-Path -LiteralPath $candidate -PathType Leaf) { return $candidate }
    }
    return $null
}

function Get-ValidationLuaFiles {
    # lib/ is deliberately excluded: LibWindow-1.1.lua ships with a UTF-8 BOM
    # the WoW client tolerates but standalone luac/luacheck choke on.
    $paths = @(
        (Join-Path $repoRoot "TurmoilsAddon.lua"),
        (Join-Path $repoRoot "constants"),
        (Join-Path $repoRoot "core"),
        (Join-Path $repoRoot "features"),
        (Join-Path $repoRoot "tests")
    )
    foreach ($path in $paths) {
        if (Test-Path -LiteralPath $path -PathType Leaf) {
            Get-Item -LiteralPath $path
        } elseif (Test-Path -LiteralPath $path -PathType Container) {
            Get-ChildItem -LiteralPath $path -Recurse -File -Filter "*.lua"
        }
    }
}

function Invoke-AddonValidation {
    $luaExecutable = Get-Lua51Executable
    if (-not $luaExecutable) {
        throw "Lua 5.1 is required for local deployment. Install it before deploying."
    }
    $luacExecutable = Join-Path (Split-Path -Parent $luaExecutable) "luac.exe"
    if (-not (Test-Path -LiteralPath $luacExecutable -PathType Leaf)) {
        throw "Lua 5.1 compiler not found beside $luaExecutable."
    }
    $luacheckExecutable = Get-LuacheckExecutable
    if (-not $luacheckExecutable) {
        throw "Luacheck is required for local deployment. Install it before deploying."
    }

    Write-Host "Running local Lua validation..."
    Push-Location $repoRoot
    try {
        foreach ($luaFile in Get-ValidationLuaFiles) {
            & $luacExecutable -p $luaFile.FullName
            if ($LASTEXITCODE -ne 0) {
                throw "Lua syntax validation failed for $($luaFile.FullName)."
            }
        }

        & $luacheckExecutable "TurmoilsAddon.lua" "constants" "core" "features" "tests"
        if ($LASTEXITCODE -ne 0) {
            throw "Luacheck failed with exit code $LASTEXITCODE. Deployment aborted."
        }

        & $luaExecutable "tests/run.lua"
        if ($LASTEXITCODE -ne 0) {
            throw "Addon tests failed with exit code $LASTEXITCODE. Deployment aborted."
        }
    } finally {
        Pop-Location
    }
    Write-Host "Lua syntax, lint, and tests passed." -ForegroundColor Green
    Write-Host ""
}

function Get-TocAddonFiles {
    param([string]$Path)

    Get-Content -LiteralPath $Path |
        ForEach-Object { $_.Trim() } |
        Where-Object {
            $_ -and
            -not $_.StartsWith("#") -and
            -not $_.StartsWith("##")
        } |
        ForEach-Object { $_ -replace '/', '\' }
}

function Copy-RepoFile {
    param(
        [string]$RelativePath,
        [string]$DestinationRoot
    )

    $src = Join-Path $repoRoot $RelativePath
    if (-not (Test-Path -LiteralPath $src -PathType Leaf)) {
        Write-Warning "Skipping missing TOC entry: $RelativePath"
        return
    }

    $dest = Join-Path $DestinationRoot $RelativePath
    $destDir = Split-Path -Parent $dest
    if (-not (Test-Path -LiteralPath $destDir -PathType Container)) {
        New-Item -ItemType Directory -Path $destDir -Force | Out-Null
    }

    Copy-Item -LiteralPath $src -Destination $dest -Force
}

Invoke-AddonValidation
if ($ValidateOnly) { return }

foreach ($wowAddonPath in $WowAddonPaths) {
    $rootAddonsDir = Split-Path -Parent $wowAddonPath
    if (-not (Test-Path -LiteralPath $rootAddonsDir -PathType Container)) {
        Write-Host "  [skip] $rootAddonsDir not found"
        continue
    }

    if (-not (Test-Path -LiteralPath $wowAddonPath -PathType Container)) {
        New-Item -ItemType Directory -Path $wowAddonPath -Force | Out-Null
    }

    Write-Host "Deploying TurmoilsAddon to:"
    Write-Host "  $wowAddonPath"

    Copy-RepoFile -RelativePath "TurmoilsAddon.toc" -DestinationRoot $wowAddonPath
    foreach ($relativePath in Get-TocAddonFiles -Path $tocPath) {
        Copy-RepoFile -RelativePath $relativePath -DestinationRoot $wowAddonPath
    }

    if (-not $NoDevSuffix) {
        $destToc = Join-Path $wowAddonPath "TurmoilsAddon.toc"
        $tocText = Get-Content -Raw -LiteralPath $destToc
        $updated = $tocText -replace '(?m)^(##\s*Version:\s*)([^\r\n]+?)(-dev)?\s*$', '$1$2-dev'
        Set-Content -LiteralPath $destToc -Value $updated -NoNewline -Encoding UTF8
    }

    Write-Host "Deploy complete." -ForegroundColor Green
}
