<#

.SYNOPSIS
This is a Powershell script to bootstrap a Cake build.

.DESCRIPTION
This Powershell script will download NuGet if missing, restore NuGet tools (including Cake)
and execute your Cake build script with the parameters you provide.

.PARAMETER Script
The build script to execute.
.PARAMETER Target
The build script target to run.
.PARAMETER Configuration
The build configuration to use.
.PARAMETER Verbosity
Specifies the amount of information to be displayed.
.PARAMETER Experimental
Tells Cake to use the latest Roslyn release.
.PARAMETER WhatIf
Performs a dry run of the build script.
No tasks will be executed.
.PARAMETER Mono
Tells Cake to use the Mono scripting engine.

.LINK
http://cakebuild.net
#>

Param(
	[switch]$IsBuildServer,
    [string]$Script = "build.cake",
    [string]$Target = "Default",
    [string]$Configuration = "Release",
    [ValidateSet("Quiet", "Minimal", "Normal", "Verbose", "Diagnostic")]
    [string]$Verbosity = "Verbose",
    [switch]$Experimental,
    [Alias("DryRun","Noop")]
    [switch]$WhatIf,
    [switch]$Mono,
    [switch]$SkipToolPackageRestore,
	[string]$FileForVersion,
	[string]$DockerHost,
	[Parameter(ValueFromRemainingArguments = $true)]
    [string[]]$ScriptArgs
)

Write-Host "Preparing to run build script..."

# Should we show verbose messages?
if($Verbose.IsPresent)
{
    $VerbosePreference = "continue"
}

$DOTNET_DOWNLOAD_URL = "https://go.microsoft.com/fwlink/?LinkID=798402"
$TOOLS_DIR = Join-Path $PSScriptRoot "tools"
$NUGET_EXE = Join-Path $TOOLS_DIR "nuget.exe"
$NUGET_SOURCE = "https://api.nuget.org/v3/index.json"
$PACKAGES_CONFIG = Join-Path $TOOLS_DIR "packages.config"
$NUGET_URL = "https://dist.nuget.org/win-x86-commandline/latest/nuget.exe"


$CAKE_EXE = Join-Path $TOOLS_DIR "Cake.CoreCLR/Cake.dll"


# Should we use mono?
$UseMono = "";
if($Mono.IsPresent) {
    Write-Verbose -Message "Using the Mono based scripting engine."
    $UseMono = "-mono"
}

# Should we use the new Roslyn?
$UseExperimental = "";
if($Experimental.IsPresent -and !($Mono.IsPresent)) {
    Write-Verbose -Message "Using experimental version of Roslyn."
    $UseExperimental = "-experimental"
}

# Is this a dry run?
$UseDryRun = "";
if($WhatIf.IsPresent) {
    $UseDryRun = "-dryrun"
}

# Make sure tools folder exists
if ((Test-Path $PSScriptRoot) -and !(Test-Path $TOOLS_DIR)) {
    Write-Verbose -Message "Creating tools directory..."
    New-Item -Path $TOOLS_DIR -Type directory | out-null
}

if(-Not $WhatIf.IsPresent) {
	# Try download NuGet.exe if do not exist.
	if (!(Test-Path $NUGET_EXE)) {
		(New-Object System.Net.WebClient).DownloadFile($NUGET_URL, $NUGET_EXE)
	}

	# Make sure NuGet exists where we expect it.
	if (!(Test-Path $NUGET_EXE)) {
		Throw "Could not find NuGet.exe"
	}
}

# Save nuget.exe path to environment to be available to child processed
$ENV:NUGET_EXE = $NUGET_EXE

&$NUGET_EXE install $PACKAGES_CONFIG -OutputDirectory $TOOLS_DIR -ExcludeVersion

# Make sure that Cake has been installed.
if (!(Test-Path $CAKE_EXE)) {
    Throw "Could not find Cake.exe at $CAKE_EXE"
}

# Start Cake
Write-Host "Running build script..."
if($IsBuildServer)
{
	Invoke-Expression "dotnet $CAKE_EXE `"$Script`" -target=`"$Target`" -configuration=`"$Configuration`" -verbosity=`"$Verbosity`" $UseMono $UseDryRun $UseExperimental -FileForVersion=`"$FileForVersion`" -DockerHost=`"$DockerHost`" $ScriptArgs" 2>&1 3>&1
}
else
{
	Invoke-Expression "dotnet $CAKE_EXE `"$Script`" -target=`"$Target`" -configuration=`"$Configuration`" -verbosity=`"$Verbosity`" $UseMono $UseDryRun $UseExperimental -FileForVersion=`"$FileForVersion`" -DockerHost=`"$DockerHost`" $ScriptArgs"
}
exit $LASTEXITCODE
