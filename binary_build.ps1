# Name of the main choria repository
$repoName = "go-choria"

If (Test-Path $repoName) {
    Write-Output "Found old repository folder. Deleting...`n"
    Remove-Item $repoName -Recurse -Force
}

Write-Output "Finding latest version"
$versionLink = "https://github.com/choria-io/$repoName/releases/latest"
$vResponse = Invoke-Webrequest -Uri $versionLink -UseBasicParsing
$vRegex = '<title>.*v(?<version>.*?)\s.*</title>'
if ($vResponse -match $vRegex) {
    $version = $matches['version']
}
Write-Output "  Version found: $version"

Write-Output "`nFinding latest commit hash"
$hashLink = "https://github.com/choria-io/go-choria/commits/main"
$hResponse = Invoke-Webrequest -Uri $hashLink -UseBasicParsing
$hRegex = 'href="/choria-io/go-choria/commit.*/(?<hash>.*?)" class'
if ($hResponse -match $hRegex) {
    $hash = $matches['hash'].Substring(0,7)
}
Write-Output "  Hash found: $hash"

# Comparing version and commit SHA to check if there's new version (release) and any new commit
Write-Output "`nComparing version and latest commit hash"
$versions = Get-Content '.\current_build.json' | ConvertFrom-Json

if ($versions.version -eq $version -and $versions.sha -eq $hash) {
    Write-Output "  No new version or commit (GH:$version => C:$($versions.version)) or commit (GH: $hash => C:$($versions.sha)). Exiting..."
    Exit 0
}
else {
    Write-Output "  Found new version (GH:$version => C:$($versions.version)) or commit (GH:$hash => C:$($versions.sha))"
}

# commands for cloning choria repo
$clone = "git clone https://github.com/choria-io/$repoName.git"

Write-Output "`nCloning repository"
Invoke-Expression $clone

# setting environment variables needed for generate
Write-Output "`nSetting ENV variables: GOOS=windows and GOARCH=amd64"
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

$outputName = "choria-$version-$env:GOOS-$env:GOARCH.exe"

Write-Output "`nGenerated output name: $outputName"

# commands to generate plugins and build the binary
$generate = "go generate -C $repoName --run plugin"
$build = "go build -C $repoName -o $outputName -trimpath -buildvcs=false -ldflags=`"-X `'$ldVersion`' -X `'$ldSHA`' -X `'$ldbuildDate`' -X `'$ldJWT`'`""

Write-Output "`nGenerating plugins:"
Invoke-Expression $generate

Write-Output "`nBuilding binary: (command: $build)"
Invoke-Expression $build

# run MSI build
.\msi_build.ps1

# if everything is OK write new versions to the json
Write-Output "Updating new versions in JSON"
$versions.version = $version
$versions.sha = $hash
$versions | ConvertTo-Json | Out-File .\current_build.json