﻿#https://www.virtualbox.org/manual/ch02.html#idm819

$toolsPath = Split-Path $MyInvocation.MyCommand.Definition
. $toolsPath\helpers.ps1

$cert = Get-ChildItem Cert:\CurrentUser\TrustedPublisher -Recurse | Where-Object { $_.Thumbprint -eq 'a88fd9bdaa06bc0f3c491ba51e231be35f8d1ad5' }
if (!$cert) {
    $toolsPath = Split-Path $MyInvocation.MyCommand.Definition
    Start-ChocolateyProcessAsAdmin "certutil -addstore 'TrustedPublisher' '$toolsPath\oracle.cer'"
}

$pp = Get-PackageParameters
$silentArgs = @('-s -l -msiparams REBOOT=ReallySuppress')
$silentArgs += if (!$pp.CurrentUser)      { 'ALLUSERS=1' } else { 'ALLUSERS=2';  Write-Host 'Param: Installing for current user' }
$silentArgs += if ($pp.NoDesktopShortcut) { 'VBOX_INSTALLDESKTOPSHORTCUT=0';     Write-Host 'Param: No desktop shortcut' }
$silentArgs += if ($pp.NoQuickLaunch)     { 'VBOX_INSTALLQUICKLAUNCHSHORTCUT=0'; Write-Host 'Param: No quick launch shortcut' }
$silentArgs += if ($pp.NoRegister)        { 'VBOX_REGISTERFILEEXTENSIONS=0';     Write-Host 'Param: No registration for virtualbox file extensions' }

$packageArgs = @{
  packageName            = 'virtualbox'
  fileType               = 'EXE'
  url                    = 'https://download.virtualbox.org/virtualbox/6.0.0/VirtualBox-6.0.0-127566-Win.exe'
  url64bit               = 'https://download.virtualbox.org/virtualbox/6.0.0/VirtualBox-6.0.0-127566-Win.exe'
  checksum               = 'e943e84158057da06e3355b0e170b82507cbe7080f5bbf06c9f4a7674ffa783c'
  checksum64             = 'e943e84158057da06e3355b0e170b82507cbe7080f5bbf06c9f4a7674ffa783c'
  checksumType           = 'sha256'
  checksumType64         = 'sha256'
  silentArgs             = $silentArgs
  validExitCodes         = @(0)
  softwareName           = 'Oracle VM VirtualBox *'
}
Install-ChocolateyPackage @packageArgs

$packageName = $packageArgs.packageName
$installLocation = Get-VirtualBoxIntallLocation
if (!$installLocation)  { Write-Warning "Can't find $packageName install location, can't install extension pack"; return }

if (!$pp.NoExtensionPack) {
    Write-Host "Installing extension pack"

    $url_ep       = 'https://download.virtualbox.org/virtualbox/6.0.0/Oracle_VM_VirtualBox_Extension_Pack-6.0.0.vbox-extpack'
    $checksum_ep  = 'b99ef88b0ac1abebc7a6d7168dd5eec58c426f05acf69c4055defff175038f57'
    $file_path_ep = (Get-PackageCacheLocation) + '\' + ($url_ep -split '/' | Select-Object -Last 1)
    Get-ChocolateyWebFile `
        -PackageName    'virtualbox-extensionpack' `
        -FileFullPath   $file_path_ep `
        -Url            $url_ep `
        -Url64bit       $url_ep `
        -Checksum       $checksum_ep `
        -Checksum64     $checksum_ep `
        -ChecksumType   'sha256' `
        -ChecksumType64 'sha256'
    if (!(Test-Path $file_path_ep)) { Write-Warning "Can't download latest extension pack" }
    else {
        Set-Alias vboxmanage $installLocation\VBoxManage.exe
        "y" | vboxmanage extpack install --replace $file_path_ep 2>&1
        if ($LastExitCode -ne 0) { Write-Warning "Extension pack installation failed with exit code $LastExitCode" }
    }
}

if (!$pp.NoPath) { Write-Host "Adding to PATH if needed"; Install-ChocolateyPath $installLocation }

Write-Host "$packageName installed to '$installLocation'"
Register-Application "$installLocation\$packageName.exe" vbox
Write-Host "$packageName registered as vbox"
