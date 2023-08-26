# choria-windows-build

For anyone who can't use Docker to create the Windows Choria binary and MSI. Choria maintainer doesn't provide the Windows binaries and MSIs for any new version, so I've created the PowerShell script that doesn't use Docker and Ruby/Rake to build the binary.

## Prerequisites

For a successful build, you need to have these tools installed:

- Git - to clone the repo
- GoLang - to build the binary
- WixTools - to build the MSI

## Execution

Current version and latest commit hash are stored in the `current_build.json`, which are used to determine if there is any new version.

`binary_build.ps1`

1. Check for the version and latest commit hash if there's a new version to build
2. If found repository is cloned.
3. Set environment variables `GOOS=windows` and `GOARCH=amd64` that **Go** is using during the steps
4. Create variables and arguments for the correct build
5. Run `go generate --run plugin` to auto-generate plugins needed for build
6. Run `go build` with variables and arguments
7. Call `msi_build.ps1`

> `msi_build.ps1`
>
> 1. Create new directory and copy created binary and template files (from the original repo) for the MSI build, to that directory
> 2. Replace the placeholders of the name, version, etc., in XML used to create the MSI (*.wxs)
> 3. Replace the placeholders in the `.bat` file which is used to call WIX executables to create MSI
> 4. Call the `.bat` file to create the MSI

8. Update `current_build.json` with the new version and hash found
