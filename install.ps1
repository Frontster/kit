<#
  Frontster toolkit bootstrap.

  What it does, in order:
    1. Installs the .NET SDK and the GitHub CLI with winget if they are missing.
    2. Signs in to GitHub with a device code (approve it on your phone or in a browser).
    3. Installs the `kit` launcher from the private package feed, using the token gh just made.
    4. Hands over to `kit hello`, which sets up the home base and the rest.

  Nothing in this file is secret and it needs no secret to start. The only credential involved is
  the one you create yourself by approving the device code, and it is kept by gh, never written to
  a file by this script.

  Run:   irm https://raw.githubusercontent.com/Frontster/kit/main/install.ps1 | iex
  Pin:   irm https://raw.githubusercontent.com/Frontster/kit/<commit>/install.ps1 | iex
#>

$ErrorActionPreference = 'Stop'

$owner = 'Frontster'
$feed = "https://nuget.pkg.github.com/$owner/index.json"
$package = 'Toolkit.Kit'

function Test-Command([string] $name) {
    [bool] (Get-Command $name -ErrorAction SilentlyContinue)
}

function Refresh-Path {
    $env:Path = [Environment]::GetEnvironmentVariable('Path', 'Machine') + ';' + [Environment]::GetEnvironmentVariable('Path', 'User')
}

function Install-WithWinget([string] $id, [string] $name) {
    if (-not (Test-Command winget)) {
        throw "winget is not available. Install 'App Installer' from the Microsoft Store, then run this again."
    }
    Write-Host "Installing $name..."
    winget install --id $id --exact --silent --accept-package-agreements --accept-source-agreements
    Refresh-Path
}

if (-not (Test-Command dotnet)) { Install-WithWinget 'Microsoft.DotNet.SDK.9' '.NET SDK 9' }
if (-not (Test-Command gh))     { Install-WithWinget 'GitHub.cli' 'GitHub CLI' }

$status = (gh auth status -h github.com 2>&1) | Out-String
if ($status -notmatch 'Logged in to github.com') {
    Write-Host 'Sign in to GitHub: copy the one-time code and approve it in the browser.'
    gh auth login -h github.com -p https --web --scopes read:packages
}
elseif ($status -notmatch 'read:packages|write:packages') {
    Write-Host 'Adding the read:packages scope to the GitHub sign-in...'
    gh auth refresh -h github.com -s read:packages
}

$token = (gh auth token -h github.com).Trim()
if (-not $token) { throw 'gh did not produce a token; the sign-in did not complete.' }

# The feed is described in a throwaway config so nothing on the machine changes before `kit hello`
# asks. The token reaches NuGet through the environment, not through the file.
$config = Join-Path ([IO.Path]::GetTempPath()) "kit-install-$([guid]::NewGuid().ToString('N')).config"
@"
<?xml version="1.0" encoding="utf-8"?>
<configuration>
  <packageSources>
    <clear />
    <add key="github" value="$feed" />
    <add key="nuget.org" value="https://api.nuget.org/v3/index.json" />
  </packageSources>
  <packageSourceCredentials>
    <github>
      <add key="Username" value="$owner" />
      <add key="ClearTextPassword" value="%KIT_NUGET_TOKEN%" />
    </github>
  </packageSourceCredentials>
  <packageSourceMapping>
    <packageSource key="github">
      <package pattern="Toolkit.*" />
    </packageSource>
    <packageSource key="nuget.org">
      <package pattern="*" />
    </packageSource>
  </packageSourceMapping>
</configuration>
"@ | Set-Content $config

$env:KIT_NUGET_TOKEN = $token
try {
    $installed = (dotnet tool list -g --format json | ConvertFrom-Json).data | Where-Object packageId -eq $package.ToLowerInvariant()
    $verb = if ($installed) { 'update' } else { 'install' }
    Write-Host "Running dotnet tool $verb -g $package..."
    dotnet tool $verb -g $package --configfile $config
    if ($LASTEXITCODE) { throw "dotnet tool $verb $package failed." }
}
finally {
    Remove-Item $config -Force -ErrorAction SilentlyContinue
}

$toolsDir = Join-Path $HOME '.dotnet\tools'
if (($env:Path -split ';') -notcontains $toolsDir) { $env:Path = "$toolsDir;$env:Path" }

kit hello
