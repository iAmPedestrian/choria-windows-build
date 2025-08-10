param (
  [Parameter(Mandatory = $false)]
  [Alias("c")]
  [switch] $commit,

  [Parameter(Mandatory = $false)]
  [Alias("r")]
  [switch] $release,

  [Parameter(Mandatory = $false)]
  [switch] $msi
)

if (-not $commit -and -not $release) {
  Write-Error "Neither '-commit (-c)' nor '-release (-r)' switch were specified. You have to specify one or the other."
  Exit 1
}

if ($commit -and $release) {
  Write-Error "Both '-commit (-c)' and '-release (-r)' switches were specified. You can specify only one."
  Exit 1
}

$continue = $false

$api_endpoint = 'https://api.github.com/repos/choria-io/go-choria'
$gh_endpoint = 'https://www.github.com/repos/choria-io/go-choria'
$commit_endpoint = 'commits'
$release_endpoint = 'releases'

$latest_commit = (Invoke-RestMethod "$api_endpoint/$commit_endpoint")[0]
$latest_release = (Invoke-RestMethod "$api_endpoint/$release_endpoint")[0]

# Name of the main choria repository
$repoName = "go-choria"

# Comparing version and commit SHA to check if there's new version (release) and any new commit
$versions = Get-Content '.\current_build.json' | ConvertFrom-Json

if ($c -or $commit) {
  Write-Output "Finding latest commit hash"
  $hash = $latest_commit.sha.Substring(0,7)
  Write-Output "  Latest hash: $hash`n"

  Write-Output "Comparing latest commit hash"
  if ($versions.commit_sha -eq $hash) {
    Write-Output "  No new commit found. Exiting..."
    Exit 0
  }
  else {
    Write-Output "  New commit found.`n"
    $output_name = $hash
    $continue = $true
  }
}
elseif ($r -or $release) {
  Write-Output "Finding latest version"
  $version = $latest_release.name
  $version_id = $latest_release.id
  Write-Output "  Latest version: $version`n  Latest version ID: $version_id`n"

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

  # setting environment variables needed for generate
  Write-Output "`nSetting ENV variables: GOOS=windows and GOARCH=amd64`n"
  $env:GOOS = 'windows'
  $env:GOARCH = 'amd64'

  # information needed for build
  Write-Output "Gathering information for build: SHA, buildDate, JWT location"
  $SHA = git -C $repoName rev-parse --short HEAD
  $buildDate = Get-Date -Format "yyyy-MM-dd HH:mm:ss zzz"    # 2023-08-22 20:04:00 +0000
  $JWT = "C:\ProgramData\Choria\etc\provisioning.jwt"

  Write-Output "Generating 'go build' command arguments"
  $ldFlags = "github.com/choria-io/$repoName/build"
  $ldVersion = "$ldFlags.Version=$version"
  $ldSHA = "$ldFlags.SHA=$SHA"
  $ldbuildDate = "$ldFlags.BuildDate=$buildDate"
  $ldJWT = "$ldFlags.ProvisionJWTFile=$JWT"

  $outputName = "choria-$output_name-$env:GOOS-$env:GOARCH.exe"

  Write-Output "Generated output name: $outputName"

  # commands to generate plugins and build the binary
  $generate = "go generate -C $reponame --run plugin"
  $build = "go build -C $repoName -o $outputName -trimpath -buildvcs=false -ldflags=`"-X `'$ldVersion`' -X `'$ldSHA`' -X `'$ldbuildDate`' -X `'$ldJWT`'`""

  Write-Output "Generating plugins:"
  Invoke-Expression $generate

  Write-Output "Building binary:"
  Invoke-Expression $build

}

if ($msi) {
  # run MSI build
  .\msi_build.ps1
}

# if everything is OK write new versions to the json
Write-Output "Updating new versions in JSON"
$versions.version = $version
$versions.sha = $hash
$versions | ConvertTo-Json | Out-File .\current_build.json
