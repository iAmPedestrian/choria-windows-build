param (
  [Parameter(Mandatory = $false)]
  [Alias('c')]
  [switch] $commit,

  [Parameter(Mandatory = $false)]
  [Alias('r')]
  [switch] $release,

  [Parameter(Mandatory = $false)]
  [switch] $msi,

  [Parameter(Mandatory = $false)]
  [Alias('h')]
  [switch] $help
)


# running on windows, wsl, or something else?

Function Show-Help {
  Write-Output "Usage: choria-build.ps1 [-commit | -c] [-release | -r] [-msi] [-help | -h]`n"
  Write-Output "Build the binary, and optionally the MSI installer, of the Choria Orchestrator for Windows OS."
  Write-Output ""
  Write-Output "List of options:"
  Write-Output "  -c, -commit    look for the latest commit as a source of the build; can't be used with '-r'"
  Write-Output "  -r, -release   look for the latest release as a source of the build; can't be used with '-c'"
  Write-Output "  -msi           whether build also MSI installer with WIX toolset"
  Write-Output "  -h, -help      show this help info"
  Write-Output ""
}


Function Build-Binary {
  $continue = $false

  $api_endpoint = 'https://api.github.com/repos/choria-io/go-choria'
  $gh_endpoint = 'https://www.github.com/repos/choria-io/go-choria'
  $commit_endpoint = 'commits'
  $release_endpoint = 'releases'

  $latest_commit = (Invoke-RestMethod "$api_endpoint/$commit_endpoint")[0]
  $latest_release = (Invoke-RestMethod "$api_endpoint/$release_endpoint")[0]
  $commit_hash = $latest_commit.sha
  $commit_hash_short = $commit_hash.Substring(0,7)
  $commit_date = (Invoke-RestMethod "$api_endpoint/$commit_endpoint/$commit_hash").commit.author.date
  $version = $latest_release.name
  $version_id = $latest_release.id
  $version_date = $latest_release.published_at

  Write-Output "Information about Choria Repo:"
  Write-Output "  Latest commit: $commit_hash_short"
  Write-Output "  Latest commit date: $commit_date"
  Write-Output "  Latest release: $version"
  Write-Output "  Latest release ID: $version_id"
  Write-Output "  Latest release date: $version_date"

  # Name of the main choria repository
  $repoName = "go-choria"

  # Comparing version and commit SHA to check if there's new version (release) and any new commit
  $versions = Get-Content '.\current_build.json' | ConvertFrom-Json

  if ($c -or $commit) {
    Write-Output "Comparing latest commit hash"
    if ($versions.commit_sha -eq $commit_hash_short) {
      Write-Output "  No new commit found. Exiting..."
      Exit 0
    }
    else {
      Write-Output "  New commit found.`n"
      $output_name = $commit_hash_short
      $continue = $true
    }
  }
  elseif ($r -or $release) {
    Write-Output "Comparing latest version"
    if ($versions.release.id -eq $version_id -and $versions.release.name -eq $version) {
      Write-Output "  No new version found. Exiting..."
      Exit 0
    }
    else {
      Write-Output "  New version found.`n"
      $output_name = $version
      $continue = $true
    }
  }

  if ($continue) {

    if (Test-Path $repoName) {
      Write-Output "Found old repository folder. Deleting...`n"
      Remove-Item $repoName -Recurse -Force
    }

    # commands for cloning choria repo
    $clone = "git clone https://github.com/choria-io/$repoName.git"

    Write-Output "Cloning repository`n"
    Invoke-Expression $clone

    # information needed for build
    Write-Output "Gathering information for build: SHA, buildDate, JWT location"
    $SHA = $commit_hash
    $buildDate = Get-Date -Format "yyyy-MM-dd HH:mm:ss zzz"    # 2023-08-22 20:04:00 +0000
    $JWT = "C:\ProgramData\Choria\etc\provisioning.jwt"

    Write-Output "Generating 'go build' command arguments"
    $ldFlags = "github.com/choria-io/$repoName/build"
    $ldVersion = "$ldFlags.Version=$version"
    $ldSHA = "$ldFlags.SHA=$SHA"
    $ldbuildDate = "$ldFlags.BuildDate=$buildDate"
    $ldJWT = "$ldFlags.ProvisionJWTFile=$JWT"

    # commands to generate plugins and build the binary
    $generate = "go generate -C $reponame --run plugin"
    $build = "go build -C $repoName -o $outputName -trimpath -buildvcs=false -ldflags=`"-X `'$ldVersion`' -X `'$ldSHA`' -X `'$ldbuildDate`' -X `'$ldJWT`'`""

    Write-Output "Generating plugins:"
    Invoke-Expression $generate

    # setting environment variables needed for generate
    Write-Output "`nSetting ENV variables: GOOS=windows and GOARCH=amd64`n"
    $env:GOOS = 'windows'
    $env:GOARCH = 'amd64'

    $outputName = "choria-$output_name-$env:GOOS-$env:GOARCH.exe"
    Write-Output "Generated output name: $outputName"

    Write-Output "Building binary:"
    Write-Output "Build commmand: $build"
    Invoke-Expression $build

  }

  # most probable check for running in WSL
  if (Test-Path "/proc/sys/fs/binfmt_misc/WSLInterop") {
    $wsl = $true
  }
  else {
    $wsl = $false
  }

  # check if WSL interop is enabled to be able to communicate with Windows filesystem
  if ($wsl) {
    if ($null -eq $env:WSL_INTEROP) {
      $interop = $false
    }
    else {
      $interop = $true
    }
  }

  if ($msi -and $wsl -and $interop) {
    Write-Warning "You are running in WSL, and want to build the MSI. This is not fully supported"
    # run MSI build
    .\msi_build.ps1
  }
  elseif ($msi -and (-not $wsl -or -not $interop)) {

  }
  # if everything is OK write new versions to the json
  Write-Output "Updating new versions in JSON"
  if ($r -or $release) {
    $versions.release.name = $version
    $versions.release.id = $version_id
  }
  elseif ($c -or $commit) {
    $versions.commit_sha = $commit_hash_short
  }
  $versions | ConvertTo-Json | Out-File .\current_build.json

}

if ($help) {
  Show-Help
  Exit 0
}
else {
  if (-not $commit -and -not $release) {
    Write-Error "Neither '-commit (-c)' nor '-release (-r)' switch were specified.`n`n"
    Show-Help
    Exit 1
  }
  elseif ($commit -and $release) {
    Write-Error "Both '-commit (-c)' and '-release (-r)' switches were specified. You can specify only one.`n`n"
    Show-Help
    Exit 1
  }
  Build-Binary
  if ($msi) {
    Build-Installer
  }
}
