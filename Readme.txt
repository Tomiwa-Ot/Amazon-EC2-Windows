History

Changes in latest
===============
- Added telemetry
- Added shortcut to settings UI
- Formatted PowerShell scripts
- Fixed bug that shutdown does not wait for BeforeSysprep.cmd to complete

Changes in 1.3.2003411
===============
- Changed password generation logic to exclude passwords with low complexity

Changes in 1.3.2003364
===============
- Update Install-EgpuManager with IMDS V2 support

Changes in 1.3.2003312
===============
- Added log lines before and after setting monitor always on
- Added AWS Nitro enclaves package version to console log

Changes in 1.3.2003284
===============
- Improved permission model by updating location for storing user data to LocalAppData

Changes in 1.3.2003236
===============
- Update method for setting user password in Set-AdminAccount and Randomize-LocalAdminPassword
- Fix InitializeDisks to check if disk is set to read only before setting it to writable

Changes in 1.3.2003210
===============
- Localization fix for install.ps1

Changes in 1.3.2003205
================
- Security fix for install.ps1 to update permissions on %ProgramData%\Amazon\EC2-Windows\Launch\Module\Scripts directory

Changes in 1.3.2003189
================
- Add w32tm resync after adding routes

Changes in 1.3.2003155
================
- Update instance types information

Changes in 1.3.2003150
================
- Add OsCurrentBuild and OsReleaseId to console output 

Changes in 1.3.2003040
================
- Fixed IMDS V1 fallback logic

Changes in 1.3.2002730
================
- Add support for IMDS V2

Changes in 1.3.2002240
================
- Fixed minor issues.

Changes in 1.3.2001660
================
- Fixed automatic login issue of passwordless user after first time of executing Sysprep.

Changes in 1.3.2001360
================
- Fixed minor issues.

Changes in 1.3.2001220
================
- All PowerShell scripts are signed.

Changes in 1.3.2001200
================
- Fix issue with InitializeDisks.ps1 where running the script on a node in a Microsoft Windows Server Failover Cluster would format drives on remote nodes whose drive letter matches the local drive letter

Changes in 1.3.2001160
================
- Fix missing wallpaper on Windows 2019

Changes in 1.3.2001040
================
- Add plugin for setting the monitor to never turn off to fix acpi issues
- Write sql server edition and version to console

Changes in 1.3.2000930
===============
- Fix for adding routes to metadata on ipv6 enabled ENIs

Changes in 1.3.2000760
================
- Add default configuration for RSS and Receive Queue settings for ENA devices
- Disable hibernation during sysprep

Changes in 1.3.2000630.0
================
- Added route 169.254.169.253/32 for DNS server
- Added filter of setting Admin user
- Improvements made to instance hibernation
- Added option to schedule EC2Launch to run on every boot

Changes in 1.3.2000430.0 
================
- Added route 169.254.169.123/32 to AMZN time service
- Added route 169.254.169.249/32 to GRID license service
- Added timeout of 25 seconds when attempting to start SSM

Changes in 1.3.200039.0
================
- Fix improper drive lettering for EBS NVME volumes
- Added additional logging for NVME driver versions

Changes in 1.3.2000080
================

Changes in 1.3.610
================
- Fixed issue with redirecting output and errors to files from user data.

Changes in 1.3.590
================
- Added missing instances types in the wallpaper.
- Fixed an issue with drive letter mapping and disk installation.

Changes in 1.3.580
================
- Fixed Get-Metadata to use the default system proxy settings for web requests.
- Added a special case for NVMe in disk initialization.
- Fixed minor issues.

Changes in 1.3.550
================
- Added a -NoShutdown option to enable Sysprep with no shutdown.

Changes in 1.3.540
================
- Fixed minor issues.

Changes in 1.3.530
================
- Fixed minor issues.

Changes in 1.3.521
================
- Fixed minor issues.

Changes in 1.3.0
================
- Fixed a hexadecimal length issue for computer name change.
- Fixed a possible reboot loop for computer name change.
- Fixed an issue in wallpaper setup.

Changes in 1.2.0
================
- Update to display information about installed operating system (OS) in EC2 system log.
- Update to display EC2Launch and SSM Agent version in EC2 system log.
- Fixed minor issues.

Changes in 1.1.2
================
- Update to display ENA driver information in EC2 system log.
- Update to exclude Hyper-V from primary NIC filter logic.
- Added KMS server and port into registry key for KMS activation.
- Improved wallpaper setup for multiple users.
- Update to clear routes from persistent store.
- Update to remove the z from availability zone in DNS suffix list.
- Update to address an issue with the <runAsLocalSystem> tag in user data.

Changes in 1.1.1
================
- Initial release.
