**What is StigSlayer?**

StigSlayer is a PowerShell tool that can be used to help conduct DISA STIG compliance checklists. Given a STIG Checklist, StigSlayer will assess that current Operating System or Software by automating the various STIG checks and will produce an output checklist with the results of the checks. Not only will the output checklist mark checked items as "Compliant", "Not Applicable", "Not a Finding", or "Open" but in many cases will also provide the results that led to that decision.

**Motive**

Initially my goal was to simply create a PowerShell script to automate the security checks that SCC (Security Compliance Checker aka SCAP Scanner) failed to check. SCC currently scans 210 of 287, or 73%, of the Windows 10 checks. After putting together some PowerShell code to automate the neglected security checks I realized that I should make the jump to completely replacing SCC; StigSlayer was born. By replacing SCC not only could I automate more of the STIG checks, but I could also customize the "Finding Details." Instead of simply saying Pass or Fail, StigSlayer will in most cases produce the actual data the script used to determine if the check is a Pass or Fail. This feature is not only useful for the auditor but also can be very helpful for whoever needs to fix the Open findings.

**Effectiveness**

Currently StigSlayer automates around 30 to 40 more checks on Windows 10 than SCC. If we take 35 as the average that means StigSlayer automates 245 of 287, or 85%, of the Windows 10 checks. However, this doesn't mean you should throw SCC away. You can actually get the maximum amount of checks automated by using both tools in tandem. Using SCC and and StigSlayer together I was able to automate 261 of 287, or 91%, of the Windows 10 checks. While this isn't 100%, if you think about it 91% is a perfect score for an underachieving "A" student.

**Using StigSlayer**

_Opening StigSlayer:_

StigSlayer is a single PowerShell file and does not have any dependencies since PowerShell is installed on all Windows systems. Many of the checks require local administrator privileges, however it is possible to also run the tool as a normal user as well. After downloading StigSlayer.ps1 you can simply right click on the file and then select "Run with PowerShell". A PowerShell console will pop-up and ask you if you want to elevate to administrator privileges or not. After typing "yes" or "no" the StigSlayer GUI will open.

_Automating a Checklist:_

StigSlayer uses .ckl as the input checklist files. These .ckl files can be created using STIG Viewer or some can be found in this repository. After you have your .ckl files you can simply click the "Import CKL Files" in the top left-hand corner to import those .ckl files. After uploading the .ckl files select one of the files from the "STIC Checklist Input Files" list and click "Start Checklist Automation". When running on my computer StigSlayer took around 35 seconds to complete the checklist automation. If your curious if anything is happening, you can always click on the blue PowerShell console to see if it is in fact running. After the automation has completed you can select that checklist from the "STIG Checklist Output Files" list and click "View Results" to view the results.

**To Do List**

- [ ] Adding functionality to create a .ckl from a xccdf file. (Currently STIG Viewer needs to be used.)
- [ ] Optimizing StigSlayer for Server 2016
- [ ] Optimizing StigSlayer for Server 2019
- [ ] Allow StigSlayer to run against a remote system.