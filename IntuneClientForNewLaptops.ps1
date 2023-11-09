


#region  1 - Export HWID's to Autopilot file
    $Computer = hostname ;
    Write-host "Generating Auot Pilot info " -ForegroundColor Green ;
    [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
    New-Item -Type Directory -Path "C:\HWID"
    Set-Location -Path "C:\HWID"
    $env:Path += ";C:\Program Files\WindowsPowerShell\Scripts"
    Set-ExecutionPolicy -Scope Process -ExecutionPolicy Unrestricted
    Install-Script -Name Get-WindowsAutopilotInfo
    Get-WindowsAutopilotInfo -OutputFile AutopilotHWID__$Computer.csv ;
    Copy-Item -Path C:\HWID\AutopilotHWID__$Computer.csv -Destination \\MEL-APPSCRIPT-01\HWID-Temp\
    if(Test-Path -Path \\MEL-APPSCRIPT-01\HWID-Temp\AutopilotHWID__$Computer.csv){
        Write-host "File successfully copied to script server " -ForegroundColor Green ;
    }
    else{
        Write-host "File is not copied to script server. You may manually copy from C:\HWID\ " -ForegroundColor red ;
    }
#endregion


#region  2 - Disables BitLocker on the C: drive
    # You may need to enter the BitLocker recovery key or password

    Install-Module BitLocker
    Import-Module BitLocker
    # Check if BitLocker is enabled on the C: drive
    $Status = Get-BitLockerVolume -MountPoint C:
    if ($Status.ProtectionStatus -eq "On")
    {
        # Disable BitLocker on the C: drive
        Disable-BitLocker -MountPoint C:
        # Wait for the operation to complete
        while ($Status.EncryptionPercentage -ne 0)
        {
            # Get the current status
            $Status = Get-BitLockerVolume -MountPoint C:
            # Display the progress
            Write-Progress -Activity "Disabling BitLocker" -Status "$($Status.EncryptionPercentage)% completed" -PercentComplete $Status.EncryptionPercentage
            # Wait for one second
            Start-Sleep -Seconds 1
        }
        # Display the result
        Write-Host "BitLocker is disabled on the C: drive." -ForegroundColor Green ;
    }
    else
    {
        # Display a message
        Write-Host "BitLocker is not enabled on the C: drive." -ForegroundColor red ;
    }
#endregion


#region  3 - Checks and enable recovery environment
    # Check the current status of WinRE
    reagentc /info
    # If WinRE is disabled, enable it
    if ((reagentc /info).Contains("Disabled")) {
        reagentc /enable
    }
    # Confirm that WinRE is enabled
    reagentc /info

#endregion


#region  4 - To turn off WDAC 
    # Set PolicyId GUID to the PolicyId from your WDAC policy XML
    $PolicyId = "{A244370E-44C9-4C06-B551-F6016E563076}"
    # Initialize variables
    $SinglePolicyFormatPolicyId = "{A244370E-44C9-4C06-B551-F6016E563076}"
    $SinglePolicyFormatFileName = "\SiPolicy.p7b"
    $MountPoint =  $env:SystemDrive+"\EFIMount"
    $SystemCodeIntegrityFolderRoot = $env:windir+"\System32\CodeIntegrity"
    $EFICodeIntegrityFolderRoot = $MountPoint+"\EFI\Microsoft\Boot"
    $MultiplePolicyFilePath = "\CiPolicies\Active\"+$PolicyId+".cip"
    # Mount the EFI partition
    $EFIPartition = (Get-Partition | Where-Object IsSystem).AccessPaths[0]
    if (-Not (Test-Path $MountPoint)) { New-Item -Path $MountPoint -Type Directory -Force }
    mountvol $MountPoint $EFIPartition
    # Check if the PolicyId to be removed is the system reserved GUID for single policy format.
    # If so, the policy may exist as both SiPolicy.p7b in the policy path root as well as
    # {GUID}.cip in the CiPolicies\Active subdirectory
    if ($PolicyId -eq $SinglePolicyFormatPolicyId) {$NumFilesToDelete = 4} else {$NumFilesToDelete = 2}
    $Count = 1
    while ($Count -le $NumFilesToDelete) 
    {  
        # Set the $PolicyPath to the file to be deleted, if exists
        Switch ($Count)
        {
            1 {$PolicyPath = $SystemCodeIntegrityFolderRoot+$MultiplePolicyFilePath}
            2 {$PolicyPath = $EFICodeIntegrityFolderRoot+$MultiplePolicyFilePath}
            3 {$PolicyPath = $SystemCodeIntegrityFolderRoot+$SinglePolicyFormatFileName}
            4 {$PolicyPath = $EFICodeIntegrityFolderRoot+$SinglePolicyFormatFileName}
        }
        # Delete the policy file from the current $PolicyPath
        Write-Host "Attempting to remove $PolicyPath..." -ForegroundColor Cyan
        if (Test-Path $PolicyPath) {Remove-Item -Path $PolicyPath -Force -ErrorAction Continue}
        $Count = $Count + 1
    }
    # Dismount the EFI partition
   mountvol $MountPoint /D
#endregion


#region  9 - force reboot computer
    Write-Host "We are done.Now plug in your windows 11 USB and press enter" -ForegroundColor red -confirm ;
    Restart-Computer -Force
#endregion
