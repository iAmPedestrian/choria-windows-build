# choria-windows-build
[Choria](https://github.com/choria-io) is an open-source orchestrator tool for Puppet. The code provides the means to create the binary for Windows, however, it is not provided anymore with new releases. It uses Docker and Ruby/Rake, but in some cases and some enterprise environments, it is not possible to use them.

For those who can't use Docker to create the Windows binary and MSI, I've created a PowerShell script to create the binary from the source code and the MSI for easier distribution and installation.

## Prerequisites
For a successful build, you need to have these tools installed:

- GoLang - to build the binary
- WixTools - to build the MSI, tested on version `3.11.2.4516`

## Execution
The current version and latest commit hash are stored in the `current_build.json`, which are used to determine if there is any new version.

`binary_build.ps1`
1. Check for the version and latest commit hash if there's a new version to build
2. Clone the repository if a new version or commit is found
3. Set environment variables `GOOS=windows` and `GOARCH=amd64`
4. Create variables and arguments for the correct build
5. Run `go generate --run plugin` to auto-generate plugins needed for the build
6. Run `go build` with variables and arguments to build the binary
7. Call `msi_build.ps1`

> `msi_build.ps1`
> 1. Create a new directory and copy the created binary and template files (from the original repo) for the MSI build to that directory
> 2. Replace the placeholders for the name, version, etc., in the XML used to create the MSI (choria.wxs)
> 3. Replace the placeholders in the `package.bat` file, which is used to call WIX executables to create MSI
> 4. Call the `package.bat` file to create the MSI

8. Update `current_build.json` with the new version and hash found
