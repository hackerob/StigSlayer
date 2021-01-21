###############################################################
#----STIG-SLAYER----------------------------------------------#
#----Written-by:-Robert-Goyette---hackerob--------------------#
###############################################################

###############################################################
#----XML-GUI-Portion------------------------------------------#
###############################################################

Add-Type -AssemblyName PresentationCore, PresentationFramework

$Xaml = @"
<Window xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation" Width="1200" Height="600" Title="Stig Slayer - Automating the Automatable" HorizontalAlignment="Left" VerticalAlignment="Top" Margin="0,0,0,0">
<Grid Margin="10,10,10,10">
<Label HorizontalAlignment="Left" VerticalAlignment="Top" Content="System Information" Margin="970,0,0,0" FontSize="015"/>
<Label Name="SystemType" HorizontalAlignment="Left" VerticalAlignment="Top" Content="The system type could not be detected." Margin="920,30,0,0"/>
<Button Content="Start Checklist Automation" HorizontalAlignment="Left" VerticalAlignment="Top" Width="180" Margin="950,240,0,0" Name="AutomateSTIGChecks" Height="30"/>
<Button Content="Import CKL Files" HorizontalAlignment="Left" VerticalAlignment="Top" Width="115" Margin="0,0,0,0" Name="ImportCKLFiles" Height="30"/>
<Label HorizontalAlignment="Left" VerticalAlignment="Top" Content="STIG Checklist Input Files" Margin="400,25,0,0"/>
<Label HorizontalAlignment="Left" VerticalAlignment="Top" Content="STIG Checklist Output Files" Margin="400,285,0,0"/>
<Button Content="View Results" HorizontalAlignment="Left" VerticalAlignment="Top" Width="115" Height="30" Margin="980,500,0,0" Name="GetGrid"/>
<DataGrid HorizontalAlignment="Left" VerticalAlignment="Top" Width="900" Height="220" Margin="0,50,0,0" Name="InputChecklistDataGrid" Grid.Column="6" HorizontalScrollBarVisibility="Auto">
<DataGrid.Columns>
<DataGridTextColumn Header="File" Binding="{Binding File}" />
<DataGridTextColumn Header="STIG ID" Binding="{Binding STIG_ID}"/>
<DataGridTextColumn Header="STIG Version" Binding="{Binding STIG_Version}"/>
<DataGridTextColumn Header="Open" Binding="{Binding Open}"/>
<DataGridTextColumn Header="NotAFinding" Binding="{Binding NotAFinding}" />
<DataGridTextColumn Header="NA" Binding="{Binding Not_Applicable}" />
<DataGridTextColumn Header="NotReviewed" Binding="{Binding NR}"/>
</DataGrid.Columns>
</DataGrid>
<DataGrid HorizontalAlignment="Left" VerticalAlignment="Top" Width="900" Height="220" Margin="0,310,0,0" Name="OutputChecklistDataGrid" Grid.Column="6" HorizontalScrollBarVisibility="Auto">
<DataGrid.Columns>
<DataGridTextColumn Header="File" Binding="{Binding File}"/>
<DataGridTextColumn Header="STIG ID" Binding="{Binding STIG_ID}"/>
<DataGridTextColumn Header="STIG Version" Binding="{Binding STIG_Version}"/>
<DataGridTextColumn Header="Open" Binding="{Binding Open}"/>
<DataGridTextColumn Header="NotAFinding" Binding="{Binding NotAFinding}"/>
<DataGridTextColumn Header="NA" Binding="{Binding Not_Applicable}"/>
<DataGridTextColumn Header="NotReviewed" Binding="{Binding NR}" />
</DataGrid.Columns>
</DataGrid>
<Label HorizontalAlignment="Left" VerticalAlignment="Top" Content="Please select a STIG Checklist Input File!" Margin="920,210,0,0"/>
<Label HorizontalAlignment="Left" VerticalAlignment="Top" Content="Please select a STIG Checklist Output File!" Margin="920,470,0,0"/>
</Grid>
</Window>
"@

###############################################################
#----STIG Functions Area--------------------------------------#
###############################################################

#Import-Module -Name "C:\Users\RobbyGoyette\Desktop\RPAP\stigs.psm1"

#TO DO
#1. Finish cleaning up different functions.
####Finish Win 10 STIG Checklist
####Do DC 2016 STIG
####Better registry STIG output#Done
####Scan remote computer-
#a. $creds = Get-Credential
#b. $Results = Invoke-Command -Computer name -Credential $creds {command}
#c. A wmi way of getting results = Invoke-WmiMethod -Class win32_process -Name create -ArgumentList 'powershell.exe -command "somecomannd"'
#2. GUI 
####Progress Bar
####Better Target Computer Info
####Scan Output

#Checks to see if powershell script is running as Administrator and if not relaunches an elevated powershell script.
If (-NOT ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator))
{
    # Relaunch as an elevated process:
    #start-process powershell -ArgumentList "-ExecutionPolicy Bypass -file `"$PSCommandPath`"" -Verb RunAs
    #exit
    Write-Host "You are about to run this script without Administrator privileges.`nIf you run this script without Administrator privileges, several STIGS checks will be skipped." -ForegroundColor Yellow -Backgroundcolor Black
	$Proceed = Read-Host "Would you like to elevate to Administrator privileges? (yes or no)"
	while("yes","no" -notcontains $Proceed)
	{
		$Proceed = Read-Host "Yes or No"
	}
    if ($Proceed -eq "no") {
        Write-Host "Continuing ..." -ForegroundColor Green
    }
    elseif ($Proceed -eq "yes") {
	    Start-Process PowerShell -Verb RunAs "-NoProfile -ExecutionPolicy Bypass -Command `"cd '$PSScriptRoot'; & '$PSCommandPath';`"";
        exit
    }
    else {
		Write-Host "Cancelling!" -ForegroundColor Red
		Start-Sleep -s 5
	    exit
    }
}


##########################################################################################################################
#check out follwoing command Get-Wmiobject -Class `Win32_computersystem' | Select-Object pcsystemtype,domainrole
#Determine type of Operating System in order to determine what STIGS are NA and what commands to run for what system.
try {
	$global:DomainRole = (Get-Wmiobject -Class 'Win32_computersystem').domainrole
    if ($DomainRole -eq 0) {$OS = "Standalone Workstation"}
    if ($DomainRole -eq 1) {$OS = "Member Workstation"}
	if ($DomainRole -eq 2) {$OS = "Standalone Server"}
	if ($DomainRole -eq 3) {$OS = "Member Server"}
	if ($DomainRole -eq 4) {$OS = "Backup Domain Controller"}
	if ($DomainRole -eq 5) {$OS = "Primary Domain Controller"}
	Write-Host "This system is a $OS" -ForegroundColor DarkCyan
}
catch {
    Write-Host "The system type could not be detected" -ForegroundColor Red
}
$OperatingSystem = (Get-WmiObject -class win32_operatingsystem).Caption


###############################################STIG Functions############################################################


Function Get-CKLFiles {
	[System.Reflection.Assembly]::LoadWithPartialName("System.windows.forms") | Out-Null
	$InitialDirectory = (Get-Item -Path ".\").FullName
	$OpenFileDialog = New-Object System.Windows.Forms.OpenFileDialog
	$OpenFileDialog.initialDirectory = $initialDirectory
	$OpenFileDialog.filter = "CKL (*.ckl)| *.ckl"
	$OpenFileDialog.Multiselect=$true
	$OpenFileDialog.filename
	if($OpenFileDialog.ShowDialog() -eq 'OK') {
		foreach ($file in $OpenFileDialog.filenames) {
			$RelativeFile = $file | Resolve-Path -Relative
			$tempx = [xml] (Get-Content $RelativeFile)
			$STIG_ID = $tempx.checklist.stigs.istig.stig_info.si_data.sid_data[3]
			$STIG_V = $tempx.checklist.stigs.istig.stig_info.si_data.sid_data[0]
			$STIG_R = (($tempx.CHECKLIST.STIGS.iSTIG.STIG_INFO.SI_DATA.SID_DATA[6]).replace("Release: ","R")).replace("Benchmark Date: ","- ")
			$STIG_Version = "V" + $STIG_V + $STIG_R
			$Open = ($tempx.CHECKLIST.STIGS.iSTIG.VULN.STATUS | Where-Object {$_ -eq "Open"}).count
			$NotAFinding = ($tempx.CHECKLIST.STIGS.iSTIG.VULN.STATUS | Where-Object {$_ -eq "NotAFinding"}).count
			$NA = ($tempx.CHECKLIST.STIGS.iSTIG.VULN.STATUS | Where-Object {$_ -eq "Not_Applicable"}).count
			$NR = ($tempx.CHECKLIST.STIGS.iSTIG.VULN.STATUS | Where-Object {$_ -eq "Not_Reviewed"}).count
			$InputChecklistDatagrid.AddChild([pscustomobject]@{File=$RelativeFile;STIG_ID=$STIG_ID;STIG_Version=$STIG_Version;Open=$Open;NotAFinding=$NotAFinding;Not_Applicable=$NA;NR=$NR})
			$tempx = ""
			#$InputChecklist.Items.Add($RelativeFile)
		}
	}
}

Function Get-Stats1 {
	
    $STIGS_stats = $x.CHECKLIST.STIGS.iSTIG.VULN.STATUS
	$STIGS_Total = $STIGS_stats.count
    $STIGS_AlreadyDone = ($x.CHECKLIST.STIGS.iSTIG.VULN.STATUS | Where-Object {$_ -ne "Not_Reviewed"}).count
    Write-Host "$STIGS_AlreadyDone out of $STIGS_Total completed."
	$STIGS_Table = [pscustomobject]@{
		Open = ($STIGS_stats | Where-Object {$_ -eq "Open"}).count
		NotAFinding = ($STIGS_stats | Where-Object {$_ -eq "NotAFinding"}).count
		NA = ($STIGS_stats | Where-Object {$_ -eq "Not_Applicable"}).count
		NR = ($STIGS_stats | Where-Object {$_ -eq "Not_Reviewed"}).count
	}

	$STIGS_Table | Format-Table | Out-String | Write-Host -ForegroundColor Magenta
}

Function Get-LogPermissions {
	$EventLogDefaultPermissions = 
	@([pscustomobject]@{IdentityReference="BUILTIN\Administrators";FileSystemRights="FullControl"},
	[pscustomobject]@{IdentityReference="NT AUTHORITY\SYSTEM";FileSystemRights="FullControl"},
	[pscustomobject]@{IdentityReference="NT SERVICE\EventLog";FileSystemRights="FullControl"})
	
	$x.CHECKLIST.STIGS.iSTIG.VULN |  Where-Object {$_.STIG_DATA[8].ATTRIBUTE_DATA -Match "%SystemRoot%\\System32\\winevt\\Logs"} | ForEach-Object {
		if ($_.STIG_DATA[8].ATTRIBUTE_DATA -Match "System.evtx") {$Logfile = "system.evtx"}
		if ($_.STIG_DATA[8].ATTRIBUTE_DATA -Match "Application.evtx") {$Logfile = "application.evtx"}	
		if ($_.STIG_DATA[8].ATTRIBUTE_DATA -Match "Security.evtx") {$Logfile = "security.evtx"}
		$Results = (Get-ACL C:\Windows\System32\winevt\logs\$Logfile).Access | Select-Object IdentityReference,FileSystemRights
		$ComparisonResults = Compare-Object -ReferenceObject $EventLogDefaultPermissions -DifferenceObject $Results -Property IdentityReference,FileSystemRights
		if ($null -eq $ComparisonResults){
			$_.Finding_Details = "The $Logfile file is configured to the default permissions. This is not a finding. The permissions can be seen below: $($Results | Out-String)"
			$_.Status = "NotAFinding"
		}
		else {
			$_.Finding_Details = "The $Logfile file is not configured to the default permissions. However, this is not necessarily a finding. The permissions can be seen below: $($Results | Out-String)"
		}
	}
}

Function Get-63337 {
	$x.CHECKLIST.STIGS.iSTIG.VULN |  Where-Object {$_.STIG_DATA[0].ATTRIBUTE_DATA -eq "V-63337"} | ForEach-Object {
		$Results = Get-BitLockerVolume | Where-Object {($_.VolumeType -eq "Data") -or ($_.VolumeType -eq "OperatingSystem")} | Select-Object VolumeType,MountPoint,VolumeStatus
		foreach ($Result in $Results) {
			if ($Result.VolumeStatus -ne "FullyEncrypted") {
				$Finding = $True
			}
		}
		if ($Finding -eq $True) {
			$_.Finding_Details = "Full disk encryption using BitLocker is not implemented on all drives, this is a finding. See results below: $($Results | Format-Table | Out-String)"
			$_.Status = "Open"
		}
		else {
			$_.Finding_Details = "Full disk encryption using BitLocker is being implemented on all drives, this is not a finding. The results can be seen below: $($Results | Format-Table | Out-String)"
			$_.Status = "NotAFinding"
		}
	}
}

Function Get-70637 {
	$x.CHECKLIST.STIGS.iSTIG.VULN |  Where-Object {$_.STIG_DATA[0].ATTRIBUTE_DATA -eq "V-70637"} | ForEach-Object {
		$Results = Get-WindowsOptionalFeature -Online | Where-Object FeatureName -like *PowerShellv2* | Format-Table | Out-String
		if ($Results -Match "Disabled") {
			$_.Finding_Details = "Windows Powershell V2 is disabled, this is not a finding. The results can be seen below: $Results"
			$_.Status = "NotAFinding"
		}
		elseif ($Results -Match "Enabled") {
			$_.Finding_Details = "Windows PowerShell V2 is enabled, this is a finding. The results can be seen below: $Results"
			$_.Status = "Open"
		}
	}
}

Function Get-70639 {
	$x.CHECKLIST.STIGS.iSTIG.VULN |  Where-Object {$_.STIG_DATA[0].ATTRIBUTE_DATA -eq "V-70639"} | ForEach-Object {
		$Results = Get-WindowsOptionalFeature -Online | Where-Object FeatureName -like SMB1Protocol | Format-Table | Out-String
		if ($Results -Match "Disabled") {
			$_.Finding_Details = "The SMB v1 protocol is disabled, this is not a finding. The results can be seen below: $Results"
			$_.Status = "NotAFinding"
		}
		elseif ($Results -Match "Enabled") {
			$_.Finding_Details = "The SMB v1 protocol is enabled, this is a finding. The results can be seen below: $Results"
			$_.Status = "Open"
		}
	}
}

Function Get-63319 {
	$x.CHECKLIST.STIGS.iSTIG.VULN |  Where-Object {$_.STIG_DATA[0].ATTRIBUTE_DATA -eq "V-63319"} | ForEach-Object {
		$ResultEdition = (Get-WmiObject -Class win32_operatingsystem).Caption
		$ResultType = (Get-WmiObject -Class win32_operatingsystem).OSArchitecture
		if (($ResultEdition -eq "Microsoft Windows 10 Enterprise") -And ($ResultType -eq "64-bit")) {
			$_.Finding_Details = "This operating system is $ResultEdition $ResultType. This is not a finding."
			$_.Status = "NotAFinding"
		}
		else {
			$_.Finding_Details = "This operating system is $ResultEdition $ResultType. This is a finding, all domain joined Windows 10 operating systems must be Microsoft Windows 10 Enterprise 64-bit."
			$_.Status = "Open"
		}
	}
}

Function Get-63371 {
	$x.CHECKLIST.STIGS.iSTIG.VULN |  Where-Object {$_.STIG_DATA[0].ATTRIBUTE_DATA -eq "V-63371"} | ForEach-Object {
		$Results = Get-WmiObject -Class Win32_UserAccount -Filter "PasswordExpires=False and LocalAccount=True and Disabled=False" | Format-List Name, PasswordExpires, Disabled, LocalAccount | Out-String
		if ($Results -eq "") {
			$_.Finding_Details = "No usernames were found with the 'PasswordExpires' status of 'False'"
			$_.Status = "NotAFinding"
		}
		else {
			$_.Finding_Details = "The following usernames were found with the 'PasswordExpires' status of 'False', this is a finding. $Results"
			$_.Status = "Open"
		}
	}	
}

Function Get-63353 {
	$x.CHECKLIST.STIGS.iSTIG.VULN |  Where-Object {$_.STIG_DATA[0].ATTRIBUTE_DATA -eq "V-63353"} | ForEach-Object {
		$Results = Get-Volume | Where-Object DriveLetter -Match "\S"
		foreach ($Volume in $Results) {if ($Volume.FileSystem -ne "NTFS") {$NotNTFS += "The $($Volume.DriveLetter) volume is not NTFS formatted. "}}
		if ($null -eq $NotNTFS) {
			$_.Finding_Details = "All the volumes are NTFS formatted."
			$_.Status = "NotAFinding"
		}
		else {
			$_.Finding_Details = "$NotNTFS All volumes must be NTFS formatted, this is a finding."
			$_.Status = "Open"
		}
	}	
}

Function Get-74719 {
	$x.CHECKLIST.STIGS.iSTIG.VULN |  Where-Object {$_.STIG_DATA[0].ATTRIBUTE_DATA -eq "V-74719"} | ForEach-Object {
		$Results =  Get-Service -Name seclogon | Select-Object Name,Status,StartType
		if (($Results.StartType -ne "Disabled") -OR ($Results.Status -eq "Running")) {
			$_.Finding_Details = "The 'Secondary Logon' service 'Startup Type' is set to $($Results.StartType) and the current status is $($Results.Status). This is a finding and this service 'Startup Type' needs to be Disabled and not running."
			$_.Status = "Open"
		}
		else {
			$_.Finding_Details = "The 'Secondary Logon' service 'Startup Type' is set to $($Results.StartType) and the current status is $($Results.Status). This is not a finding."
			$_.Status = "NotAFinding"
		}
	}	
}

Function Get-73261 {
    #Seperate check for Domain Controllers
    if ($OS -NotMatch ".*Domain Controller") {
        $x.CHECKLIST.STIGS.iSTIG.VULN |  Where-Object {$_.STIG_DATA[0].ATTRIBUTE_DATA -eq "V-73261"} | ForEach-Object {
            $Results = Get-CimInstance -Class Win32_Useraccount -Filter "PasswordRequired=False and LocalAccount=True and Disabled=False" | Format-List Name, PasswordRequired, Disabled, LocalAccount | Out-String
			if ($Results -eq "") {
			    $_.Finding_Details = "No usernames were found with the 'PasswordRequired' status of 'False'"
				$_.Status = "NotAFinding"
			}
			else {
			    $_.Finding_Details = "The following usernames were found with the 'PasswordRequired' status of 'False', this is a finding. $Results"
				$_.Status = "Open"
			}
        }
	}
}

Function Get-73263 {
    #Seperate check for Domain Controllers
    if ($OS -NotMatch ".*Domain Controller") {
        $x.CHECKLIST.STIGS.iSTIG.VULN |  Where-Object {$_.STIG_DATA[0].ATTRIBUTE_DATA -eq "V-73263"} | ForEach-Object {
            $Results = Get-CimInstance -Class Win32_Useraccount -Filter "PasswordExpires=False and LocalAccount=True and Disabled=False" | Format-List Name, PasswordExpires, Disabled, LocalAccount | Out-String
			if ($Results -eq "") {
			    $_.Finding_Details = "No usernames were found with the 'PasswordExpires' status of 'False'"
				$_.Status = "NotAFinding"
			}
			else {
			    $_.Finding_Details = "The following usernames were found with the 'PasswordExpires' status of 'False', this is a finding. $Results"
				$_.Status = "Open"
			}
        }
	}
}

Function Get-73227 {
    $x.CHECKLIST.STIGS.iSTIG.VULN |  Where-Object {$_.STIG_DATA[0].ATTRIBUTE_DATA -eq "V-73227"} | ForEach-Object {
        $Results = Get-LocalGroupMember -Name 'Backup Operators' | Out-String
		if ($Results -eq "") {
			$_.Finding_Details = "No accounts are members of the Backup Operators group, this is NA."
			$_.Status = "Not_Applicable"
		}
		else {
		    $_.Finding_Details = "The following users are members of the Backup Operators group. $Results"
		}
	}
}

Function Get-63363 {
    $x.CHECKLIST.STIGS.iSTIG.VULN |  Where-Object {$_.STIG_DATA[0].ATTRIBUTE_DATA -eq "V-63363"} | ForEach-Object {
        $Results = Get-LocalGroupMember -Name 'Backup Operators' | Out-String
		if ($Results -eq "") {
			$_.Finding_Details = "No accounts are members of the Backup Operators group, this is not a finding."
			$_.Status = "NotAFinding"
		}
		else {
		    $_.Finding_Details = "The following users are members of the Backup Operators group. $Results"
		}
	}
}

Function Get-63359 {
    $x.CHECKLIST.STIGS.iSTIG.VULN |  Where-Object {$_.STIG_DATA[0].ATTRIBUTE_DATA -eq "V-63359"} | ForEach-Object {
		#This command is taken exactly from the STIG
		([ADSI]('WinNT://{0}' -f $env:COMPUTERNAME)).Children | Where-Object { $_.SchemaClassName -eq 'user' } | ForEach-Object {
			$user = ([ADSI]$_.Path).name
			$lastLogin = $user.Properties.LastLogin.Value
			$enabled = ($user.Properties.UserFlags.Value -band 0x2) -ne 0x2
			if ($null -eq $lastLogin) {
			    $lastLogin = 'Never'
			}
			$Results += "$user $lastLogin $enabled`n" 
		}
		$_.Finding_Details = "Below is a list of local accounts with the account name, last logon, and if the account is enabled (True/False).`n$Results"
	}
}

Function Get-73259 {
    $x.CHECKLIST.STIGS.iSTIG.VULN |  Where-Object {$_.STIG_DATA[0].ATTRIBUTE_DATA -eq "V-73259"} | ForEach-Object {
		#This command is taken exactly from the STIG
		([ADSI]('WinNT://{0}' -f $env:COMPUTERNAME)).Children | Where-Object { $_.SchemaClassName -eq 'user' } | ForEach-Object {
			$user = ([ADSI]$_.Path).name
			$lastLogin = $user.Properties.LastLogin.Value
			$enabled = ($user.Properties.UserFlags.Value -band 0x2) -ne 0x2
			if ($null -eq $lastLogin) {
			    $lastLogin = 'Never'
			}
			$Results += "$user $lastLogin $enabled`n" 
		}
		$_.Finding_Details = "Below is a list of local accounts with the account name, last logon, and if the account is enabled (True/False).`n$Results"
	}
}

Function Get-63349 {
    $x.CHECKLIST.STIGS.iSTIG.VULN |  Where-Object {$_.STIG_DATA[0].ATTRIBUTE_DATA -eq "V-63349"} | ForEach-Object {
		#This is the rounded version but I judged this is accurate enough and keeps code simpler when only one command run against remote system.
		$Results = (Get-WmiObject -class win32_operatingsystem).BuildNumber
		if ($Results -gt "17134.0") {
			$_.Finding_Details = "This system appears to be up to date and is running Windows 10 Version $Results"
			$_.Status = "NotAFinding"
		}
		elseif ($Results -lt "17134.0") {
		    $_.Finding_Details = "This system appears to be out of date and is running Windows 10 Version $Results"
		}
	}
}

Function Get-73303 {
    $x.CHECKLIST.STIGS.iSTIG.VULN |  Where-Object {$_.STIG_DATA[0].ATTRIBUTE_DATA -eq "V-73303"} | ForEach-Object {
        $Results = (get-windowsfeature -Name Web-Ftp-Server).Installed
		if ($Results -eq $False) {
			$_.Finding_Details = "FTP is not installed, this is NA."
			$_.Status = "Not_Applicable"
		}
		elseif ($Results -eq $True) {
		    $_.Finding_Details = "FTP is installed, please make sure Anonymous Authentication is disabled."
		}
	}
}

Function Get-73305 {
    $x.CHECKLIST.STIGS.iSTIG.VULN |  Where-Object {$_.STIG_DATA[0].ATTRIBUTE_DATA -eq "V-73305"} | ForEach-Object {
        $Results = (get-windowsfeature -Name Web-Ftp-Server).Installed
		if ($Results -eq $False) {
			$_.Finding_Details = "FTP is not installed, this is NA."
			$_.Status = "Not_Applicable"
		}
		elseif ($Results -eq $True) {
		    $_.Finding_Details = "FTP is installed, please continue with the manual check."
		}
	}
}

Function Get-73237 {
    if ($OS -Match "Standalone Server") {
	    $x.CHECKLIST.STIGS.iSTIG.VULN |  Where-Object {$_.STIG_DATA[0].ATTRIBUTE_DATA -eq "V-73237"} | ForEach-Object {
	        $_.Finding_Details = "For standalone systems this is NA."
	        $_.Status = "Not_Applicable"
		}
	}
    else {
		$x.CHECKLIST.STIGS.iSTIG.VULN |  Where-Object {$_.STIG_DATA[0].ATTRIBUTE_DATA -eq "V-73237"} | ForEach-Object {
			$Results = Get-WMIObject -class Win32_Tpm -Namespace root\cimv2\Security\MicrosoftTpm | Select-Object IsOwned_InitialValue, SpecVersion | Out-String
			if ($Results -Match "True.*(2.0|1.2).*") {
				$_.Finding_Details = "The system has a TPM and it is ready for use. $Results"
				$_.Status = "NotAFinding"
			}
			else {
				$_.Finding_Details = "$Results"
			}
		}
	}
}

Function Get-63323 {
    if ($OS -Match "Standalone Workstation") {
	    $x.CHECKLIST.STIGS.iSTIG.VULN |  Where-Object {$_.STIG_DATA[0].ATTRIBUTE_DATA -eq "V-63323"} | ForEach-Object {
	        $_.Finding_Details = "For standalone systems this is NA."
	        $_.Status = "Not_Applicable"
		}
	}
    else {
		$x.CHECKLIST.STIGS.iSTIG.VULN |  Where-Object {$_.STIG_DATA[0].ATTRIBUTE_DATA -eq "V-63323"} | ForEach-Object {
			$Results = Get-WMIObject -class Win32_Tpm -Namespace root\cimv2\Security\MicrosoftTpm | Select-Object IsOwned_InitialValue, SpecVersion | Out-String
			if ($Results -Match "True.*(2.0|1.2).*") {
				$_.Finding_Details = "The system has a TPM and it is ready for use. $Results"
				$_.Status = "NotAFinding"
			}
			else {
				$_.Finding_Details = "$Results"
			}
		}
	}
}

Function Get-90357 {
    $x.CHECKLIST.STIGS.iSTIG.VULN |  Where-Object {$_.STIG_DATA[0].ATTRIBUTE_DATA -eq "V-90357"} | ForEach-Object {
        $Results = Confirm-SecureBootUEFI
		if ($Results -eq $True) {
			$_.Finding_Details = "This system firmware is configured to run in 'UEFI' mode."
			$_.Status = "NotAFinding"
		}
		elseif ($Results -eq $False) {
		    $_.Finding_Details = "This system firmware is NOT configured to run in 'UEFI' mode."
			$_.Status = "Open"
		}
	}
}

Function Get-77083 {
    $x.CHECKLIST.STIGS.iSTIG.VULN |  Where-Object {$_.STIG_DATA[0].ATTRIBUTE_DATA -eq "V-77083"} | ForEach-Object {
        $Results = Confirm-SecureBootUEFI
		if ($Results -eq $True) {
			$_.Finding_Details = "This system firmware is configured to run in 'UEFI' mode."
			$_.Status = "NotAFinding"
		}
		elseif ($Results -eq $False) {
		    $_.Finding_Details = "This system firmware is NOT configured to run in 'UEFI' mode."
			$_.Status = "Open"
		}
	}
}

Function Get-90355 {
    $x.CHECKLIST.STIGS.iSTIG.VULN |  Where-Object {$_.STIG_DATA[0].ATTRIBUTE_DATA -eq "V-90355"} | ForEach-Object {
        $Results = Confirm-SecureBootUEFI
		if ($Results -eq $True) {
			$_.Finding_Details = "This system firmware is configured to run in 'UEFI' mode. And Secure Boot is enabled."
			$_.Status = "NotAFinding"
		}
		elseif ($Results -eq $False) {
		    $_.Finding_Details = "This system firmware is NOT configured to run in 'UEFI' mode. Therefore Secure Boot is not enabled."
			$_.Status = "Open"
		}
	}
}

Function Get-77085 {
    $x.CHECKLIST.STIGS.iSTIG.VULN |  Where-Object {$_.STIG_DATA[0].ATTRIBUTE_DATA -eq "V-77085"} | ForEach-Object {
        $Results = Confirm-SecureBootUEFI
		if ($Results -eq $True) {
			$_.Finding_Details = "This system firmware is configured to run in 'UEFI' mode. And Secure Boot is enabled."
			$_.Status = "NotAFinding"
		}
		elseif ($Results -eq $False) {
		    $_.Finding_Details = "This system firmware is NOT configured to run in 'UEFI' mode. Therefore Secure Boot is not enabled."
			$_.Status = "Open"
		}
	}
}

Function Get-73513 {
    if ($OS -Match "Standalone Server") {
	    $x.CHECKLIST.STIGS.iSTIG.VULN |  Where-Object {$_.STIG_DATA[0].ATTRIBUTE_DATA -eq "V-73513"} | ForEach-Object {
	        $_.Finding_Details = "For standalone systems this is NA."
	        $_.Status = "Not_Applicable"
		}
	}
	else {
		$x.CHECKLIST.STIGS.iSTIG.VULN |  Where-Object {$_.STIG_DATA[0].ATTRIBUTE_DATA -eq "V-73513"} | ForEach-Object {
			$Results = Get-CimInstance -ClassName Win32_DeviceGuard -Namespace root\Microsoft\Windows\DeviceGuard | Format-Table RequiredSecurityProperties,VirtualizationBasedSecurityStatus | Out-String
			if ($Results -Match ".*{.*2.*}.*2") {
				$_.Finding_Details = "'RequiredSecurityProperties' does include a value of '2' indicating 'Secure Boot' AND 'VirtualizationBasedSecurityStatus' is set to a value of '2' indicating 'Running'. This is not a finding. See results below: $Results"
				$_.Status = "NotAFinding"
			}
			else {
				$_.Finding_Details = "Virtualization Based Security is not configured correctly. See results below $Results"
				$_.Status = "Open"
			}
		}
	}
}



Function Get-63595 {
	$x.CHECKLIST.STIGS.iSTIG.VULN |  Where-Object {$_.STIG_DATA[0].ATTRIBUTE_DATA -eq "V-63595"} | ForEach-Object {
		$Results = Get-CimInstance -ClassName Win32_DeviceGuard -Namespace root\Microsoft\Windows\DeviceGuard | Format-Table RequiredSecurityProperties,VirtualizationBasedSecurityStatus | Out-String
		if ($Results -Match ".*{.*2.*}.*2") {
			$_.Finding_Details = "'RequiredSecurityProperties' does include a value of '2' indicating 'Secure Boot' AND 'VirtualizationBasedSecurityStatus' is set to a value of '2' indicating 'Running'. This is not a finding. See results below: $Results"
			$_.Status = "NotAFinding"
		}
		else {
			$_.Finding_Details = "Virtualization Based Security is not configured correctly. See results below $Results"
			$_.Status = "Open"
		}
	}
}


Function Get-73515 {
    if ($OS -Match "Standalone Server" -OR $OS -Match ".*Domain Controller") {
	    $x.CHECKLIST.STIGS.iSTIG.VULN |  Where-Object {$_.STIG_DATA[0].ATTRIBUTE_DATA -eq "V-73515"} | ForEach-Object {
	        $_.Finding_Details = "For standalone systems this is NA."
	        $_.Status = "Not_Applicable"
		}
	}
	else {
		$x.CHECKLIST.STIGS.iSTIG.VULN |  Where-Object {$_.STIG_DATA[0].ATTRIBUTE_DATA -eq "V-73515"} | ForEach-Object {
			$Results = Get-CimInstance -ClassName Win32_DeviceGuard -Namespace root\Microsoft\Windows\DeviceGuard | select-object SecurityServicesConfigured | Out-String
			if ($Results -Match "1") {
				$_.Finding_Details = "SecurityServicesConfigured contains a value of 1. See results below: $Results"
				$_.Status = "NotAFinding"
			}
			elseif ($Results -NotMatch "1") {
				$_.Finding_Details = "SecurityServicesConfigured does not contain a value of 1. See results below: $Results"
				$_.Status = "Open"
			}
		}
	}
}

Function Get-63599 {
	$x.CHECKLIST.STIGS.iSTIG.VULN |  Where-Object {$_.STIG_DATA[0].ATTRIBUTE_DATA -eq "V-63599"} | ForEach-Object {
		$Results = Get-CimInstance -ClassName Win32_DeviceGuard -Namespace root\Microsoft\Windows\DeviceGuard | select-object SecurityServicesConfigured | Out-String
		if ($Results -match "1") {
			$_.Finding_Details = "SecurityServicesConfigured contains a value of 1. See results below: $Results"
			$_.Status = "NotAFinding"
		}
		elseif ($Results -NotMatch "1") {
			$_.Finding_Details = "SecurityServicesConfigured does not contain a value of 1. See results below: $Results"
			$_.Status = "Open"
		}
	}
}

Function Get-73459 {
    $x.CHECKLIST.STIGS.iSTIG.VULN |  Where-Object {$_.STIG_DATA[0].ATTRIBUTE_DATA -eq "V-73459"} | ForEach-Object {
        $Results = AuditPol /get /subcategory:'Removable Storage' | Out-String
		if ($Results -Match "Failure") {
			$_.Finding_Details = "The system does Audit Removable Storage Failures. See results below:`n$Results"
			$_.Status = "NotAFinding"
		}
		elseif ($Results -NotMatch "Failure") {
		    $_.Finding_Details = "The system does not Audit Removable Storage Failures. See results below:`n$Results"
			$_.Status = "Open"
		}
	}
}

Function Get-73457 {
    $x.CHECKLIST.STIGS.iSTIG.VULN |  Where-Object {$_.STIG_DATA[0].ATTRIBUTE_DATA -eq "V-73457"} | ForEach-Object {
        $Results = AuditPol /get /subcategory:'Removable Storage' | Out-String
		if ($Results -Match "Success") {
			$_.Finding_Details = "The system does Audit Removable Storage Successes. See results below:`n$Results"
			$_.Status = "NotAFinding"
		}
		elseif ($Results -NotMatch "Success") {
		    $_.Finding_Details = "The system does not Audit Removable Storage Successes. See results below:`n$Results"
			$_.Status = "Open"
		}
	}
}

Function Get-73447 {
    $x.CHECKLIST.STIGS.iSTIG.VULN |  Where-Object {$_.STIG_DATA[0].ATTRIBUTE_DATA -eq "V-73447"} | ForEach-Object {
        $Results = AuditPol /get /subcategory:'Group Membership' | Out-String
		if ($Results -Match "Success") {
			$_.Finding_Details = "The system does Audit Group Membership Successes. See results below:`n$Results"
			$_.Status = "NotAFinding"
		}
		elseif ($Results -NotMatch "Success") {
		    $_.Finding_Details = "The system does not Audit Group Membership Successes. See results below:`n$Results"
			$_.Status = "Open"
		}
	}
}

Function Get-73431 {
    $x.CHECKLIST.STIGS.iSTIG.VULN |  Where-Object {$_.STIG_DATA[0].ATTRIBUTE_DATA -eq "V-73431"} | ForEach-Object {
        $Results = AuditPol /get /subcategory:'Plug and Play Events' | Out-String
		if ($Results -Match "Success") {
			$_.Finding_Details = "The system does Audit Plug and Play Events Successes. See results below:`n$Results"
			$_.Status = "NotAFinding"
		}
		elseif ($Results -NotMatch "Success") {
		    $_.Finding_Details = "The system does not Audit Plug and Play Events Successes. See results below:`n$Results"
			$_.Status = "Open"
		}
	}
}

Function Get-73727 {
    $x.CHECKLIST.STIGS.iSTIG.VULN |  Where-Object {$_.STIG_DATA[0].ATTRIBUTE_DATA -eq "V-73727"} | ForEach-Object {
        try {$Results = Get-ItemProperty -Path HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\Attachments -Name SaveZoneInformation -ErrorAction STOP | Format-Table SaveZoneInformation | Out-String}
		catch {$Results = $False}
		if ($Results -Match "1") {
			$_.Finding_Details = "The Registry key exists and is set to a value of 1. See results below: $Results"
			$_.Status = "Open"
		}
		elseif ($Results -Match "2") {
		    $_.Finding_Details = "The Registry key exists and is set to a value of 2. See resulst below: $Results"
			$_.Status = "NotAFinding"
		}
		elseif ($Results -eq $False) {
		    $_.Finding_Details = "Registry key does not exist."
			$_.Status = "NotAFinding"
		}
	}
}

Function Get-63841 {
    $x.CHECKLIST.STIGS.iSTIG.VULN |  Where-Object {$_.STIG_DATA[0].ATTRIBUTE_DATA -eq "V-63841"} | ForEach-Object {
        try {$Results = Get-ItemProperty -Path HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\Attachments -Name SaveZoneInformation -ErrorAction STOP | Format-Table SaveZoneInformation | Out-String}
		catch {$Results = $False}
		if ($Results -Match "1") {
			$_.Finding_Details = "The Registry key exists and is set to a value of 1. See results below: $Results"
			$_.Status = "Open"
		}
		elseif ($Results -Match "2") {
		    $_.Finding_Details = "The Registry key exists and is set to a value of 2. See resulst below: $Results"
			$_.Status = "NotAFinding"
		}
		elseif ($Results -eq $False) {
		    $_.Finding_Details = "Registry key does not exist."
			$_.Status = "NotAFinding"
		}
	}
}

Function Get-73253 {
    $x.CHECKLIST.STIGS.iSTIG.VULN |  Where-Object {$_.STIG_DATA[0].ATTRIBUTE_DATA -eq "V-73253"} | ForEach-Object {
	    $PrintedResults = icacls c:\windows | Out-String
        $Results = Get-Acl -Path C:\Windows | ForEach-Object {$_.Sddl}
		$DesiredPermissions = "O:S-1-5-80-956008885-3418522649-1831038044-1853292631-2271478464G:S-1-5-80-956008885-3418522649-1831038044-1853292631-2271478464D:PAI(A;OICIIO;GA;;;CO)(A;OICIIO;GA;;;SY)(A;;0x1301bf;;;SY)(A;OICIIO;GA;;;BA)(A;;0x1301bf;;;BA)(A;OICIIO;GXGR;;;BU)(A;;0x1200a9;;;BU)(A;CIIO;GA;;;S-1-5-80-956008885-3418522649-1831038044-1853292631-2271478464)(A;;FA;;;S-1-5-80-956008885-3418522649-1831038044-1853292631-2271478464)(A;;0x1200a9;;;AC)(A;OICIIO;GXGR;;;AC)(A;;0x1200a9;;;S-1-15-2-2)(A;OICIIO;GXGR;;;S-1-15-2-2)"
		if ($Results -eq $DesiredPermissions) {
			$_.Finding_Details = "The correct permissions are set. See results below:`n$PrintedResults"
			$_.Status = "NotAFinding"
		}
		elseif ($Results -ne $DesiredPermissions) {
		    $_.Finding_Details = "The correct permissions are not set. See results below:`n$PrintedResults"
			$_.Status = "Open"
		}
	}
}

Function Get-73251 {
    $x.CHECKLIST.STIGS.iSTIG.VULN |  Where-Object {$_.STIG_DATA[0].ATTRIBUTE_DATA -eq "V-73251"} | ForEach-Object {
	    $PrintedResults = icacls "c:\program files*" | Out-String
        $Results1 = Get-Acl -Path "C:\Program Files" | ForEach-Object {$_.Sddl}
		$Results2 = Get-Acl -Path "C:\Program Files (x86)" | ForEach-Object {$_.Sddl}
		$DesiredPermissions = "O:S-1-5-80-956008885-3418522649-1831038044-1853292631-2271478464G:S-1-5-80-956008885-3418522649-1831038044-1853292631-2271478464D:PAI(A;OICIIO;GA;;;CO)(A;OICIIO;GA;;;SY)(A;;0x1301bf;;;SY)(A;OICIIO;GA;;;BA)(A;;0x1301bf;;;BA)(A;OICIIO;GXGR;;;BU)(A;;0x1200a9;;;BU)(A;CIIO;GA;;;S-1-5-80-956008885-3418522649-1831038044-1853292631-2271478464)(A;;FA;;;S-1-5-80-956008885-3418522649-1831038044-1853292631-2271478464)(A;;0x1200a9;;;AC)(A;OICIIO;GXGR;;;AC)(A;;0x1200a9;;;S-1-15-2-2)(A;OICIIO;GXGR;;;S-1-15-2-2)"
        if ($Results1 -eq $DesiredPermissions -And $Results2 -eq $DesiredPermissions) {
			$_.Finding_Details = "The correct permissions are set. See results below:`n$PrintedResults"
			$_.Status = "NotAFinding"
		}
		elseif ($Results1 -ne $DesiredPermissions -OR $Results2 -ne $DesiredPermissions) {
		    $_.Finding_Details = "The correct permissions are not set. See results below:`n$PrintedResults"
			$_.Status = "Open"
		}
	}
}

Function Get-73249 {
    $x.CHECKLIST.STIGS.iSTIG.VULN |  Where-Object {$_.STIG_DATA[0].ATTRIBUTE_DATA -eq "V-73249"} | ForEach-Object {
	    $PrintedResults = icacls "c:\" | Out-String
        $Results = Get-Acl -Path "C:\" | ForEach-Object {$_.Sddl}
		#Desired Permissions is not correct rn. That will need to be edited.
		$DesiredPermissions = "O:S-1-5-80-956008885-3418522649-1831038044-1853292631-2271478464G:S-1-5-80-956008885-3418522649-1831038044-1853292631-2271478464D:PAI(A;OICIIO;GA;;;CO)(A;OICI;FA;;;SY)(A;OICI;FA;;;BA)(A;CI;LC;;;BU)(A;CIIO;DC;;;BU)(A;OICI;0x1200a9;;;BU)"
        if ($Results -eq $DesiredPermissions) {
			$_.Finding_Details = "The correct permissions are set. See results below:`n$PrintedResults"
			$_.Status = "NotAFinding"
		}
		elseif ($Results -ne $DesiredPermissions) {
		    $_.Finding_Details = "The correct permissions are not set. See results below:`n$PrintedResults"
			$_.Status = "Open"
		}
	}
}

Function Get-73223 {
	#Seperate Command for Domain Controllers
    if ($OS -NotMatch ".*Domain Controller") {
		$x.CHECKLIST.STIGS.iSTIG.VULN |  Where-Object {$_.STIG_DATA[0].ATTRIBUTE_DATA -eq "V-73223"} | ForEach-Object {
			$Results = get-localuser * | Where-Object {$_.SID -Like "*-500*"} | ForEach-Object {$_.PasswordLastSet -lt (Get-Date).adddays(-60)}
			$PrintedResults = get-localuser * | Where-Object {$_.SID -Like "*-500*"} | Format-Table Name, SID, PasswordLastSet | Out-String
			if ($Results -eq $False) {
				$_.Finding_Details = "The 'PasswordLastSet' date is less than '60' days old. See results below:`n$PrintedResults"
				$_.Status = "NotAFinding"
			}
			elseif ($Results -ne $DesiredPermissions) {
				$_.Finding_Details = "The 'PasswordLastSet' date is greater than '60' days old. See results below:`n$PrintedResults"
				$_.Status = "Open"
			}
		}
    }
}

Function Get-NAStandalone {
	if (($DomainRole -eq "0") -Or ($DomainRole -eq "2")) {
		$x.CHECKLIST.STIGS.iSTIG.VULN |  Where-Object {$_.STIG_DATA[8].ATTRIBUTE_DATA -Match "for standalone systems,? this is NA"} | ForEach-Object {
			$_.Finding_Details = "This is a standalone system, this is NA."
			$_.Status = "Not_Applicable"
		}
	}
}

Function Get-NABluetooth {
	$x.CHECKLIST.STIGS.iSTIG.VULN |  Where-Object {$_.STIG_DATA[8].ATTRIBUTE_DATA -Match "This is NA if the system does not have Bluetooth"} | ForEach-Object {
		$Results = Get-PnPdevice | Where-Object { ($_.Class -eq 'bluetooth') -And ($_.Status -eq "ok")}
		if ($null -eq $Results) {
			$_.Finding_Details = "The system does not have Bluetooth, this is NA."
			$_.Status = "Not_Applicable"
		}
		else {}
	}
}

Function Get-NAMSChecks {
    if ($OS -NotMatch ".*Domain Controller") {
        $x.CHECKLIST.STIGS.iSTIG.VULN |  Where-Object {$_.STATUS -eq "Not_Reviewed"} | Where-Object {$_.STIG_DATA[8].Attribute_DATA -Match "This applies to domain controllers.*" -or $_.STIG_DATA[8].Attribute_DATA -Match "This requirement is applicable to domain controllers; it is NA for other systems.*"} | ForEach-Object {
            $_.Status = "Not_Applicable"
			$_.Finding_Details = "This is not a domain controller and therefore NA."
			$STIGS_Done.Add($_.STIG_DATA[0].Attribute_DATA)
		}
    }
}

Function Save-Changes {
	#Settings object will instruct how the xml elements are written to the file
	$settings = New-Object System.Xml.XmlWriterSettings
	$settings.Indent = $true
	$settings.IndentChars = "`t"
	#NewLineChars will affect all newlines
	$settings.NewLineChars ="`n"
	#Set an optional encoding, UTF-8 is the most used (without BOM)
	#$settings.Encoding = New-Object System.Text.UTF8Encoding( $false )
	$FullPath = (Resolve-Path $OutputFile).Path
	$w = [System.Xml.XmlWriter]::Create($FullPath, $settings)
	$x.save($w)
	$w.Close()
	Write-Host "File Saved!`nSee $OutputFile`n" -ForegroundColor Cyan
}

Function Get-Stats {
    Write-Host "Total STIGS Edited:" $STIGS_Done.Count "`n" -ForegroundColor Magenta
    Write-Host "STIGS Edited:`n" $STIGS_Done -ForegroundColor DarkGreen
}

Function Get-Stats1 {
	
    $STIGS_stats = $x.CHECKLIST.STIGS.iSTIG.VULN.STATUS
	$STIGS_Total = $STIGS_stats.count
    $STIGS_AlreadyDone = ($x.CHECKLIST.STIGS.iSTIG.VULN.STATUS | Where-Object {$_ -ne "Not_Reviewed"}).count
    Write-Host "$STIGS_AlreadyDone out of $STIGS_Total completed."
	$STIGS_Table = [pscustomobject]@{
		Open = ($STIGS_stats | Where-Object {$_ -eq "Open"}).count
		NotAFinding = ($STIGS_stats | Where-Object {$_ -eq "NotAFinding"}).count
		NA = ($STIGS_stats | Where-Object {$_ -eq "Not_Applicable"}).count
		NR = ($STIGS_stats | Where-Object {$_ -eq "Not_Reviewed"}).count
	}

	$STIGS_Table | Format-Table | Out-String | Write-Host -ForegroundColor Magenta
}

Function Get-Grid {
	$filetoanalyze = $OutputChecklistDatagrid.SelectedItem.File.ToString()
	write-host $filetoanalyze
	[xml] $y = (Get-Content $filetoanalyze)
	$STIG_IDS = $y.CHECKLIST.STIGS.iSTIG.VULN
	foreach ($STIG_ID in $STIG_IDS) {
		$status = $STIG_ID.STATus
		if ($status -eq "Open") {
			$STIG_Grid += ,[pscustomobject]@{
				STIG_ID = $STIG_ID.STIG_DATA[0].ATTRIBUTE_DATA
				Status = $STIG_ID.STATUS
				Finding_Details = $STIG_ID.Finding_Details
				Fixtext = $STIG_ID.STIG_DATA[9].ATTRIBUTE_DATA
			}
		}
		else {
			$STIG_Grid += ,[pscustomobject]@{
				STIG_ID = $STIG_ID.STIG_DATA[0].ATTRIBUTE_DATA
				Status = $STIG_ID.STATUS
				Finding_Details = $STIG_ID.Finding_Details
				Fixtext = "-"
			}
		}
	}
	$STIG_Grid | Out-GridView
}

Function Get-STIGS {
    $STIG_IDS = $x.CHECKLIST.STIGS.iSTIG.VULN | Where-Object {$_.STATUS -eq "Not_Reviewed"} | ForEach-Object {$_.STIG_DATA[0].Attribute_DATA}
	foreach ($STIG_ID in $STIG_IDS) {
		try {
			$invokestig = $STIG_ID.substring(2)
			#Get-Command Get-$invokestig -ErrorAction STOP
			Invoke-Expression Get-$invokestig -ErrorAction STOP
			#$command = "Get-$invokestig"
			#$command
			#Write-Host "STIG ID $STIG_ID completed"
			$STIGS_Done.Add($STIG_ID)
	
		}
		catch {}
	}
}

Function Get-RegChecks {
    #dynamically checks for any STIG Registry checks. Due to many different formats and possible reults there is a lot of error handling to catch as many of these as possible.
	$reg_STIGS = $x.CHECKLIST.STIGS.iSTIG.VULN | Where-Object {$_.STIG_DATA[8].ATTRIBUTE_DATA -Match "Registry Hive: "} | Where-Object {$_.STATUS -eq "Not_Reviewed"}
	
	foreach ($reg_STIG in $reg_STIGS) {
		$double_reg = $reg_STIG.STIG_DATA[8].ATTRIBUTE_DATA | Select-String -Pattern "Value Name:" -AllMatches
		if ($double_reg.Matches.count -gt 1) {
			Write-Host $reg_STIG.STIG_DATA[0].ATTRIBUTE_DATA "contains multiple reg keys"
		}
		#temporary fix for two legal text registry keys
        	elseif ($reg_STIG.STIG_DATA[8].ATTRIBUTE_DATA -Match "LegalNoticeCaption") {write-host "skipped $($reg_STIG.STIG_DATA[0].ATTRIBUTE_DATA)"}
        	elseif ($reg_STIG.STIG_DATA[8].ATTRIBUTE_DATA -Match "LegalNoticeText") {write-host "skipped $($reg_STIG.STIG_DATA[0].ATTRIBUTE_DATA)"}

		else {
			try {
				$stig_info = $reg_STIG.STIG_DATA[8].ATTRIBUTE_DATA | Select-String -Pattern "Registry Hive:\s*?(\S.*?)`nRegistry Path:\s*?(\S.*?)`n*Value Name:\s*?(\S.*?)`n[`n\s]*?(Value Type|Type):\s*?(\S*?)`nValue( data)?:\s*?(\S.*?)\s*(`n|$)" -ErrorAction STOP
				
				#Set Needed Variables
				if ($stig_info.Matches.groups[1].value -eq "HKEY_LOCAL_MACHINE") {$reg_hive = "HKLM"}
				elseif ($stig_info.Matches.groups[1].value -eq "HKEY_CURRENT_USER") {$reg_hive = "HKCU"}
				$reg_path = $reg_hive + ":" + $stig_info.Matches.groups[2].value
				$value_name = $stig_info.Matches.groups[3].value
				$value_type = $stig_info.Matches.groups[5].value
				#The reg value paramater is very difficult because it contains extra words, contains or, contains a less than or greater, and can even stretch over multiple lines.
				
				$reg_value = $stig_info.Matches.groups[7].value
				#Special Conditionals - Reg Values that contain "OR"
				if ($reg_value -Match "\Wor ") {
					if ($reg_value -Match "or less, excluding [`"]?0") {$Compare_Type = "or less excluding 0"}
					elseif ($reg_value -Match "or less[^,]") {$Compare_Type = "or less"}
					elseif ($reg_value -Match "or greater") {$Compare_Type = "or greater"}
					else {$Compare_Type = "None"}
				}
				else {$Compare_Type = "None"}

				#Strip bad characters from Reg Values that contain the "0x" binary string.
				if ($reg_value -Match "0x") {
					$new_reg = $reg_value | Select-String -Pattern "0x.*? \((.*?)\)"
					$reg_value = $new_reg.Matches.Groups[1].value
				}
				#Strip Parenthesis
				if ($reg_value -Match " \(") {
					$reg_value = $reg_value -Replace " \(.*?\)"
				}
				if ($reg_value -Match "[ ,]or ") {
					$Compare_Type = "value or value"
				}


				Try {
					#Get Results
					$Results = Get-Item -Path $reg_path -ErrorAction STOP
					$results_value = $Results.GetValue($value_name) 
					if (($Results.GetValueKind($value_name)) -eq "DWord") {
						$results_type = "REG_DWORD"
					}
					elseif (($Results.GetValueKind($value_name)) -eq "String") {
						$results_type = "REG_SZ"
					}
					
					#Set Conditionals based on Compare Type
					if ($Compare_Type -eq "or less excluding 0") {
						$Comparitive = ($results_value -le $reg_value) -And ($results_value -ne "0")
						$AntiComparitive = ($results_value -gt $reg_value) -Or ($results_value -eq '0')
					}
					elseif ($Compare_Type -eq "or less") {
						$Comparitive = $results_value -le $reg_value
						$AntiComparitive = $results_value -gt $reg_value
					}
					elseif ($Compare_Type -eq "or greater") {
						$Comparitive = $results_value -ge $reg_value
						$AntiComparitive = $results_value -lt $reg_value
					}					
					elseif ($Compare_Type -eq "value or value") {
						$Comparitive = $reg_value -Match $results_value
						$AntiComparitive = $reg_value -NotMatch $results_value
					}
					else {
						$Comparitive = $results_value -eq $reg_value
						$AntiComparitive = $results_value -ne $reg_value
					}

					#Check conditions
					if ($Comparitive -And ($results_type -eq $value_type)) {
						#write-host $reg_STIG.STIG_DATA[0].ATTRIBUTE_DATA "is compliant"
						$reg_STIG.Finding_Details = "For the registry path $reg_path the value $value_name is $results_type = $results_value. This is not a finding."
						$reg_STIG.Status = "NotAFinding"
					}
					elseif ($AntiComparitive -Or ($results_type -ne $value_type)) {
						#write-host $reg_STIG.STIG_DATA[0].ATTRIBUTE_DATA "is not compliant"
						$reg_STIG.Finding_Details = "For the registry path $reg_path the value $value_name is $results_type = $results_value. This is a finding and the value $value_name should be $value_type = $reg_value"
						$reg_STIG.Status = "Open"
					}
				}
				Catch [System.Management.Automation.MethodInvocationException] {
					if ($stig_info.Matches.groups[7].value -Match "or if the Value Name does not exist") {
						$reg_STIG.Finding_Details = "The Value Name does not exist. This is not a finding."
						$reg_STIG.Status = "NotAFinding"
					}
					elseif ($reg_STIG.STIG_DATA[8].ATTRIBUTE_DATA -Match "If the following registry value does not exist or is not configured as specified, this is a finding.") {
						$reg_STIG.Finding_Details = "The Value Name does not exist. This is a finding."
						$reg_STIG.Status = "Open"
					}
					else {write-host $reg_STIG.STIG_DATA[0].ATTRIBUTE_DATA "value name doesnt exist" $reg_value}
				}
				Catch [System.Management.Automation.ItemNotFoundException] {
					#Write-Host $reg_STIG.STIG_DATA[0].ATTRIBUTE_DATA "regpath doesnt exist"
					if ($reg_STIG.STIG_DATA[8].ATTRIBUTE_DATA -Match "If the following registry value does not exist or is not configured as specified, this is a finding.") {
						$reg_STIG.Finding_Details = "This registry value does not exist."
						$reg_STIG.Status = "Open"
					}
					elseif ($reg_value -Match "or if the Value Name does not exist") {
						$reg_STIG.Finding_Details = "The Value Name does not exist. This is not a finding."
						$reg_STIG.Status = "NotAFinding"
					}
					else {write-host $reg_STIG.STIG_DATA[0].ATTRIBUTE_DATA "this regpath does not exist"}
				}
				catch {write-host "Some Error Occured:" $reg_STIG.STIG_DATA[0].ATTRIBUTE_DATA}
			}
			catch {
				write-host $reg_STIG.STIG_DATA[0].ATTRIBUTE_DATA "is a complicated registry check"
			}
		}
	}
}

Function Get-OtherRegChecks {
    #dynamically checks for any STIG Registry checks from Office STIGS
	$reg_STIGS = $x.CHECKLIST.STIGS.iSTIG.VULN | Where-Object {$_.STIG_DATA[8].ATTRIBUTE_DATA -Match "`n(HKLM|HKCU)"} | Where-Object {$_.STATUS -eq "Not_Reviewed"}
	
	foreach ($reg_STIG in $reg_STIGS) {
		#$reg_STIG.STIG_DATA[0].ATTRIBUTE_DATA
		if ("1" -eq "2") {}
		else {
			try {
				#This is only for REG_DWORD right now.
				$stig_info = $reg_STIG.STIG_DATA[8].ATTRIBUTE_DATA | Select-String -Pattern "`n(HKLM|HKCU)(.*?)`n`nCriteria: If the (value|value of) (\S*?) is (REG_DWORD|REG_SZ) = (\S*?), this is not a finding.(\Z| )" -ErrorAction STOP
				
				#Set Needed Variables
				$Reg_PathPrefix = $stig_info.Matches.groups[1].value
				$Reg_PathSuffix = $stig_info.Matches.Groups[2].value
				$Reg_Path = $Reg_PathPrefix + ":" + $Reg_PathSuffix
				$value_type = $stig_info.Matches.groups[4].value
				$value_name = $stig_info.Matches.groups[5].value
				$Reg_Value = $stig_info.Matches.groups[6].value
				if ($stig_info.Matches.groups[7].value -ne " ") {$StringEnd = $true}
				else {$StringEnd = $false}
				
				Try {
					$Results = Get-Item -Path $reg_path -ErrorAction STOP
					$results_value = $Results.GetValue($value_name) 
					$results_type = $Results.GetValueKind($value_name)
					Write-Host $results_type $value_type
					
					if ($results_value -eq $Reg_Value) {
						write-host $reg_STIG.STIG_DATA[0].ATTRIBUTE_DATA "is compliant"
						$reg_STIG.Finding_Details = "This registry key is set to the value of $results_value. This is not a finding."
						$reg_STIG.Status = "NotAFinding"
					}
					elseif ($results_value -ne $Reg_Value) {
						#write-host $reg_STIG.STIG_DATA[0].ATTRIBUTE_DATA "is not compliant"
						$reg_STIG.Finding_Details = "This registry key is set to the value of $results_value. This is finding and the value should be set to $reg_value."
						if ($StringEnd -eq $true) {
							$reg_STIG.Status = "Open"
						}
					}
				}
				Catch [System.Management.Automation.MethodInvocationException] {
					if ($reg_STIG.STIG_DATA[8].ATTRIBUTE_DATA -Match "does not exist, this is not a finding.") {
						$reg_STIG.Finding_Details = "The Value Name does not exist. This is not a finding."
						$reg_STIG.Status = "NotAFinding"
					}
					else {write-host $reg_STIG.STIG_DATA[0].ATTRIBUTE_DATA "The value name does not exist."}
				}
				Catch [System.Management.Automation.ItemNotFoundException] {
					#Write-Host $reg_STIG.STIG_DATA[0].ATTRIBUTE_DATA "regpath doesnt exist"
					If ($reg_STIG.STIG_DATA[8].ATTRIBUTE_DATA -Match "does not exist, this is not a finding.") {
						$reg_STIG.Finding_Details = "The Value Name does not exist. This is not a finding."
						$reg_STIG.Status = "NotAFinding"
					}
					Else {write-host $reg_STIG.STIG_DATA[0].ATTRIBUTE_DATA "This regpath does not exist"}
				}
				Catch {write-host "Some Error Occured"}
			}
			Catch {
				Write-Host $reg_STIG.STIG_DATA[0].ATTRIBUTE_DATA "was not in the correct format"
			}
		}
	}
}

Function Get-PMChecks {
	$pm_STIGS = $x.CHECKLIST.STIGS.iSTIG.VULN | Where-Object {$_.STIG_DATA[8].ATTRIBUTE_DATA -Match "Get-ProcessMitigation"} | Where-Object {$_.STATUS -eq "Not_Reviewed"}
	foreach ($pm_STIG in $pm_STIGS) {
		#All Possible: DEP ASLR Payload ImageLoad ChildProcess
		#DEP ASLR and Payload
		if ($pm_STIG.STIG_DATA[8].ATTRIBUTE_DATA -Match "Get-ProcessMitigation -Name (.*?.exe)") {
			$pm_info = $pm_STIG.STIG_DATA[8].ATTRIBUTE_DATA
			$pm_processgrab = $pm_STIG.STIG_DATA[8].ATTRIBUTE_DATA | Select-String -Pattern "Get-ProcessMitigation -Name (.*?.exe)."
			$process = $pm_processgrab.Matches.groups[1].value
			$processquery =  Get-ProcessMitigation -Name $process | Out-String
			$dep = $processquery | Select-String "(Override DEP.*?(true|false))" | ForEach-Object {$_.Matches[0].Value}
			#two types of aslr do if then for setting variable
			if ($pm_info -Match "ASLR:`nForceRelocateImages") {
				$aslr = $processquery | Select-String "(ForceRelocateImages.*?(on|off|notset))" | ForEach-Object {$_.Matches[0].Value}
			}
			elseif ($pm_info -Match "ASLR:`nOverrideRelocateImages") {
				$aslr = $processquery | Select-String "(Override RelocateImages.*?(true|false))" | ForEach-Object {$_.Matches[0].Value}
			}
			
			
            $payload = $processquery | Select-String -Pattern "Payload:((\s|.)*?)`nSEHOP" | ForEach-Object {$_.Matches[0].groups[1].value}  | Select-String -Pattern "Override.*(True|False)\s" -AllMatches | foreach-object {$_.Matches.value}
			$imageload = $processquery | Select-String "(Override BlockRemoteImages.*?(true|false))" | ForEach-Object {$_.Matches[0].Value}
			$childprocess = $processquery | Select-String "(Override ChildProcess.*?(true|false))" | ForEach-Object {$_.Matches[0].Value}

            #DEP ASLR ImageLoad Payload and ChildProcess
			if (($pm_info -Match "DEP") -And ($pm_info -Match "ASLR") -And ($pm_info -Match "Payload") -And ($pm_info -Match "ImageLoad") -And ($pm_info -Match "ChildProcess")) {
				if (($dep -Match "False") -And ($aslr -Match "On") -Or ($aslr -Match "False") -And ($payload -NotMatch "True") -And ($payload -Match "False") -And ($imageload -Match "False") -And ($childprocess -Match "False")) {
					$pm_STIG.Finding_Details = "All of these settings are configured correctly. This is not a finding.`nDEP:`n$dep`n`nASLR:`n$aslr`n`nImageLoad:`n$imageload`n`nPayload:`n$payload`n`nChildProcess:`n$childprocess"
					$pm_STIG.Status = "NotAFinding"
				}
				else {
					$pm_STIG.Finding_Details = "Some settings are not configured correctly. This is a finding.`nDEP:`n$dep`n`nASLR:`n$aslr`n`nImageLoad:`n$imageload`n`nPayload:`n$payload`n`nChildProcess:`n$childprocess"
					$pm_STIG.Status = "Open"
				}
			}
			#DEP ASLR ImageLoad and Payload
			if (($pm_info -Match "DEP") -And ($pm_info -Match "ASLR") -And ($pm_info -Match "Payload") -And ($pm_info -Match "ImageLoad") -And ($pm_info -NotMatch "ChildProcess")) {
				if (($dep -Match "False") -And ($aslr -Match "On") -And ($payload -NotMatch "True") -And ($payload -Match "False") -And ($imageload -Match "False")) {
					$pm_STIG.Finding_Details = "All of these settings are configured correctly. This is not a finding.`nDEP:`n$dep`n`nASLR:`n$aslr`n`nImageLoad:`n$imageload`n`nPayload:`n$payload"
					$pm_STIG.Status = "NotAFinding"
				}
				else {
					$pm_STIG.Finding_Details = "Some settings are not configured correctly. This is a finding.`nDEP:`n$dep`n`nASLR:`n$aslr`n`nImageLoad:`n$imageload`n`nPayload:`n$payload"
					$pm_STIG.Status = "Open"
				}
			}
			#DEP ImageLoad Payload and ChildProcess
			if (($pm_info -Match "DEP") -And ($pm_info -NotMatch "ASLR") -And ($pm_info -Match "Payload") -And ($pm_info -Match "ImageLoad") -And ($pm_info -Match "ChildProcess")) {
				if (($dep -Match "False") -And ($payload -NotMatch "True") -And ($payload -Match "False") -And ($imageload -Match "False") -And ($childprocess -Match "False")) {
					$pm_STIG.Finding_Details = "All of these settings are configured correctly. This is not a finding.`nDEP:`n$dep`n`nImageLoad:`n$imageload`n`nPayload:`n$payload`n`nChildProcess:`n$childprocess"
					$pm_STIG.Status = "NotAFinding"
				}
				else {
					$pm_STIG.Finding_Details = "Some settings are not configured correctly. This is a finding.`nDEP:`n$dep`n`nImageLoad:`n$imageload`n`nPayload:`n$payload`n`nChildProcess:`n$childprocess"
					$pm_STIG.Status = "Open"
				}
			}
			#DEP ASLR and Payload
			elseif (($pm_info -Match "DEP") -And ($pm_info -Match "ASLR") -And ($pm_info -Match "Payload") -And ($pm_info -NotMatch "ImageLoad") -And ($pm_info -NotMatch "ChildProcess")) {
				if (($dep -Match "False") -And ($aslr -Match "On") -And ($payload -NotMatch "True") -And ($payload -Match "False")) {
					$pm_STIG.Finding_Details = "All of these settings are configured correctly. This is not a finding.`nDEP:`n$dep`n`nASLR:`n$aslr`n`nPayload:`n$payload"
					$pm_STIG.Status = "NotAFinding"
				}
				else {
					$pm_STIG.Finding_Details = "Some settings are not configured correctly. This is a finding.`nDEP:`n$dep`n`nASLR:`n$aslr`n`nPayload:`n$payload"
					$pm_STIG.Status = "Open"
				}
			}
			#DEP and Payload
			elseif (($pm_info -Match "DEP") -And ($pm_info -NotMatch "ASLR") -And ($pm_info -Match "Payload") -And ($pm_info -NotMatch "ImageLoad") -And ($pm_info -NotMatch "ChildProcess")) {
				if (($dep -Match "False") -And ($payload -NotMatch "True") -And ($payload -Match "False")) {
					$pm_STIG.Finding_Details = "All of these settings are configured correctly. This is not a finding.`nDEP:`n$dep`n`nPayload:`n$payload"
					$pm_STIG.Status = "NotAFinding"
				}
				else {
					$pm_STIG.Finding_Details = "Some settings are not configured correctly. This is a finding.`nDEP:`n$dep`n`nPayload:`n$payload"
					$pm_STIG.Status = "Open"
				}
			}
			#DEP and ASLR
			elseif (($pm_info -Match "DEP") -And ($pm_info -Match "ASLR") -And ($pm_info -NotMatch "Payload") -And ($pm_info -NotMatch "ImageLoad") -And ($pm_info -NotMatch "ChildProcess")) {
				if (($dep -Match "False") -And ($aslr -Match "On")) {
					$pm_STIG.Finding_Details = "All of these settings are configured correctly. This is not a finding.`nDEP:`n$dep`n`nASLR:`n$aslr"
					$pm_STIG.Status = "NotAFinding"
				}
				else {
					$pm_STIG.Finding_Details = "Some settings are not configured correctly. This is a finding.`nDEP:`n$dep`n`nASLR:`n$aslr"
					$pm_STIG.Status = "Open"
				}
			}
			#DEP
			elseif (($pm_info -Match "DEP") -And ($pm_info -NotMatch "ASLR") -And ($pm_info -NotMatch "Payload") -And ($pm_info -NotMatch "ImageLoad") -And ($pm_info -NotMatch "ChildProcess")) {
				if ($dep -Match "False") {
					$pm_STIG.Finding_Details = "All of these settings are configured correctly. This is not a finding.`nDEP:`n$dep"
					$pm_STIG.Status = "NotAFinding"
				}
				else {
					$pm_STIG.Finding_Details = "Some settings are not configured correctly. This is a finding.`nDEP:`n$dep"
					$pm_STIG.Status = "Open"
				}
			}
		}
		elseif ($pm_STIG.STIG_DATA[8].ATTRIBUTE_DATA -Match "Get-ProcessMitigation -System") {
			$pm_info = $pm_STIG.STIG_DATA[8].ATTRIBUTE_DATA
			$processquery =  Get-ProcessMitigation -System | Out-String
			$dep = $processquery | Select-String "DEP:\s*?(Enable.*?(ON|OFF|NOTSET))" | ForEach-Object {$_.Matches[0].groups[1].Value}
			$aslr = $processquery | Select-String "(BottomUp.*?(ON|OFF|NOTSET))" | ForEach-Object {$_.Matches[0].Value}
			$cfg = $processquery | Select-String "CFG:\s*?(Enable.*?(ON|OFF|NOTSET))" | ForEach-Object {$_.Matches[0].groups[1].Value}
			$sehop = $processquery | Select-String "SEHOP:\s*?(Enable.*?(ON|OFF|NOTSET))" | ForEach-Object {$_.Matches[0].groups[1].Value}
			$heap = $processquery | Select-String "(TerminateOnError.*?(ON|OFF|NOTSET))" | ForEach-Object {$_.Matches[0].Value}

			if ($pm_info -Match "DEP") {
				if (($dep -Match "ON") -OR ($dep -Match "NOTSET")) {
					$pm_STIG.Finding_Details = "This setting is configured correctly. This is not a finding.`nResults: $dep"
					$pm_STIG.Status = "NotAFinding"
				}
				elseif ($dep -Match "OFF") {
					$pm_STIG.Finding_Details = "This setting is not configured correctly. This is a finding.`nResults: $dep"
					$pm_STIG.Status = "Open"
				}
			}
			elseif ($pm_info -Match "ASLR") {
				if (($aslr -Match "ON") -OR ($aslr -Match "NOTSET")) {
					$pm_STIG.Finding_Details = "This setting is configured correctly. This is not a finding.`nResults: $aslr"
					$pm_STIG.Status = "NotAFinding"
				}
				elseif ($aslr -Match "OFF") {
					$pm_STIG.Finding_Details = "This setting is not configured correctly. This is a finding.`nResults: $aslr"
					$pm_STIG.Status = "Open"
				}
			}
			elseif ($pm_info -Match "CFG") {
				if (($cfg -Match "ON") -OR ($cfg -Match "NOTSET")) {
					$pm_STIG.Finding_Details = "This setting is configured correctly. This is not a finding.`nResults: $cfg"
					$pm_STIG.Status = "NotAFinding"
				}
				elseif ($cfg -Match "OFF") {
					$pm_STIG.Finding_Details = "This setting is not configured correctly. This is a finding.`nResults: $cfg"
					$pm_STIG.Status = "Open"
				}
			}
			elseif ($pm_info -Match "SEHOP") {
				if (($sehop -Match "ON") -OR ($sehop -Match "NOTSET")) {
					$pm_STIG.Finding_Details = "This setting is configured correctly. This is not a finding.`nResults: $sehop"
					$pm_STIG.Status = "NotAFinding"
				}
				elseif ($sehop -Match "OFF") {
					$pm_STIG.Finding_Details = "This setting is not configured correctly. This is a finding.`nResults: $sehop"
					$pm_STIG.Status = "Open"
				}
			}
			elseif ($pm_info -Match "HEAP") {
				if (($heap -Match "ON") -OR ($heap -Match "NOTSET")) {
					$pm_STIG.Finding_Details = "This setting is configured correctly. This is not a finding.`nResults: $heap"
					$pm_STIG.Status = "NotAFinding"
				}
				elseif ($heap -Match "OFF") {
					$pm_STIG.Finding_Details = "This setting is not configured correctly. This is a finding.`nResults: $heap"
					$pm_STIG.Status = "Open"
				}
			}
		}
	}
}

Function Get-AuditChecks {
	$audit_STIGS = $x.CHECKLIST.STIGS.iSTIG.VULN | Where-Object {$_.STIG_DATA[8].ATTRIBUTE_DATA -Match "AuditPol /get"} | Where-Object {$_.STATUS -eq "Not_Reviewed"}
	foreach ($audit_STIG in $audit_STIGS) {
	    try {
			$stig_info = $audit_STIG.STIG_DATA[8].ATTRIBUTE_DATA | Select-String -Pattern "(If the system does not audit the following, this is a finding.|Compare the AuditPol settings with the following.)`n`n(.*?) >> (.*?) - (.*)" -ErrorAction STOP
			$query = $stig_info.Matches.groups[3].value
			$setting = $stig_info.Matches.groups[4].value
			$Results = AuditPol /get /subcategory:$query | Out-String
	    	if ($Results -Match $setting) {
		    	$audit_STIG.Finding_Details = "The system does audit $query $setting events. See results below:`n$Results"
			    $audit_STIG.Status = "NotAFinding"
		    }
		    elseif ($Results -NotMatch $stig_info.Matches.groups[4].value) {
		        $audit_STIG.Finding_Details = "The system does not audit $query $setting events. See results below:`n$Results"
				$audit_STIG.Status = "Open"
			}
		}
		catch {write-host "Error with Audit check ID " $audit_STIG.STIG_DATA[0].ATTRIBUTE_DATA}
	}
}

Function Get-SeceditChecks {
	$Secedit_STIGS = $x.CHECKLIST.STIGS.iSTIG.VULN | Where-Object {$_.STIG_DATA[8].ATTRIBUTE_DATA -Match "User Rights Assignment"} | Where-Object {$_.STATUS -eq "Not_Reviewed"}
	$SECEDIT_File = "./sec.inf"
	SecEdit.exe /export /cfg $SECEDIT_File

	
	$SE_Privilege = @{
		"Act as part of the operating system"								=		'SeTcbPrivilege';
		"Access Credential Manager as a trusted caller"						=		'SeTrustedCredManAccessPrivilege';
		"Create a token object"												=		'SeCreateTokenPrivilege';
		"Create permanent shared objects"									=		'SeCreatePermanentPrivilege';
		"Enable computer and user accounts to be trusted for delegation"	=		'SeEnableDelegationPrivilege';
		"Lock pages in memory"												=		'SeLockMemoryPrivilege';
		"Access this computer from the network"								=		'SeNetworkLogonRight';
		"Allow log on locally"												=		'SeInteractiveLogonRight';
		"Back up files and directories"										=		'SeBackupPrivilege';
		"Change the system time"											=		'SeSystemtimePrivilege';
		"Create a pagefile"													=		'SeCreatePagefilePrivilege';
		"Create global objects"												=		'SeCreateGlobalPrivilege';
		"Create symbolic links"												=		'SeCreateSymbolicLinkPrivilege';
		"Debug Programs"													=		'SeDebugPrivilege';
		"Force shutdown from a remote system"								=		'SeRemoteShutdownPrivilege';
		"Impersonate a client after authentication"							=		'SeImpersonatePrivilege';
		"Load and unload device drivers"									=		'SeLoadDriverPrivilege';
		"Manage auditing and security log"									=		'SeSecurityPrivilege';
		"Modify firmware environment values"								=		'SeSystemEnvironmentPrivilege';
		"Perform volume maintenance tasks"									=		'SeManageVolumePrivilege';
		"Profile single process"											=		'SeProfileSingleProcessPrivilege';
		"Restore files and directories"										=		'SeRestorePrivilege';
		"Take ownership of files or other objects"							=		'SeTakeOwnershipPrivilege'


	}

	foreach ($Secedit_STIG in $Secedit_STIGS) {
		$useraccounts = @()
		
		try {
			$stig_info = $Secedit_STIG.STIG_DATA[8].ATTRIBUTE_DATA | Select-String -Pattern "If any groups or accounts (\(to include administrators\), )?(other than the following |)are granted the `"(.*?)`" user right, this is a finding.(`n`n([\w\n\\ ]*?)( is|$|`n`n)|)" -ErrorAction STOP
			$query = $stig_info.Matches.Groups[2].Value
			$user_right = $stig_info.Matches.Groups[3].Value
			$groupsoraccounts = $stig_info.Matches.Groups[5].Value
			$grouplist = $groupsoraccounts.split("`r`n|`n|`r")
			$grouplist -Match ".*\\.*" | ForEach-Object {$grouplist = $grouplist -replace "$($_.split('\')[0] + `"\\`" + $_.split('\')[1])", $_.split('\')[1]}

			#write-host $grouplist
			if ($null -eq $SE_Privilege.$user_right) {
				write-host "This privilege $user_right does not exist in the hashtable yet."
				Throw
			}
			
			if ($query -eq "") {
				#write-host $SE_Privilege.$user_right
				$Results = Get-Content $SECEDIT_File | Where-Object {$_ -Match "$($SE_Privilege.$user_right)"} | Select-String -Pattern "/*S-[\d-]*" -AllMatches
				if ($null -eq $Results) {
					#Write-Host "No groups or accounts have been granted the `"$user_right`" user right. This is not a finding."
					$Secedit_STIG.Finding_Details = "No groups or accounts have been granted the `"$user_right`" user right. This is not a finding."
					$Secedit_STIG.Status = "NotAFinding"
				}
				else {
					$Results.Matches.Value | ForEach-Object {
						try {$useraccounts += (New-Object System.Security.Principal.SecurityIdentifier($_)).Translate([System.Security.Principal.NTAccount]).value}
						catch {$useraccounts += $Results.Matches.Value}
					}
					#write-host "One or more group or account hase been given the `"$user_right`" user right. This is a finding. The groups or accounts given the user right are the following:`n$useraccounts"
					$Secedit_STIG.Finding_Details = "One or more group or account hase been given the `"$user_right`" user right. This is a finding. The groups or accounts given the user right are the following:`n$useraccounts"
					$Secedit_STIG.Status = "Open"
				}

			}
			elseif ($query -eq "other than the following ") {
				#write-host "Required Group Accounts:`n$grouplist"
				$Results = Get-Content $SECEDIT_File | Where-Object {$_ -Match "$($SE_Privilege.$user_right)"} | Select-String -Pattern "/*S-[\d-]*" -AllMatches
				$Results.Matches.Value | ForEach-Object {
					try {$useraccounts += ((New-Object System.Security.Principal.SecurityIdentifier($_)).Translate([System.Security.Principal.NTAccount]).value).split("\")[1]}
					catch {$useraccounts += $Results.Matches.Value}
				}
				#Write-Host "Actual Group Accounts:`n" $useraccounts
				$Comparison = Compare-Object -ReferenceObject $grouplist -DifferenceObject $useraccounts -IncludeEqual
				if ($Comparison -Match "=>") {
					write-host $Comparison
					$Added_Groups = $Comparison | Where-Object SideIndicator -eq "=>" | Select-Object InputObject
					$Secedit_STIG.Finding_Details = "Groups or accounts other than the accounts stated above have been granted the `"$user_right`" user right, this is a finding. The groups or accounts given the user right that should not have this right are the following:`n$Added_Groups`nAll groups or accounts given the user right:`n$useraccounts"
					$Secedit_STIG.Status = "Open"
				}
				elseif (($Comparison -Match "==") -Or ($Comparison -Match "<=") -And ($Comparison -NotMatch "=>")) {
					$Secedit_STIG.Finding_Details = "No other groups or accounts besides the groups and accounts named above are granted the `"$user_right`" user right. This is not a finding.`nThe groups or accounts given the user right are the following:`n$useraccounts"
					$Secedit_STIG.Status = "NotAFinding"
				}
			}
			else {write-host "case 3"}
		}
		catch {write-host "Error with secedit check ID " $Secedit_STIG.STIG_DATA[0].ATTRIBUTE_DATA}
	}
	Remove-Item $Secedit_File
}

Function Get-GPOChecks {
	$GPO_STIGS = $x.CHECKLIST.STIGS.iSTIG.VULN | Where-Object {$_.STIG_DATA[8].ATTRIBUTE_DATA -Match "Security Settings"} | Where-Object {$_.STATUS -eq "Not_Reviewed"}
	$SECEDIT_File = "./sec.inf"
	SecEdit.exe /export /cfg $SECEDIT_File
	foreach ($PasswordPolicy_STIG in $GPO_STIGS) {
		$System_Access = @{
			"Enforce password history"											=		'PasswordHistorySize';
			"Maximum password age"												=		'MaximumPasswordAge';
			"Minimum password age"												=		'MinimumPasswordAge';
			"Minimum password length"											=		'MinimumPasswordLength';
			"Password must meet complexity requirements"						=		'PasswordComplexity';
			"Store password using reversible encryption"						=		'ClearTextPassword';
			"Accounts: Rename administrator account"							=		'NewAdministratorName';
			"Accounts: Rename guest account"									=		'NewGuestName';
			"Accounts: Administrator account status"							=		'EnableAdminAccount';
			"Accounts: Guest account status"									=		'EnableGuestAccount';
			"Network access: Allow anonymous SID/Name translation"				=		'LSAAnonymousNameLookup';
			#These last three have some problems. Only one works right now and two of them do not always exist.
			"Account lockout duration"											=		'LockoutDuration';
			"Account lockout threshold"											=		'LockoutBadCount';
			"Reset account lockout counter after"								=		'ResetLockoutCount'
		}
		
		try {
			$stig_info = $PasswordPolicy_STIG.STIG_DATA[8].ATTRIBUTE_DATA | Select-String -Pattern "If the (value for )?(the |)`"(.*?),?`" (value )?(is set to|is not set to|is less than|is greater than) `"(\w*?)`".*?, this is a finding." -ErrorAction STOP
			$setting = $stig_info.Matches.Groups[3].Value
			$comparer = $stig_info.Matches.Groups[5].Value
			$value = $stig_info.Matches.Groups[6].Value
			if ($null -eq $System_Access.$setting) {
				write-host "This setting, $setting does not exist in the hashtable yet."
				Throw
			}
			#This regex does not match items that are comprised of letters. This needs to be fixed.
			$Results = Get-Content $SECEDIT_File | Where-Object {$_ -Match "$($System_Access.$setting)"} | Select-String -Pattern "= `"?([0-9]+|\w+)`"?" -ErrorAction STOP
			$Results_Value = $Results.Matches.Groups[1].Value
			if ($comparer -eq "is less than") {
				if ($Results_Value -lt $value) {
					$PasswordPolicy_STIG.Finding_Details = "The value for `"$setting`" is $Results_value which is less than $value. This is a finding."
					$PasswordPolicy_STIG.Status = "Open"
				}
				elseif (($Results_Value -gt $value) -Or ($Results_Value -eq $value)) {
					$PasswordPolicy_STIG.Finding_Details = "The value for `"$setting`" is $Results_value which is not less than $value. This is not a finding."
					$PasswordPolicy_STIG.Status = "NotAFinding"
				}
				else {write-host "error less than"}
			}
			elseif ($comparer -eq "is greater than") {
				if ($Results_Value -gt $value) {
					$PasswordPolicy_STIG.Finding_Details = "The value for `"$setting`" is $Results_value which is greater than $value. This is a finding."
					$PasswordPolicy_STIG.Status = "Open"
				}
				elseif (($Results_Value -lt $value) -Or ($Results_Value -eq $value)) {
					$PasswordPolicy_STIG.Finding_Details = "The value for `"$setting`" is $Results_value which is not greater than $value. This is not a finding."
					$PasswordPolicy_STIG.Status = "NotAFinding"
				}
				else {write-host "error greater than"}
			}
			elseif ($comparer -eq "is not set to") {
				if ($Results_Value -eq 1) {$Results_Value_Name = "Enabled"}
				if ($Results_Value -eq 0) {$Results_Value_Name = "Disabled"}
				else {$Results_Value_Name = $Results_Value}
				if ($Results_Value_Name -eq $value) {
					$PasswordPolicy_STIG.Finding_Details = "The value for `"$setting`" is set to $Results_Value_Name. This is not a finding."
					$PasswordPolicy_STIG.Status = "NotAFinding"
				}
				elseif ($Results_Value_Name -ne $value) {
					$PasswordPolicy_STIG.Finding_Details = "The value for `"$setting`" is not set to $value but is set to $Results_Value_Name. This is a finding."
					$PasswordPolicy_STIG.Status = "Open"
				}
				else {write-host "enabled disabled error"}
			}
			elseif ($comparer -eq "is set to") {
				if ($Results_Value -eq 1) {$Results_Value_Name = "Enabled"}
				if ($Results_Value -eq 0) {$Results_Value_Name = "Disabled"}
				else {$Results_Value_Name = $Results_Value}
				write-host $PasswordPolicy_STIG.STIG_DATA[0].ATTRIBUTE_DATA
				if ($Results_Value_Name -eq $value) {
					$PasswordPolicy_STIG.Finding_Details = "The value for `"$setting`" is set to $Results_Value_Name. This is a finding."
					$PasswordPolicy_STIG.Status = "Open"
				}
				elseif ($Results_Value_Name -ne $value) {
					$PasswordPolicy_STIG.Finding_Details = "The value for `"$setting`" is not set to $value but is set to $Results_Value_Name. This is not a finding."
					$PasswordPolicy_STIG.Status = "NotAFinding"
				}
				else {write-host "enabled disabled error"}
			}

		}
		catch {write-host "Error with Password Policy STIG ID " $PasswordPolicy_STIG.STIG_DATA[0].ATTRIBUTE_DATA}
	}
	Remove-Item $Secedit_File
}


Function Get-Win10Features {
	$Feature_STIGS = $x.CHECKLIST.STIGS.iSTIG.VULN | Where-Object {$_.STIG_DATA[8].ATTRIBUTE_DATA -Match "Verify it has not been installed"} | Where-Object {$_.STATUS -eq "Not_Reviewed"}

	$resultsquery = Get-WindowsOptionalFeature -Online -FeatureName *

	foreach ($Feature_STIG in $Feature_STIGS) {
		try {
			$stig_info = $Feature_STIG.STIG_DATA[8].ATTRIBUTE_DATA | Select-String -Pattern "^((\w*?)|(The )?`"(.*?)`") is not installed by default.  Verify it has not been installed." -ErrorAction STOP
			$feature = $stig_info.Matches.Groups[4].Value
			if ($feature -eq "") {$feature = $stig_info.Matches.Groups[2].Value}
			if ($feature -eq "Simple TCP/IP Services") {$feature = "Simple TCPIP services (i.e. echo, daytime etc)"}
			$featurestate = $resultsquery | Where-Object DisplayName -eq $feature | Format-Table DisplayName,State | Out-String
			
			if ($featurestate -Match "Disabled") {
				$Feature_STIG.Finding_Details = "The feature $feature is not installed, this is not a finding. See results below:`n$featurestate"
				$Feature_STIG.Status = "NotAFinding"
			}
			elseif ($featurestate -Match "Enabled") {
				$Feature_STIG.Finding_Details = "The feature $feature is installed. This is a finding. See results below:`n$featurestate"
				$Feature_STIG.Status = "Open"
			}
			else {
				write-host "It appears that he following feature $feature, didn't show up as enabled or disabled."
			}
		}
		catch {write-host "Win10-Feature Error with" $Feature_STIG.STIG_DATA[0].ATTRIBUTE_DATA}
	}
}

Function Measure-Compliance {
	#Setting Global Variables For Script
	#Copying checklist; opening up copied checklist in XML format
	$Path = (Get-Item -Path ".\").FullName

	#Input File
	if ($null -eq $InputFile) {
		#try {$InputFile = $InputChecklist.SelectedItem.ToString()}
		try {$InputFile = $InputChecklistDatagrid.SelectedItem.File.ToString()}
		catch {
			Get-ChildItem | Where-Object {$_ -Match ".ckl"} 
			$RelativeFile = Read-Host "Please pick a STIG checklist to work on in the current directory"
			$InputFile = Join-Path $Path $RelativeFile
		}	
	}
	else {$InputFile = Join-Path $Path $RelativeFile}


	#Output File
	$datestamp = get-date -format yyyy_MM_dd_HH-mm-ss
	$OutputFile= $InputFile -replace ".ckl","_output_$datestamp.ckl"

	Copy-Item $InputFile -Destination $OutputFile
	#Open copied file in XML mode with UTF encoding
	$x = [xml] (Get-Content $OutputFile -Encoding UTF8)
	#Preserve whitespace from old XML file. (Keeps Pretty Printing)
	$x.PreserveWhitespace = $true


	$STIGS_Done = New-Object System.Collections.Generic.List[string]

	
	#$ScanOutput.AppendText = "Scan started...`n"
	#Run Stats1 Table
	Get-Stats1
	#Run Standalone NA checks.
	Get-NAStandalone
	#Run DC-Checks to find NA STIGS - Only doing NA for member servers. 20% done.
	Get-NAMSChecks
	#Bluetooth NA Checks
	Get-NABluetooth
	#Loop through all STIGS IDS that are not completed. - This function takes a long time. I wonder if there is a way to speed it up.
	Get-STIGS
	#Get log permissions STIGS. (Application, Security, and System)
	Get-LogPermissions
	#Process Mitigation Checks (mainly Win 10) - Just need to do Java 1 off piece. Eventually we sould rewrite this program. 90% Done 
	Get-PMChecks
	#Registry Checks - Some registry keys are skipped. 70% done.
	Get-RegChecks
	#Get Other Reg Checks - Word
	Get-OtherRegChecks
	#Secedit - Log of problems here.
	Get-SeceditChecks
	#Windows 10 Optional Features
	Get-Win10Features
	#GPO Checks - Lot of Problems Here.
	Get-GPOChecks
	#Audit Checks - 80% Done - Results need to be looked over. - Security Option Needs to be set to force (see STIGS)
	Get-AuditChecks
	#Run Stats1 Table Again
	Get-Stats1
	$STIG_ID = $x.checklist.stigs.istig.stig_info.si_data.sid_data[3]
	$STIG_V = $x.checklist.stigs.istig.stig_info.si_data.sid_data[0]
	$STIG_R = (($x.CHECKLIST.STIGS.iSTIG.STIG_INFO.SI_DATA.SID_DATA[6]).replace("Release: ","R")).replace("Benchmark Date: ","- ")
	$STIG_Version = $STIG_V + $STIG_R
	$Open = ($x.CHECKLIST.STIGS.iSTIG.VULN.STATUS | Where-Object {$_ -eq "Open"}).count
	$NotAFinding = ($x.CHECKLIST.STIGS.iSTIG.VULN.STATUS | Where-Object {$_ -eq "NotAFinding"}).count
	$NA = ($x.CHECKLIST.STIGS.iSTIG.VULN.STATUS | Where-Object {$_ -eq "Not_Applicable"}).count
	$NR = ($x.CHECKLIST.STIGS.iSTIG.VULN.STATUS | Where-Object {$_ -eq "Not_Reviewed"}).count
	#Write changes to file
	Save-Changes
	#Add new file to GUI Drop Down
	$OutputChecklistDatagrid.AddChild([pscustomobject]@{File=$OutputFile;STIG_ID=$STIG_ID;STIG_Version=$STIG_Version;Open=$Open;NotAFinding=$NotAFinding;Not_Applicable=$NA;NR=$NR})
	#$OutputChecklist.Items.Add($OutputFile)
	#Print stats including what STIG IDs were changed.
	Get-Stats
}


#-------------------------------------------------------------#
#----Display GUI----------------------------------------------#
#-------------------------------------------------------------#

$Window = [Windows.Markup.XamlReader]::Parse($Xaml)

[xml]$xml = $Xaml

$xml.SelectNodes("//*[@Name]") | ForEach-Object { Set-Variable -Name $_.Name -Value $Window.FindName($_.Name) }


#GUI Buttons and Functionality
$ImportCKLFiles.Add_Click({ Get-CKLFiles })
$AutomateSTIGChecks.Add_Click({ Measure-Compliance })
$GetGrid.Add_Click({ Get-Grid })
$SystemType.Content = "OS: $OperatingSystem`nDomain Role: $OS`nHostname:     $env:COMPUTERNAME`nCurrent User: $env:USERNAME"

$Window.ShowDialog()
