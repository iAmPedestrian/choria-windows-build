Write-Output "`nBuilding MSI"

# Directory for the MSI build
$msiFolder = "msibuild"
If (Test-Path $msiFolder) {
    Write-Output "Found old MSI build folder. Deleting...`n"
    Remove-Item $msiFolder -Recurse -Force
}

Write-Output "`nCreating '$msiFolder' directory"
New-Item -Name $msiFolder -ItemType Directory | Out-Null

Write-Output "Move created binary '$outputName' to '$msiFolder' directory"
Move-Item -Path "$repoName\*.exe" -Destination $msiFolder

Write-Output "Copy packager template to '$msiFolder' directory"
Copy-Item -Path "$repoName\packager\templates\windows\global\*" -Destination $msiFolder -Recurse

Set-Location $msiFolder

Write-Output "`nReplacing placeholders for WIX"
$cpkg_display_name = 'Choria Orchestrator'
$cpkg_name = 'Choria'
$cpkg_version = $version
$cpkg_bindir = 'bin'
$cpkg_etcdir = 'etc'
$cpkg_binary = $outputName

Write-Output "  Replacing in choria.wxs"
$xmlFile = (Get-Content ".\choria.wxs")
$xmlFile = $xmlFile.Replace("{{cpkg_display_name}}",$cpkg_display_name)
$xmlFile = $xmlFile.Replace("{{cpkg_name}}",$cpkg_name)
$xmlFile = $xmlFile.Replace("{{cpkg_version}}",$cpkg_version)
$xmlFile = $xmlFile.Replace("{{cpkg_bindir}}",$cpkg_bindir)
$xmlFile = $xmlFile.Replace("{{cpkg_etcdir}}",$cpkg_etcdir)
$xmlFile = $xmlFile.Replace("{{cpkg_binary}}",$cpkg_binary)

Set-Content ".\choria.wxs" $xmlFile

Write-Output "  Replacing in package.bat"
$batFile = (Get-Content ".\package.bat")
$batFile = $batFile.Replace("{{cpkg_name}}",$cpkg_name)
$batFile = $batFile.Replace("{{cpkg_version}}",$cpkg_version)

Set-Content ".\package.bat" $batFile

Write-Output "`nCreating MSI"
$msi = ".\package.bat"
Invoke-Expression $msi

Set-Location ..