# Copyright 2016 Amazon.com, Inc. or its affiliates. All Rights Reserved.
#
# Licensed under the Amazon Software License (the "License").
# You may not use this file except in compliance with the License.
# A copy of the License is located at
#
# http://aws.amazon.com/asl/
#
# or in the "license" file accompanying this file. This file is distributed
# on an "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either
# express or implied. See the License for the specific language governing
# permissions and limitations under the License.

<#-----------------------------------------------------------------------------------------------------------
    Set-Wallpaper sets the instance information on current wallpaper.
    If not wallpaper is set, it creates one with custom color.
-------------------------------------------------------------------------------------------------------------#>
function Set-Wallpaper
{
  param(
    [Parameter(Position = 0)]
    [switch]$Initial
  )

  if (Test-NanoServer)
  {
    return
  }

  # Import the wallpaper util methods.
  Import-WallpaperUtil

  # Keep both original wallpaper and modified wallpaper in the following directories.
  $originalWallpaperPath = Join-Path $env:LOCALAPPDATA -ChildPath $script:originalWallpaperName
  $customWallpaperPath = Join-Path $env:LOCALAPPDATA -ChildPath $script:customWallpaperName

  # Get the current wallpaper path.
  $currentWallpaperPath = [WallpaperUtil.Helper]::GetWallpaper()

  # This is the initial wallpaper setting prepration at first time boot for the current user.
  if ($Initial)
  {
    # If wallpaper is still set to old custom wallpaper path, set it to original wallpaper.
    # This is a scenario for user profiles created before sysprep because Clear-Wallpaper
    # does not clear things for all users.
    if ($currentWallpaperPath -ieq $customWallpaperPath)
    {
      # If original wallpaper path exists, set the current wallpaper path to be it.
      # Otherwise, set the current wallpaper path to empty string.
      if (Test-Path $originalWallpaperPath)
      {
        $currentWallpaperPath = $originalWallpaperPath
      }
      else
      {
        $currentWallpaperPath = ""
      }
    }
    else
    {
      # If the current wallpaper path is under LOCALAPPDATA as Ec2Wallpaper, but not in the current user's path, copy the original wallpaper.
      if ((Test-Path $currentWallpaperPath) -and (Get-Item $currentWallpaperPath).Name -eq $script:customWallpaperName -and $currentWallpaperPath -ne $customWallpaperPath)
      {
        $temp = Join-Path (Get-Item $currentWallpaperPath).Directory.FullName -ChildPath $script:originalWallpaperName
        if (Test-Path $temp)
        {
          $currentWallpaperPath = $temp
        }
        else
        {
          $currentWallpaperPath = ""
        }
      }

      # If the current wallpaper path is not the custom wallpaper path,
      # copy the original file to the current user's LOCALAPPDATA.
      Copy-Item -Path $currentWallpaperPath -Destination $originalWallpaperPath -Force
    }
  }
  else
  {
    # If this is not the initial wallpaper setting, check if the wallpaper has changed since the initial setting.
    if ($currentWallpaperPath -ne $customWallpaperPath)
    {
      # If wallpaper has changed after the initial setting by user, wallpaper setting is over.
      # Delete the wallpaper setup file in the current user's startup directory.
      $userStartupPath = "C:\Users\{0}\AppData\Roaming\Microsoft\Windows\Start Menu\Programs\Startup" -f $env:USERNAME
      $wallpaperSetupPath = Join-Path $userStartupPath -ChildPath $script:wallpaperSetupName

      if (Test-Path $wallpaperSetupPath)
      {
        Remove-Item -Path $wallpaperSetupPath -Force -Confirm:$false
      }

      if (Test-Path $customWallpaperPath)
      {
        # Also delete the custom wallpaper for the current user.
        Remove-Item -Path $customWallpaperPath -Force -Confirm:$false
      }

      # At the end, finish it.
      return
    }
  }

  # Some information is fetched from metadata.
  $metadata = @(
    @{ Name = "Instance ID"; Source = "meta-data/instance-id" }
    @{ Name = "Public IPv4 Address"; Source = "meta-data/public-ipv4" }
    @{ Name = "Private IPv4 Address"; Source = "meta-data/local-ipv4" }
    @{ Name = "IPv6 Address"; Source = "meta-data/ipv6" }
    @{ Name = "Instance Size"; Source = "meta-data/instance-type" }
    @{ Name = "Availability Zone"; Source = "meta-data/placement/availability-zone" }
  )

  # These include all generations, both latest and older types.
  $instanceTypes = @(
    @{ Type = "m5d.16xlarge"; Memory = "262144 MB"; NetworkPerformance = "20 Gigabit" }
    @{ Type = "r5a.16xlarge"; Memory = "524288 MB"; NetworkPerformance = "12 Gigabit" }
    @{ Type = "r5a.xlarge"; Memory = "32768 MB"; NetworkPerformance = "Up to 10 Gigabit" }
    @{ Type = "r6g.16xlarge"; Memory = "524288 MB"; NetworkPerformance = "25 Gigabit" }
    @{ Type = "c4.8xlarge"; Memory = "61440 MB"; NetworkPerformance = "10 Gigabit" }
    @{ Type = "m5d.xlarge"; Memory = "16384 MB"; NetworkPerformance = "Up to 10 Gigabit" }
    @{ Type = "c5n.4xlarge"; Memory = "43008 MB"; NetworkPerformance = "Up to 25 Gigabit" }
    @{ Type = "r5.24xlarge"; Memory = "786432 MB"; NetworkPerformance = "25 Gigabit" }
    @{ Type = "g4dn.12xlarge"; Memory = "196608 MB"; NetworkPerformance = "50 Gigabit" }
    @{ Type = "c4.4xlarge"; Memory = "30720 MB"; NetworkPerformance = "High" }
    @{ Type = "x1e.32xlarge"; Memory = "3997696 MB"; NetworkPerformance = "25 Gigabit" }
    @{ Type = "m5d.large"; Memory = "8192 MB"; NetworkPerformance = "Up to 10 Gigabit" }
    @{ Type = "i3en.3xlarge"; Memory = "98304 MB"; NetworkPerformance = "Up to 25 Gigabit" }
    @{ Type = "g3.16xlarge"; Memory = "499712 MB"; NetworkPerformance = "25 Gigabit" }
    @{ Type = "t2.2xlarge"; Memory = "32768 MB"; NetworkPerformance = "Moderate" }
    @{ Type = "m5dn.large"; Memory = "8192 MB"; NetworkPerformance = "Up to 25 Gigabit" }
    @{ Type = "c5d.12xlarge"; Memory = "98304 MB"; NetworkPerformance = "12 Gigabit" }
    @{ Type = "m5a.16xlarge"; Memory = "262144 MB"; NetworkPerformance = "12 Gigabit" }
    @{ Type = "x1e.8xlarge"; Memory = "999424 MB"; NetworkPerformance = "Up to 10 Gigabit" }
    @{ Type = "c6g.16xlarge"; Memory = "131072 MB"; NetworkPerformance = "25 Gigabit" }
    @{ Type = "r5n.12xlarge"; Memory = "393216 MB"; NetworkPerformance = "50 Gigabit" }
    @{ Type = "m6gd.12xlarge"; Memory = "196608 MB"; NetworkPerformance = "20 Gigabit" }
    @{ Type = "m5a.2xlarge"; Memory = "32768 MB"; NetworkPerformance = "Up to 10 Gigabit" }
    @{ Type = "t3.2xlarge"; Memory = "32768 MB"; NetworkPerformance = "Up to 5 Gigabit" }
    @{ Type = "r5a.12xlarge"; Memory = "393216 MB"; NetworkPerformance = "10 Gigabit" }
    @{ Type = "c6g.12xlarge"; Memory = "98304 MB"; NetworkPerformance = "20 Gigabit" }
    @{ Type = "r6gd.xlarge"; Memory = "32768 MB"; NetworkPerformance = "Up to 10 Gigabit" }
    @{ Type = "m6gd.4xlarge"; Memory = "65536 MB"; NetworkPerformance = "Up to 10 Gigabit" }
    @{ Type = "m5d.8xlarge"; Memory = "131072 MB"; NetworkPerformance = "10 Gigabit" }
    @{ Type = "c3.large"; Memory = "3840 MB"; NetworkPerformance = "Moderate" }
    @{ Type = "m5ad.large"; Memory = "8192 MB"; NetworkPerformance = "Up to 10 Gigabit" }
    @{ Type = "a1.medium"; Memory = "2048 MB"; NetworkPerformance = "Up to 10 Gigabit" }
    @{ Type = "c3.8xlarge"; Memory = "61440 MB"; NetworkPerformance = "10 Gigabit" }
    @{ Type = "c6g.xlarge"; Memory = "8192 MB"; NetworkPerformance = "Up to 10 Gigabit" }
    @{ Type = "r5ad.8xlarge"; Memory = "262144 MB"; NetworkPerformance = "Up to 10 Gigabit" }
    @{ Type = "m5dn.2xlarge"; Memory = "32768 MB"; NetworkPerformance = "Up to 25 Gigabit" }
    @{ Type = "i3en.12xlarge"; Memory = "393216 MB"; NetworkPerformance = "50 Gigabit" }
    @{ Type = "m6gd.xlarge"; Memory = "16384 MB"; NetworkPerformance = "Up to 10 Gigabit" }
    @{ Type = "m5ad.8xlarge"; Memory = "131072 MB"; NetworkPerformance = "Up to 10 Gigabit" }
    @{ Type = "m5ad.2xlarge"; Memory = "32768 MB"; NetworkPerformance = "Up to 10 Gigabit" }
    @{ Type = "x1.16xlarge"; Memory = "999424 MB"; NetworkPerformance = "10 Gigabit" }
    @{ Type = "m6gd.metal"; Memory = "262144 MB"; NetworkPerformance = "25 Gigabit" }
    @{ Type = "g4dn.metal"; Memory = "393216 MB"; NetworkPerformance = "100 Gigabit" }
    @{ Type = "r6gd.2xlarge"; Memory = "65536 MB"; NetworkPerformance = "Up to 10 Gigabit" }
    @{ Type = "m6g.xlarge"; Memory = "16384 MB"; NetworkPerformance = "Up to 10 Gigabit" }
    @{ Type = "m5dn.8xlarge"; Memory = "131072 MB"; NetworkPerformance = "25 Gigabit" }
    @{ Type = "p2.8xlarge"; Memory = "499712 MB"; NetworkPerformance = "10 Gigabit" }
    @{ Type = "r6g.large"; Memory = "16384 MB"; NetworkPerformance = "Up to 10 Gigabit" }
    @{ Type = "z1d.xlarge"; Memory = "32768 MB"; NetworkPerformance = "Up to 10 Gigabit" }
    @{ Type = "i3en.24xlarge"; Memory = "786432 MB"; NetworkPerformance = "100 Gigabit" }
    @{ Type = "r3.large"; Memory = "15360 MB"; NetworkPerformance = "Moderate" }
    @{ Type = "d2.2xlarge"; Memory = "62464 MB"; NetworkPerformance = "High" }
    @{ Type = "r6g.medium"; Memory = "8192 MB"; NetworkPerformance = "Up to 10 Gigabit" }
    @{ Type = "m6g.metal"; Memory = "262144 MB"; NetworkPerformance = "25 Gigabit" }
    @{ Type = "r5ad.24xlarge"; Memory = "786432 MB"; NetworkPerformance = "20 Gigabit" }
    @{ Type = "c5a.4xlarge"; Memory = "32768 MB"; NetworkPerformance = "Up to 10 Gigabit" }
    @{ Type = "m5ad.12xlarge"; Memory = "196608 MB"; NetworkPerformance = "10 Gigabit" }
    @{ Type = "r6gd.large"; Memory = "16384 MB"; NetworkPerformance = "Up to 10 Gigabit" }
    @{ Type = "m5.24xlarge"; Memory = "393216 MB"; NetworkPerformance = "25 Gigabit" }
    @{ Type = "t3a.small"; Memory = "2048 MB"; NetworkPerformance = "Up to 5 Gigabit" }
    @{ Type = "m5.8xlarge"; Memory = "131072 MB"; NetworkPerformance = "10 Gigabit" }
    @{ Type = "m5a.4xlarge"; Memory = "65536 MB"; NetworkPerformance = "Up to 10 Gigabit" }
    @{ Type = "c5.xlarge"; Memory = "8192 MB"; NetworkPerformance = "Up to 10 Gigabit" }
    @{ Type = "m5.metal"; Memory = "393216 MB"; NetworkPerformance = "25 Gigabit" }
    @{ Type = "c5n.large"; Memory = "5376 MB"; NetworkPerformance = "Up to 25 Gigabit" }
    @{ Type = "m5.12xlarge"; Memory = "196608 MB"; NetworkPerformance = "10 Gigabit" }
    @{ Type = "c5d.large"; Memory = "4096 MB"; NetworkPerformance = "Up to 10 Gigabit" }
    @{ Type = "m2.4xlarge"; Memory = "70041 MB"; NetworkPerformance = "High" }
    @{ Type = "m5dn.12xlarge"; Memory = "196608 MB"; NetworkPerformance = "50 Gigabit" }
    @{ Type = "m5.xlarge"; Memory = "16384 MB"; NetworkPerformance = "Up to 10 Gigabit" }
    @{ Type = "x1e.2xlarge"; Memory = "249856 MB"; NetworkPerformance = "Up to 10 Gigabit" }
    @{ Type = "m5n.16xlarge"; Memory = "262144 MB"; NetworkPerformance = "75 Gigabit" }
    @{ Type = "r5ad.12xlarge"; Memory = "393216 MB"; NetworkPerformance = "10 Gigabit" }
    @{ Type = "c5a.12xlarge"; Memory = "98304 MB"; NetworkPerformance = "12 Gigabit" }
    @{ Type = "c6gd.metal"; Memory = "131072 MB"; NetworkPerformance = "25 Gigabit" }
    @{ Type = "t3.xlarge"; Memory = "16384 MB"; NetworkPerformance = "Up to 5 Gigabit" }
    @{ Type = "f1.2xlarge"; Memory = "124928 MB"; NetworkPerformance = "Up to 10 Gigabit" }
    @{ Type = "r6gd.medium"; Memory = "8192 MB"; NetworkPerformance = "Up to 10 Gigabit" }
    @{ Type = "r5a.large"; Memory = "16384 MB"; NetworkPerformance = "Up to 10 Gigabit" }
    @{ Type = "r5dn.8xlarge"; Memory = "262144 MB"; NetworkPerformance = "25 Gigabit" }
    @{ Type = "c5n.2xlarge"; Memory = "21504 MB"; NetworkPerformance = "Up to 25 Gigabit" }
    @{ Type = "t1.micro"; Memory = "627 MB"; NetworkPerformance = "Very Low" }
    @{ Type = "r3.8xlarge"; Memory = "249856 MB"; NetworkPerformance = "10 Gigabit" }
    @{ Type = "z1d.2xlarge"; Memory = "65536 MB"; NetworkPerformance = "Up to 10 Gigabit" }
    @{ Type = "r5a.2xlarge"; Memory = "65536 MB"; NetworkPerformance = "Up to 10 Gigabit" }
    @{ Type = "c5d.2xlarge"; Memory = "16384 MB"; NetworkPerformance = "Up to 10 Gigabit" }
    @{ Type = "inf1.xlarge"; Memory = "8192 MB"; NetworkPerformance = "Up to 25 Gigabit" }
    @{ Type = "t3a.2xlarge"; Memory = "32768 MB"; NetworkPerformance = "Up to 5 Gigabit" }
    @{ Type = "m5ad.4xlarge"; Memory = "65536 MB"; NetworkPerformance = "Up to 10 Gigabit" }
    @{ Type = "m4.4xlarge"; Memory = "65536 MB"; NetworkPerformance = "High" }
    @{ Type = "r5n.4xlarge"; Memory = "131072 MB"; NetworkPerformance = "Up to 25 Gigabit" }
    @{ Type = "i2.2xlarge"; Memory = "62464 MB"; NetworkPerformance = "High" }
    @{ Type = "m2.2xlarge"; Memory = "35020 MB"; NetworkPerformance = "Moderate" }
    @{ Type = "m5dn.xlarge"; Memory = "16384 MB"; NetworkPerformance = "Up to 25 Gigabit" }
    @{ Type = "m6gd.medium"; Memory = "4096 MB"; NetworkPerformance = "Up to 10 Gigabit" }
    @{ Type = "m5d.metal"; Memory = "393216 MB"; NetworkPerformance = "25 Gigabit" }
    @{ Type = "r4.16xlarge"; Memory = "499712 MB"; NetworkPerformance = "25 Gigabit" }
    @{ Type = "c5.4xlarge"; Memory = "32768 MB"; NetworkPerformance = "Up to 10 Gigabit" }
    @{ Type = "r6g.8xlarge"; Memory = "262144 MB"; NetworkPerformance = "12 Gigabit" }
    @{ Type = "d2.8xlarge"; Memory = "249856 MB"; NetworkPerformance = "10 Gigabit" }
    @{ Type = "m5n.8xlarge"; Memory = "131072 MB"; NetworkPerformance = "25 Gigabit" }
    @{ Type = "r5d.24xlarge"; Memory = "786432 MB"; NetworkPerformance = "25 Gigabit" }
    @{ Type = "r3.xlarge"; Memory = "31232 MB"; NetworkPerformance = "Moderate" }
    @{ Type = "c3.xlarge"; Memory = "7680 MB"; NetworkPerformance = "Moderate" }
    @{ Type = "c5.12xlarge"; Memory = "98304 MB"; NetworkPerformance = "12 Gigabit" }
    @{ Type = "r6g.12xlarge"; Memory = "393216 MB"; NetworkPerformance = "20 Gigabit" }
    @{ Type = "c5d.4xlarge"; Memory = "32768 MB"; NetworkPerformance = "Up to 10 Gigabit" }
    @{ Type = "m6g.4xlarge"; Memory = "65536 MB"; NetworkPerformance = "Up to 10 Gigabit" }
    @{ Type = "m5n.large"; Memory = "8192 MB"; NetworkPerformance = "Up to 25 Gigabit" }
    @{ Type = "h1.4xlarge"; Memory = "65536 MB"; NetworkPerformance = "Up to 10 Gigabit" }
    @{ Type = "r5d.xlarge"; Memory = "32768 MB"; NetworkPerformance = "Up to 10 Gigabit" }
    @{ Type = "m5d.24xlarge"; Memory = "393216 MB"; NetworkPerformance = "25 Gigabit" }
    @{ Type = "c5d.24xlarge"; Memory = "196608 MB"; NetworkPerformance = "25 Gigabit" }
    @{ Type = "m4.large"; Memory = "8192 MB"; NetworkPerformance = "Moderate" }
    @{ Type = "m5a.8xlarge"; Memory = "131072 MB"; NetworkPerformance = "Up to 10 Gigabit" }
    @{ Type = "m5ad.xlarge"; Memory = "16384 MB"; NetworkPerformance = "Up to 10 Gigabit" }
    @{ Type = "a1.xlarge"; Memory = "8192 MB"; NetworkPerformance = "Up to 10 Gigabit" }
    @{ Type = "r5.4xlarge"; Memory = "131072 MB"; NetworkPerformance = "Up to 10 Gigabit" }
    @{ Type = "h1.2xlarge"; Memory = "32768 MB"; NetworkPerformance = "Up to 10 Gigabit" }
    @{ Type = "r5dn.xlarge"; Memory = "32768 MB"; NetworkPerformance = "Up to 25 Gigabit" }
    @{ Type = "m6gd.16xlarge"; Memory = "262144 MB"; NetworkPerformance = "25 Gigabit" }
    @{ Type = "c4.large"; Memory = "3840 MB"; NetworkPerformance = "Moderate" }
    @{ Type = "r5d.8xlarge"; Memory = "262144 MB"; NetworkPerformance = "10 Gigabit" }
    @{ Type = "r5a.4xlarge"; Memory = "131072 MB"; NetworkPerformance = "Up to 10 Gigabit" }
    @{ Type = "c5d.18xlarge"; Memory = "147456 MB"; NetworkPerformance = "25 Gigabit" }
    @{ Type = "a1.2xlarge"; Memory = "16384 MB"; NetworkPerformance = "Up to 10 Gigabit" }
    @{ Type = "r6gd.metal"; Memory = "524288 MB"; NetworkPerformance = "25 Gigabit" }
    @{ Type = "m1.xlarge"; Memory = "15360 MB"; NetworkPerformance = "High" }
    @{ Type = "r5n.16xlarge"; Memory = "524288 MB"; NetworkPerformance = "75 Gigabit" }
    @{ Type = "r3.2xlarge"; Memory = "62464 MB"; NetworkPerformance = "High" }
    @{ Type = "a1.large"; Memory = "4096 MB"; NetworkPerformance = "Up to 10 Gigabit" }
    @{ Type = "r3.4xlarge"; Memory = "124928 MB"; NetworkPerformance = "High" }
    @{ Type = "i3.xlarge"; Memory = "31232 MB"; NetworkPerformance = "Up to 10 Gigabit" }
    @{ Type = "m5n.4xlarge"; Memory = "65536 MB"; NetworkPerformance = "Up to 25 Gigabit" }
    @{ Type = "g3.8xlarge"; Memory = "249856 MB"; NetworkPerformance = "10 Gigabit" }
    @{ Type = "g2.2xlarge"; Memory = "15360 MB"; NetworkPerformance = "Moderate" }
    @{ Type = "r5n.24xlarge"; Memory = "786432 MB"; NetworkPerformance = "100 Gigabit" }
    @{ Type = "c5a.xlarge"; Memory = "8192 MB"; NetworkPerformance = "Up to 10 Gigabit" }
    @{ Type = "c5n.9xlarge"; Memory = "98304 MB"; NetworkPerformance = "50 Gigabit" }
    @{ Type = "r6gd.8xlarge"; Memory = "262144 MB"; NetworkPerformance = "12 Gigabit" }
    @{ Type = "c6gd.16xlarge"; Memory = "131072 MB"; NetworkPerformance = "25 Gigabit" }
    @{ Type = "h1.8xlarge"; Memory = "131072 MB"; NetworkPerformance = "10 Gigabit" }
    @{ Type = "r5ad.large"; Memory = "16384 MB"; NetworkPerformance = "Up to 10 Gigabit" }
    @{ Type = "inf1.2xlarge"; Memory = "16384 MB"; NetworkPerformance = "Up to 25 Gigabit" }
    @{ Type = "r5d.2xlarge"; Memory = "65536 MB"; NetworkPerformance = "Up to 10 Gigabit" }
    @{ Type = "r5.metal"; Memory = "786432 MB"; NetworkPerformance = "25 Gigabit" }
    @{ Type = "c5a.16xlarge"; Memory = "131072 MB"; NetworkPerformance = "20 Gigabit" }
    @{ Type = "m4.xlarge"; Memory = "16384 MB"; NetworkPerformance = "High" }
    @{ Type = "r4.2xlarge"; Memory = "62464 MB"; NetworkPerformance = "Up to 10 Gigabit" }
    @{ Type = "t3.large"; Memory = "8192 MB"; NetworkPerformance = "Up to 5 Gigabit" }
    @{ Type = "c5a.24xlarge"; Memory = "196608 MB"; NetworkPerformance = "20 Gigabit" }
    @{ Type = "r5n.2xlarge"; Memory = "65536 MB"; NetworkPerformance = "Up to 25 Gigabit" }
    @{ Type = "z1d.12xlarge"; Memory = "393216 MB"; NetworkPerformance = "25 Gigabit" }
    @{ Type = "r5d.4xlarge"; Memory = "131072 MB"; NetworkPerformance = "Up to 10 Gigabit" }
    @{ Type = "t3.micro"; Memory = "1024 MB"; NetworkPerformance = "Up to 5 Gigabit" }
    @{ Type = "c5.9xlarge"; Memory = "73728 MB"; NetworkPerformance = "10 Gigabit" }
    @{ Type = "c5.metal"; Memory = "196608 MB"; NetworkPerformance = "25 Gigabit" }
    @{ Type = "m5ad.24xlarge"; Memory = "393216 MB"; NetworkPerformance = "20 Gigabit" }
    @{ Type = "t3a.large"; Memory = "8192 MB"; NetworkPerformance = "Up to 5 Gigabit" }
    @{ Type = "r6gd.4xlarge"; Memory = "131072 MB"; NetworkPerformance = "Up to 10 Gigabit" }
    @{ Type = "m4.16xlarge"; Memory = "262144 MB"; NetworkPerformance = "25 Gigabit" }
    @{ Type = "r5d.16xlarge"; Memory = "524288 MB"; NetworkPerformance = "20 Gigabit" }
    @{ Type = "a1.metal"; Memory = "32768 MB"; NetworkPerformance = "Up to 10 Gigabit" }
    @{ Type = "m5n.12xlarge"; Memory = "196608 MB"; NetworkPerformance = "50 Gigabit" }
    @{ Type = "m6g.12xlarge"; Memory = "196608 MB"; NetworkPerformance = "20 Gigabit" }
    @{ Type = "r5ad.16xlarge"; Memory = "524288 MB"; NetworkPerformance = "12 Gigabit" }
    @{ Type = "c5n.18xlarge"; Memory = "196608 MB"; NetworkPerformance = "100 Gigabit" }
    @{ Type = "r5.large"; Memory = "16384 MB"; NetworkPerformance = "Up to 10 Gigabit" }
    @{ Type = "c5a.2xlarge"; Memory = "16384 MB"; NetworkPerformance = "Up to 10 Gigabit" }
    @{ Type = "c5.24xlarge"; Memory = "196608 MB"; NetworkPerformance = "25 Gigabit" }
    @{ Type = "h1.16xlarge"; Memory = "262144 MB"; NetworkPerformance = "25 Gigabit" }
    @{ Type = "r5dn.large"; Memory = "16384 MB"; NetworkPerformance = "Up to 25 Gigabit" }
    @{ Type = "c1.medium"; Memory = "1740 MB"; NetworkPerformance = "Moderate" }
    @{ Type = "g4dn.xlarge"; Memory = "16384 MB"; NetworkPerformance = "Up to 25 Gigabit" }
    @{ Type = "m3.xlarge"; Memory = "15360 MB"; NetworkPerformance = "High" }
    @{ Type = "m6g.large"; Memory = "8192 MB"; NetworkPerformance = "Up to 10 Gigabit" }
    @{ Type = "c6g.large"; Memory = "4096 MB"; NetworkPerformance = "Up to 10 Gigabit" }
    @{ Type = "t3.medium"; Memory = "4096 MB"; NetworkPerformance = "Up to 5 Gigabit" }
    @{ Type = "t2.micro"; Memory = "1024 MB"; NetworkPerformance = "Low to Moderate" }
    @{ Type = "c4.xlarge"; Memory = "7680 MB"; NetworkPerformance = "High" }
    @{ Type = "t3.nano"; Memory = "512 MB"; NetworkPerformance = "Up to 5 Gigabit" }
    @{ Type = "t3a.medium"; Memory = "4096 MB"; NetworkPerformance = "Up to 5 Gigabit" }
    @{ Type = "r5.8xlarge"; Memory = "262144 MB"; NetworkPerformance = "10 Gigabit" }
    @{ Type = "r5.xlarge"; Memory = "32768 MB"; NetworkPerformance = "Up to 10 Gigabit" }
    @{ Type = "z1d.metal"; Memory = "393216 MB"; NetworkPerformance = "25 Gigabit" }
    @{ Type = "r5d.large"; Memory = "16384 MB"; NetworkPerformance = "Up to 10 Gigabit" }
    @{ Type = "r5ad.2xlarge"; Memory = "65536 MB"; NetworkPerformance = "Up to 10 Gigabit" }
    @{ Type = "inf1.6xlarge"; Memory = "49152 MB"; NetworkPerformance = "25 Gigabit" }
    @{ Type = "r4.xlarge"; Memory = "31232 MB"; NetworkPerformance = "Up to 10 Gigabit" }
    @{ Type = "c6gd.xlarge"; Memory = "8192 MB"; NetworkPerformance = "Up to 10 Gigabit" }
    @{ Type = "m6g.8xlarge"; Memory = "131072 MB"; NetworkPerformance = "12 Gigabit" }
    @{ Type = "c4.2xlarge"; Memory = "15360 MB"; NetworkPerformance = "High" }
    @{ Type = "p3.2xlarge"; Memory = "62464 MB"; NetworkPerformance = "Up to 10 Gigabit" }
    @{ Type = "c1.xlarge"; Memory = "7168 MB"; NetworkPerformance = "High" }
    @{ Type = "m5.4xlarge"; Memory = "65536 MB"; NetworkPerformance = "Up to 10 Gigabit" }
    @{ Type = "t2.large"; Memory = "8192 MB"; NetworkPerformance = "Low to Moderate" }
    @{ Type = "i2.xlarge"; Memory = "31232 MB"; NetworkPerformance = "Moderate" }
    @{ Type = "r5.16xlarge"; Memory = "524288 MB"; NetworkPerformance = "20 Gigabit" }
    @{ Type = "r6g.4xlarge"; Memory = "131072 MB"; NetworkPerformance = "Up to 10 Gigabit" }
    @{ Type = "g3.4xlarge"; Memory = "124928 MB"; NetworkPerformance = "Up to 10 Gigabit" }
    @{ Type = "r5.12xlarge"; Memory = "393216 MB"; NetworkPerformance = "10 Gigabit" }
    @{ Type = "m5n.xlarge"; Memory = "16384 MB"; NetworkPerformance = "Up to 25 Gigabit" }
    @{ Type = "t2.nano"; Memory = "512 MB"; NetworkPerformance = "Low to Moderate" }
    @{ Type = "x1e.xlarge"; Memory = "124928 MB"; NetworkPerformance = "Up to 10 Gigabit" }
    @{ Type = "i2.4xlarge"; Memory = "124928 MB"; NetworkPerformance = "High" }
    @{ Type = "c3.2xlarge"; Memory = "15360 MB"; NetworkPerformance = "High" }
    @{ Type = "r6gd.16xlarge"; Memory = "524288 MB"; NetworkPerformance = "25 Gigabit" }
    @{ Type = "c6gd.4xlarge"; Memory = "32768 MB"; NetworkPerformance = "Up to 10 Gigabit" }
    @{ Type = "i3.metal"; Memory = "524288 MB"; NetworkPerformance = "25 Gigabit" }
    @{ Type = "p3.8xlarge"; Memory = "249856 MB"; NetworkPerformance = "10 Gigabit" }
    @{ Type = "m5.16xlarge"; Memory = "262144 MB"; NetworkPerformance = "20 Gigabit" }
    @{ Type = "r6gd.12xlarge"; Memory = "393216 MB"; NetworkPerformance = "20 Gigabit" }
    @{ Type = "c5.2xlarge"; Memory = "16384 MB"; NetworkPerformance = "Up to 10 Gigabit" }
    @{ Type = "g4dn.16xlarge"; Memory = "262144 MB"; NetworkPerformance = "50 Gigabit" }
    @{ Type = "m6gd.large"; Memory = "8192 MB"; NetworkPerformance = "Up to 10 Gigabit" }
    @{ Type = "m5d.4xlarge"; Memory = "65536 MB"; NetworkPerformance = "Up to 10 Gigabit" }
    @{ Type = "r5ad.4xlarge"; Memory = "131072 MB"; NetworkPerformance = "Up to 10 Gigabit" }
    @{ Type = "i3.16xlarge"; Memory = "499712 MB"; NetworkPerformance = "25 Gigabit" }
    @{ Type = "r5dn.2xlarge"; Memory = "65536 MB"; NetworkPerformance = "Up to 25 Gigabit" }
    @{ Type = "r6g.2xlarge"; Memory = "65536 MB"; NetworkPerformance = "Up to 10 Gigabit" }
    @{ Type = "c5.large"; Memory = "4096 MB"; NetworkPerformance = "Up to 10 Gigabit" }
    @{ Type = "m2.xlarge"; Memory = "17510 MB"; NetworkPerformance = "Moderate" }
    @{ Type = "t3a.nano"; Memory = "512 MB"; NetworkPerformance = "Up to 5 Gigabit" }
    @{ Type = "r5d.metal"; Memory = "786432 MB"; NetworkPerformance = "25 Gigabit" }
    @{ Type = "inf1.24xlarge"; Memory = "196608 MB"; NetworkPerformance = "100 Gigabit" }
    @{ Type = "t2.small"; Memory = "2048 MB"; NetworkPerformance = "Low to Moderate" }
    @{ Type = "r5n.xlarge"; Memory = "32768 MB"; NetworkPerformance = "Up to 25 Gigabit" }
    @{ Type = "i3.4xlarge"; Memory = "124928 MB"; NetworkPerformance = "Up to 10 Gigabit" }
    @{ Type = "m4.2xlarge"; Memory = "32768 MB"; NetworkPerformance = "High" }
    @{ Type = "c6g.2xlarge"; Memory = "16384 MB"; NetworkPerformance = "Up to 10 Gigabit" }
    @{ Type = "i3en.xlarge"; Memory = "32768 MB"; NetworkPerformance = "Up to 25 Gigabit" }
    @{ Type = "c6gd.2xlarge"; Memory = "16384 MB"; NetworkPerformance = "Up to 10 Gigabit" }
    @{ Type = "m5a.24xlarge"; Memory = "393216 MB"; NetworkPerformance = "20 Gigabit" }
    @{ Type = "c5d.metal"; Memory = "196608 MB"; NetworkPerformance = "25 Gigabit" }
    @{ Type = "c6gd.medium"; Memory = "2048 MB"; NetworkPerformance = "Up to 10 Gigabit" }
    @{ Type = "m5dn.16xlarge"; Memory = "262144 MB"; NetworkPerformance = "75 Gigabit" }
    @{ Type = "r5a.24xlarge"; Memory = "786432 MB"; NetworkPerformance = "20 Gigabit" }
    @{ Type = "p3.16xlarge"; Memory = "499712 MB"; NetworkPerformance = "25 Gigabit" }
    @{ Type = "x1e.16xlarge"; Memory = "1998848 MB"; NetworkPerformance = "10 Gigabit" }
    @{ Type = "t3.small"; Memory = "2048 MB"; NetworkPerformance = "Up to 5 Gigabit" }
    @{ Type = "g3s.xlarge"; Memory = "31232 MB"; NetworkPerformance = "Up to 10 Gigabit" }
    @{ Type = "r6g.metal"; Memory = "524288 MB"; NetworkPerformance = "25 Gigabit" }
    @{ Type = "p2.16xlarge"; Memory = "749568 MB"; NetworkPerformance = "25 Gigabit" }
    @{ Type = "m6g.medium"; Memory = "4096 MB"; NetworkPerformance = "Up to 10 Gigabit" }
    @{ Type = "m5.large"; Memory = "8192 MB"; NetworkPerformance = "Up to 10 Gigabit" }
    @{ Type = "m5a.xlarge"; Memory = "16384 MB"; NetworkPerformance = "Up to 10 Gigabit" }
    @{ Type = "m5dn.4xlarge"; Memory = "65536 MB"; NetworkPerformance = "Up to 25 Gigabit" }
    @{ Type = "c6g.medium"; Memory = "2048 MB"; NetworkPerformance = "Up to 10 Gigabit" }
    @{ Type = "d2.4xlarge"; Memory = "124928 MB"; NetworkPerformance = "High" }
    @{ Type = "i3.large"; Memory = "15616 MB"; NetworkPerformance = "Up to 10 Gigabit" }
    @{ Type = "r4.large"; Memory = "15616 MB"; NetworkPerformance = "Up to 10 Gigabit" }
    @{ Type = "c5n.xlarge"; Memory = "10752 MB"; NetworkPerformance = "Up to 25 Gigabit" }
    @{ Type = "r5a.8xlarge"; Memory = "262144 MB"; NetworkPerformance = "Up to 10 Gigabit" }
    @{ Type = "r5dn.12xlarge"; Memory = "393216 MB"; NetworkPerformance = "50 Gigabit" }
    @{ Type = "r4.4xlarge"; Memory = "124928 MB"; NetworkPerformance = "Up to 10 Gigabit" }
    @{ Type = "m5n.2xlarge"; Memory = "32768 MB"; NetworkPerformance = "Up to 25 Gigabit" }
    @{ Type = "m4.10xlarge"; Memory = "163840 MB"; NetworkPerformance = "10 Gigabit" }
    @{ Type = "i3en.large"; Memory = "16384 MB"; NetworkPerformance = "Up to 25 Gigabit" }
    @{ Type = "m6gd.8xlarge"; Memory = "131072 MB"; NetworkPerformance = "12 Gigabit" }
    @{ Type = "r6g.xlarge"; Memory = "32768 MB"; NetworkPerformance = "Up to 10 Gigabit" }
    @{ Type = "x1e.4xlarge"; Memory = "499712 MB"; NetworkPerformance = "Up to 10 Gigabit" }
    @{ Type = "r5d.12xlarge"; Memory = "393216 MB"; NetworkPerformance = "10 Gigabit" }
    @{ Type = "r4.8xlarge"; Memory = "249856 MB"; NetworkPerformance = "10 Gigabit" }
    @{ Type = "a1.4xlarge"; Memory = "32768 MB"; NetworkPerformance = "Up to 10 Gigabit" }
    @{ Type = "z1d.3xlarge"; Memory = "98304 MB"; NetworkPerformance = "Up to 10 Gigabit" }
    @{ Type = "m5dn.24xlarge"; Memory = "393216 MB"; NetworkPerformance = "100 Gigabit" }
    @{ Type = "t2.xlarge"; Memory = "16384 MB"; NetworkPerformance = "Moderate" }
    @{ Type = "i3.2xlarge"; Memory = "62464 MB"; NetworkPerformance = "Up to 10 Gigabit" }
    @{ Type = "c5n.metal"; Memory = "196608 MB"; NetworkPerformance = "100 Gigabit" }
    @{ Type = "m5.2xlarge"; Memory = "32768 MB"; NetworkPerformance = "Up to 10 Gigabit" }
    @{ Type = "r5dn.16xlarge"; Memory = "524288 MB"; NetworkPerformance = "75 Gigabit" }
    @{ Type = "i2.8xlarge"; Memory = "249856 MB"; NetworkPerformance = "10 Gigabit" }
    @{ Type = "m5n.24xlarge"; Memory = "393216 MB"; NetworkPerformance = "100 Gigabit" }
    @{ Type = "p2.xlarge"; Memory = "62464 MB"; NetworkPerformance = "High" }
    @{ Type = "x1.32xlarge"; Memory = "1998848 MB"; NetworkPerformance = "25 Gigabit" }
    @{ Type = "c6g.8xlarge"; Memory = "65536 MB"; NetworkPerformance = "12 Gigabit" }
    @{ Type = "z1d.large"; Memory = "16384 MB"; NetworkPerformance = "Up to 10 Gigabit" }
    @{ Type = "r5dn.4xlarge"; Memory = "131072 MB"; NetworkPerformance = "Up to 25 Gigabit" }
    @{ Type = "i3.8xlarge"; Memory = "249856 MB"; NetworkPerformance = "10 Gigabit" }
    @{ Type = "m5d.12xlarge"; Memory = "196608 MB"; NetworkPerformance = "10 Gigabit" }
    @{ Type = "i3en.2xlarge"; Memory = "65536 MB"; NetworkPerformance = "Up to 25 Gigabit" }
    @{ Type = "c6g.4xlarge"; Memory = "32768 MB"; NetworkPerformance = "Up to 10 Gigabit" }
    @{ Type = "m5a.large"; Memory = "8192 MB"; NetworkPerformance = "Up to 10 Gigabit" }
    @{ Type = "r5n.8xlarge"; Memory = "262144 MB"; NetworkPerformance = "25 Gigabit" }
    @{ Type = "z1d.6xlarge"; Memory = "196608 MB"; NetworkPerformance = "10 Gigabit" }
    @{ Type = "f1.16xlarge"; Memory = "999424 MB"; NetworkPerformance = "25 Gigabit" }
    @{ Type = "m5ad.16xlarge"; Memory = "262144 MB"; NetworkPerformance = "12 Gigabit" }
    @{ Type = "c5a.8xlarge"; Memory = "65536 MB"; NetworkPerformance = "10 Gigabit" }
    @{ Type = "c5d.xlarge"; Memory = "8192 MB"; NetworkPerformance = "Up to 10 Gigabit" }
    @{ Type = "t2.medium"; Memory = "4096 MB"; NetworkPerformance = "Low to Moderate" }
    @{ Type = "m6g.16xlarge"; Memory = "262144 MB"; NetworkPerformance = "25 Gigabit" }
    @{ Type = "r5ad.xlarge"; Memory = "32768 MB"; NetworkPerformance = "Up to 10 Gigabit" }
    @{ Type = "r5.2xlarge"; Memory = "65536 MB"; NetworkPerformance = "Up to 10 Gigabit" }
    @{ Type = "m3.large"; Memory = "7680 MB"; NetworkPerformance = "Moderate" }
    @{ Type = "m3.2xlarge"; Memory = "30720 MB"; NetworkPerformance = "High" }
    @{ Type = "m5d.2xlarge"; Memory = "32768 MB"; NetworkPerformance = "Up to 10 Gigabit" }
    @{ Type = "c3.4xlarge"; Memory = "30720 MB"; NetworkPerformance = "High" }
    @{ Type = "m6gd.2xlarge"; Memory = "32768 MB"; NetworkPerformance = "Up to 10 Gigabit" }
    @{ Type = "f1.4xlarge"; Memory = "249856 MB"; NetworkPerformance = "Up to 10 Gigabit" }
    @{ Type = "m3.medium"; Memory = "3840 MB"; NetworkPerformance = "Moderate" }
    @{ Type = "t3a.micro"; Memory = "1024 MB"; NetworkPerformance = "Up to 5 Gigabit" }
    @{ Type = "m1.medium"; Memory = "3788 MB"; NetworkPerformance = "Moderate" }
    @{ Type = "m1.large"; Memory = "7680 MB"; NetworkPerformance = "Moderate" }
    @{ Type = "c5a.large"; Memory = "4096 MB"; NetworkPerformance = "Up to 10 Gigabit" }
    @{ Type = "g4dn.8xlarge"; Memory = "131072 MB"; NetworkPerformance = "50 Gigabit" }
    @{ Type = "p3dn.24xlarge"; Memory = "786432 MB"; NetworkPerformance = "100 Gigabit" }
    @{ Type = "g4dn.4xlarge"; Memory = "65536 MB"; NetworkPerformance = "Up to 25 Gigabit" }
    @{ Type = "m6g.2xlarge"; Memory = "32768 MB"; NetworkPerformance = "Up to 10 Gigabit" }
    @{ Type = "d2.xlarge"; Memory = "31232 MB"; NetworkPerformance = "Moderate" }
    @{ Type = "cc2.8xlarge"; Memory = "61952 MB"; NetworkPerformance = "10 Gigabit" }
    @{ Type = "t3a.xlarge"; Memory = "16384 MB"; NetworkPerformance = "Up to 5 Gigabit" }
    @{ Type = "c6gd.8xlarge"; Memory = "65536 MB"; NetworkPerformance = "12 Gigabit" }
    @{ Type = "g2.8xlarge"; Memory = "61440 MB"; NetworkPerformance = "High" }
    @{ Type = "m1.small"; Memory = "1740 MB"; NetworkPerformance = "Low" }
    @{ Type = "r5dn.24xlarge"; Memory = "786432 MB"; NetworkPerformance = "100 Gigabit" }
    @{ Type = "c6gd.12xlarge"; Memory = "98304 MB"; NetworkPerformance = "20 Gigabit" }
    @{ Type = "i3en.6xlarge"; Memory = "196608 MB"; NetworkPerformance = "25 Gigabit" }
    @{ Type = "m5a.12xlarge"; Memory = "196608 MB"; NetworkPerformance = "10 Gigabit" }
    @{ Type = "i3en.metal"; Memory = "786432 MB"; NetworkPerformance = "100 Gigabit" }
    @{ Type = "c6gd.large"; Memory = "4096 MB"; NetworkPerformance = "Up to 10 Gigabit" }
    @{ Type = "g4dn.2xlarge"; Memory = "32768 MB"; NetworkPerformance = "Up to 25 Gigabit" }
    @{ Type = "c5.18xlarge"; Memory = "147456 MB"; NetworkPerformance = "25 Gigabit" }
    @{ Type = "c5d.9xlarge"; Memory = "73728 MB"; NetworkPerformance = "10 Gigabit" }
    @{ Type = "c6g.metal"; Memory = "131072 MB"; NetworkPerformance = "25 Gigabit" }
    @{ Type = "r5n.large"; Memory = "16384 MB"; NetworkPerformance = "Up to 25 Gigabit" }
  )

  $infos = @()
  $instanceSize = ""

  # Before calling any function, initialize the log with filename
  Initialize-Log -FileName "WallpaperSetup.log"

  Write-Log "Setting up wallpaper begins"
  Write-Log "Getting instance information to render it on wallpaper"

  # Get current hostname.
  $infos += "Hostname: {0}" -f [System.Net.Dns]::GetHostName()

  # Get each information from metadata list defined above.
  foreach ($data in $metadata)
  {
    try
    {
      $value = (Get-Metadata -UrlFragment $data.Source).Trim()
      $infos += "{0}: {1}" -f $data.Name,$value

      if ($data.Name -eq "Instance Size")
      {
        $instanceSize = $value
      }

      Write-Log ("Successfully retrieved {0} from metadata" -f $data.Name)
    }
    catch
    {
      Write-ErrorLog ("Failed to retrieve {0} from metadata: {1}" -f $data.Name,$_.Exception.Message)
    }
  }

  # Get architecture chip information from registry key.
  $envRegRes = Get-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager\Environment" -ErrorAction SilentlyContinue
  if ($envRegRes -and $envRegRes.PROCESSOR_ARCHITECTURE)
  {
    $infos += "Architecture: {0}" -f $envRegRes.PROCESSOR_ARCHITECTURE
    Write-Log ("Successfully retrieved architecture chip from registry key" -f $data.Name)
  }
  else
  {
    Write-ErrorLog "Failed to retrieve architecture chip from registry key"
  }

  # Set instance type information if instance size was found from metadata above
  if ($instanceSize)
  {
    $instanceType = $instanceTypes | Where-Object { $_.Type.Equals($instanceSize) }
    if ($instanceType)
    {
      $infos += "Total Memory: {0}" -f $instanceType.Memory
      $infos += "Network Performance: {0}" -f $instanceType.NetworkPerformance
      Write-Log ("Successfully found instance type information for instance size {0}" -f $instanceSize)
    }
    else
    {
      Write-ErrorLog ("Failed to find instance type information for instance size {0}" -f $instanceSize)
    }
  }

  # Check if message contains any information about the instance
  if ($infos.Length -eq 0)
  {
    throw New-Object System.Exception ("Failed to get instance information.")
  }

  # Create a message from the infos
  $message = ""
  foreach ($info in $infos)
  {
    $message += $info + [Environment]::NewLine
  }

  Write-Log ("Successfully fetched instance information: {0}" -f $message)

  try
  {
    Add-Type -AssemblyName System.Windows.Forms

    $fontStyle = "Calibri"
    $fontSize = 12

    Write-Log "Rendering instance information on wallpaper"

    $width = [System.Windows.Forms.SystemInformation]::PrimaryMonitorSize.Width
    $height = [System.Windows.Forms.SystemInformation]::PrimaryMonitorSize.Height

    $textfont = New-Object System.Drawing.Font ($fontStyle,$fontSize,[System.Drawing.FontStyle]::Regular)
    $textBrush = New-Object Drawing.SolidBrush ([System.Drawing.Color]::White)

    $proposedSize = New-Object System.Drawing.Size ([int]$width,[int]$height)
    $messageSize = [System.Windows.Forms.TextRenderer]::MeasureText($message,$textfont,$proposedSize)

    if (-not $currentWallpaperPath)
    {
      # Check and create a new wallpaper if no wallpaper is set in current system.
      Write-Log "No wallpaper is set.. Setting wallpaper with custom color"
      $bgrRectangle = New-Object Drawing.Rectangle (0,0,[int]$width,[int]$height)
      $bgrBrush = New-Object System.Drawing.SolidBrush ([System.Drawing.Color]::Navy)
      $bmp = New-Object System.Drawing.Bitmap ([int]$width,[int]$height)
      $graphics = [System.Drawing.Graphics]::FromImage($bmp)
      $graphics.FillRectangle($bgrBrush,$bgrRectangle)
    }
    else
    {
      # Get the bitmap from the current wallpaper and set the size to be fit in screen.
      Write-Log "Wallpaper found.. Rendering instance information on current wallpaper"
      $srcBmp = [System.Drawing.Bitmap]::FromFile($originalWallpaperPath)
      $bmp = New-Object System.Drawing.Bitmap ($srcBmp,$width,$height)
      $graphics = [System.Drawing.Graphics]::FromImage($bmp)
      $srcBmp.Dispose()
    }

    # Set the position and size of the text box with rectangle.
    $rec = New-Object System.Drawing.RectangleF (($width - $messageSize.Width - 20),30,($messageSize.Width + 20),$messageSize.Height)
    $graphics.TextRenderingHint = [System.Drawing.Text.TextRenderingHint]::AntiAlias
    $graphics.DrawString($message,$textfont,$textBrush,$rec)

    # Save the new wallpaper in destination defined above.
    $bmp.Save($customWallpaperPath,[System.Drawing.Imaging.ImageFormat]::Jpeg)

    # Finally, set the wallpaper!
    [WallpaperUtil.Helper]::SetWallpaper($customWallpaperPath)

    Write-Log "Successfully rendered instance information on wallpaper"
  }
  catch
  {
    Write-ErrorLog ("Failed to render instance information on wallpaper {0}" -f $_.Exception.Message)
  }
  finally
  {
    if ($graphics)
    {
      $graphics.Dispose()
    }
    if ($bmp)
    {
      $bmp.Dispose()
    }
  }

  # Before finishing the script, complete the log.
  Complete-Log
}

# SIG # Begin signature block
# MIIfJgYJKoZIhvcNAQcCoIIfFzCCHxMCAQExDzANBglghkgBZQMEAgEFADB5Bgor
# BgEEAYI3AgEEoGswaTA0BgorBgEEAYI3AgEeMCYCAwEAAAQQH8w7YFlLCE63JNLG
# KX7zUQIBAAIBAAIBAAIBAAIBADAxMA0GCWCGSAFlAwQCAQUABCBFHISPQxNeq0Cz
# U9kcLEeYV3CwqmwWS94DwleM/XwN+KCCDlUwggawMIIEmKADAgECAhAIrUCyYNKc
# TJ9ezam9k67ZMA0GCSqGSIb3DQEBDAUAMGIxCzAJBgNVBAYTAlVTMRUwEwYDVQQK
# EwxEaWdpQ2VydCBJbmMxGTAXBgNVBAsTEHd3dy5kaWdpY2VydC5jb20xITAfBgNV
# BAMTGERpZ2lDZXJ0IFRydXN0ZWQgUm9vdCBHNDAeFw0yMTA0MjkwMDAwMDBaFw0z
# NjA0MjgyMzU5NTlaMGkxCzAJBgNVBAYTAlVTMRcwFQYDVQQKEw5EaWdpQ2VydCwg
# SW5jLjFBMD8GA1UEAxM4RGlnaUNlcnQgVHJ1c3RlZCBHNCBDb2RlIFNpZ25pbmcg
# UlNBNDA5NiBTSEEzODQgMjAyMSBDQTEwggIiMA0GCSqGSIb3DQEBAQUAA4ICDwAw
# ggIKAoICAQDVtC9C0CiteLdd1TlZG7GIQvUzjOs9gZdwxbvEhSYwn6SOaNhc9es0
# JAfhS0/TeEP0F9ce2vnS1WcaUk8OoVf8iJnBkcyBAz5NcCRks43iCH00fUyAVxJr
# Q5qZ8sU7H/Lvy0daE6ZMswEgJfMQ04uy+wjwiuCdCcBlp/qYgEk1hz1RGeiQIXhF
# LqGfLOEYwhrMxe6TSXBCMo/7xuoc82VokaJNTIIRSFJo3hC9FFdd6BgTZcV/sk+F
# LEikVoQ11vkunKoAFdE3/hoGlMJ8yOobMubKwvSnowMOdKWvObarYBLj6Na59zHh
# 3K3kGKDYwSNHR7OhD26jq22YBoMbt2pnLdK9RBqSEIGPsDsJ18ebMlrC/2pgVItJ
# wZPt4bRc4G/rJvmM1bL5OBDm6s6R9b7T+2+TYTRcvJNFKIM2KmYoX7BzzosmJQay
# g9Rc9hUZTO1i4F4z8ujo7AqnsAMrkbI2eb73rQgedaZlzLvjSFDzd5Ea/ttQokbI
# YViY9XwCFjyDKK05huzUtw1T0PhH5nUwjewwk3YUpltLXXRhTT8SkXbev1jLchAp
# QfDVxW0mdmgRQRNYmtwmKwH0iU1Z23jPgUo+QEdfyYFQc4UQIyFZYIpkVMHMIRro
# OBl8ZhzNeDhFMJlP/2NPTLuqDQhTQXxYPUez+rbsjDIJAsxsPAxWEQIDAQABo4IB
# WTCCAVUwEgYDVR0TAQH/BAgwBgEB/wIBADAdBgNVHQ4EFgQUaDfg67Y7+F8Rhvv+
# YXsIiGX0TkIwHwYDVR0jBBgwFoAU7NfjgtJxXWRM3y5nP+e6mK4cD08wDgYDVR0P
# AQH/BAQDAgGGMBMGA1UdJQQMMAoGCCsGAQUFBwMDMHcGCCsGAQUFBwEBBGswaTAk
# BggrBgEFBQcwAYYYaHR0cDovL29jc3AuZGlnaWNlcnQuY29tMEEGCCsGAQUFBzAC
# hjVodHRwOi8vY2FjZXJ0cy5kaWdpY2VydC5jb20vRGlnaUNlcnRUcnVzdGVkUm9v
# dEc0LmNydDBDBgNVHR8EPDA6MDigNqA0hjJodHRwOi8vY3JsMy5kaWdpY2VydC5j
# b20vRGlnaUNlcnRUcnVzdGVkUm9vdEc0LmNybDAcBgNVHSAEFTATMAcGBWeBDAED
# MAgGBmeBDAEEATANBgkqhkiG9w0BAQwFAAOCAgEAOiNEPY0Idu6PvDqZ01bgAhql
# +Eg08yy25nRm95RysQDKr2wwJxMSnpBEn0v9nqN8JtU3vDpdSG2V1T9J9Ce7FoFF
# UP2cvbaF4HZ+N3HLIvdaqpDP9ZNq4+sg0dVQeYiaiorBtr2hSBh+3NiAGhEZGM1h
# mYFW9snjdufE5BtfQ/g+lP92OT2e1JnPSt0o618moZVYSNUa/tcnP/2Q0XaG3Ryw
# YFzzDaju4ImhvTnhOE7abrs2nfvlIVNaw8rpavGiPttDuDPITzgUkpn13c5Ubdld
# AhQfQDN8A+KVssIhdXNSy0bYxDQcoqVLjc1vdjcshT8azibpGL6QB7BDf5WIIIJw
# 8MzK7/0pNVwfiThV9zeKiwmhywvpMRr/LhlcOXHhvpynCgbWJme3kuZOX956rEnP
# LqR0kq3bPKSchh/jwVYbKyP/j7XqiHtwa+aguv06P0WmxOgWkVKLQcBIhEuWTatE
# QOON8BUozu3xGFYHKi8QxAwIZDwzj64ojDzLj4gLDb879M4ee47vtevLt/B3E+bn
# KD+sEq6lLyJsQfmCXBVmzGwOysWGw/YmMwwHS6DTBwJqakAwSEs0qFEgu60bhQji
# WQ1tygVQK+pKHJ6l/aCnHwZ05/LWUpD9r4VIIflXO7ScA+2GRfS0YW6/aOImYIbq
# yK+p/pQd52MbOoZWeE4wggedMIIFhaADAgECAhABe4J3F0ijMMT66O5gzQEfMA0G
# CSqGSIb3DQEBCwUAMGkxCzAJBgNVBAYTAlVTMRcwFQYDVQQKEw5EaWdpQ2VydCwg
# SW5jLjFBMD8GA1UEAxM4RGlnaUNlcnQgVHJ1c3RlZCBHNCBDb2RlIFNpZ25pbmcg
# UlNBNDA5NiBTSEEzODQgMjAyMSBDQTEwHhcNMjExMjI4MDAwMDAwWhcNMjMwMTAz
# MjM1OTU5WjCB8jEdMBsGA1UEDwwUUHJpdmF0ZSBPcmdhbml6YXRpb24xEzARBgsr
# BgEEAYI3PAIBAxMCVVMxGTAXBgsrBgEEAYI3PAIBAhMIRGVsYXdhcmUxEDAOBgNV
# BAUTBzQxNTI5NTQxCzAJBgNVBAYTAlVTMRMwEQYDVQQIEwpXYXNoaW5ndG9uMRAw
# DgYDVQQHEwdTZWF0dGxlMSIwIAYDVQQKExlBbWF6b24gV2ViIFNlcnZpY2VzLCBJ
# bmMuMRMwEQYDVQQLEwpBbWF6b24gRUMyMSIwIAYDVQQDExlBbWF6b24gV2ViIFNl
# cnZpY2VzLCBJbmMuMIIBojANBgkqhkiG9w0BAQEFAAOCAY8AMIIBigKCAYEAtCrQ
# u3fd3L+RmFVifX8P7XsFoqdsNC6J9Gnnw9tIzGwRU5ke3UKljLvIMed9kvTZ196W
# JZf/GT6WJIbq2QVRHBFrNzQ24vOtdDJp4vEJN2zTWNoMx2IMrP3u7Arlh8BEuORU
# faeZjTFrxG1ZOn2BG8RcaeST+YINZoM6F+tPEzEg7UPbCe6yu1Wztkzj1nadwO9J
# A0vPHLsldeSgo5bqXS3KgTkUZQXgNyB7+DtgjFH+slV1CfzA5B20O3CuZq916q7s
# 1XaVjtCirDjDXIqeULzLUd6F4gvcHCtPIsPLm9q9vNn9Z7YTXcfbTfIMI/Q5OQKF
# i2f5LTEAYwMuQC963rAqSamLxs8u6EMHentmXPpTN7T/iMSRXMsDMn61XCDwkJG0
# IAkyzjfL8NgBn0kc5VZTztnstjwoWvTWHTXUXDPtyIg12vfg5hzLdc1GJhqt1AVA
# DDgp4d/k0tvICm1UQMoHqGrZ59zIWEBHq3aNdIiAl2ckMiLYsaf5Tn+FmvRdAgMB
# AAGjggI1MIICMTAfBgNVHSMEGDAWgBRoN+Drtjv4XxGG+/5hewiIZfROQjAdBgNV
# HQ4EFgQUsPO2uKK+TDLSX5Ez4DXbRIGMdIkwLgYDVR0RBCcwJaAjBggrBgEFBQcI
# A6AXMBUME1VTLURFTEFXQVJFLTQxNTI5NTQwDgYDVR0PAQH/BAQDAgeAMBMGA1Ud
# JQQMMAoGCCsGAQUFBwMDMIG1BgNVHR8Ega0wgaowU6BRoE+GTWh0dHA6Ly9jcmwz
# LmRpZ2ljZXJ0LmNvbS9EaWdpQ2VydFRydXN0ZWRHNENvZGVTaWduaW5nUlNBNDA5
# NlNIQTM4NDIwMjFDQTEuY3JsMFOgUaBPhk1odHRwOi8vY3JsNC5kaWdpY2VydC5j
# b20vRGlnaUNlcnRUcnVzdGVkRzRDb2RlU2lnbmluZ1JTQTQwOTZTSEEzODQyMDIx
# Q0ExLmNybDA9BgNVHSAENjA0MDIGBWeBDAEDMCkwJwYIKwYBBQUHAgEWG2h0dHA6
# Ly93d3cuZGlnaWNlcnQuY29tL0NQUzCBlAYIKwYBBQUHAQEEgYcwgYQwJAYIKwYB
# BQUHMAGGGGh0dHA6Ly9vY3NwLmRpZ2ljZXJ0LmNvbTBcBggrBgEFBQcwAoZQaHR0
# cDovL2NhY2VydHMuZGlnaWNlcnQuY29tL0RpZ2lDZXJ0VHJ1c3RlZEc0Q29kZVNp
# Z25pbmdSU0E0MDk2U0hBMzg0MjAyMUNBMS5jcnQwDAYDVR0TAQH/BAIwADANBgkq
# hkiG9w0BAQsFAAOCAgEAOLIzfXbFw3b1+5oTm9q/ovV5uSCa26vf0QR+auJmfcaZ
# 24S2C3Mlc/TQ9NEodiJd8SJdNGlpGObtQdzi61ykbUGcxR6i4YI8kZ4WerMr5fCd
# 4NGRToXmn7ZC9qxhHoMRDOH59W+NY4XkouE79XfQgnNjwVyAorb0oSJ94DS0eBAk
# S5Z/aNHeoHSND7CL/BGMKZIfy5oeQudafNOM8dyt9hAqJf+nOrpvOwlLpJgXTYNH
# eGxP4cyb3EQTDMrXYxHckSi4usUq1iW5pCdPA/pQt5BNmGoB0azVdA73Vym/UyR5
# vIz+v1OAWaPdvRvm/26hGyr+WzsR6WIzIBg2GB9k0uv+1bKdqL0yu1gNmcV8LZHR
# LNTMx1DX85RKjXNcHcQYjDH2R5oy0CHmV7QSwFJAc2a4+h+7TcmZsbdKlPHi6bFW
# /G5HDPWt/F9oQ3OZknWdTigo4vuYl7jcpoSMZgBVGv9EXTrpkLaoCxBn48i7UJ8O
# gZzskxcjBx9dObtu9kEA1IndCHoqiqFGakdYI2+LjIr+cPT58XvMQjm7sfeeTTTy
# +amZ+ONAscTa1y8jOHIycnMZSKjh/OGw0iApuTUREPB68c6tdsjODU5GF8u5k28M
# QVuSQzZbKN+t8FyPh2F4HT9tfvTJxSJxArh/YiXqyyjc/B5AIpwxMIHyw22EzbYx
# ghAnMIIQIwIBATB9MGkxCzAJBgNVBAYTAlVTMRcwFQYDVQQKEw5EaWdpQ2VydCwg
# SW5jLjFBMD8GA1UEAxM4RGlnaUNlcnQgVHJ1c3RlZCBHNCBDb2RlIFNpZ25pbmcg
# UlNBNDA5NiBTSEEzODQgMjAyMSBDQTECEAF7gncXSKMwxPro7mDNAR8wDQYJYIZI
# AWUDBAIBBQCgfDAQBgorBgEEAYI3AgEMMQIwADAZBgkqhkiG9w0BCQMxDAYKKwYB
# BAGCNwIBBDAcBgorBgEEAYI3AgELMQ4wDAYKKwYBBAGCNwIBFTAvBgkqhkiG9w0B
# CQQxIgQg1AljuYeqvi49vnXCywXAhIFjVg48j4o+jvL8w0RAneowDQYJKoZIhvcN
# AQEBBQAEggGAeb62pC8myHbMsNDIs3b6FhPPeM08x7F485NWnUuGVa/WUPiv4XX3
# cX0cPcYSrfyfbkyjU8493foNSi/KPk57T9xo+2E7luxHyGzFYttCUcEDi5kg+Xqr
# f4BeLFTxkNqIrXlEnQxCS5NDLOlfg4DHGxlgNnw41TuOeLlFFkqyf24VFV5f1fbT
# WZU8WJibha7n8EgYKDqP6XmBeo1FOqb9Celg2uQ1s/q1XW+shnDaZ9AuoLK12MIG
# jfM29muE4jvgfOrAIO9HfffAQE01c9+mGVojf1vbryWkTfq8mDsO+a2p2T+iw/gS
# TscAaqtU8/ZzgAhOweHrMg9QIAFj2HbYMUpbq3T3wJwi2ylrKtzIUkHz/d5Ov1be
# espCEAnUWBkmBNAF0vRhjhlDcX4MichGrQeJ8NCwihlVYSWFeX2zYQYwp7QE/N67
# ibUZt+GXwX07JaUULOfj6hLAhUghuZ6LNxqyU+X7q4M+BM7Sb4j9aV/f5H9wlxLn
# q8L9vD249DTioYINfTCCDXkGCisGAQQBgjcDAwExgg1pMIINZQYJKoZIhvcNAQcC
# oIINVjCCDVICAQMxDzANBglghkgBZQMEAgEFADB3BgsqhkiG9w0BCRABBKBoBGYw
# ZAIBAQYJYIZIAYb9bAcBMDEwDQYJYIZIAWUDBAIBBQAEIP0/ntvDHgU6jHo1L0Jx
# usZvgNvI49Ea1UMJk+1C7ai1AhB1SBmsI8S47fp42SKvNZiMGA8yMDIyMDEzMTE4
# NDc1MFqgggo3MIIE/jCCA+agAwIBAgIQDUJK4L46iP9gQCHOFADw3TANBgkqhkiG
# 9w0BAQsFADByMQswCQYDVQQGEwJVUzEVMBMGA1UEChMMRGlnaUNlcnQgSW5jMRkw
# FwYDVQQLExB3d3cuZGlnaWNlcnQuY29tMTEwLwYDVQQDEyhEaWdpQ2VydCBTSEEy
# IEFzc3VyZWQgSUQgVGltZXN0YW1waW5nIENBMB4XDTIxMDEwMTAwMDAwMFoXDTMx
# MDEwNjAwMDAwMFowSDELMAkGA1UEBhMCVVMxFzAVBgNVBAoTDkRpZ2lDZXJ0LCBJ
# bmMuMSAwHgYDVQQDExdEaWdpQ2VydCBUaW1lc3RhbXAgMjAyMTCCASIwDQYJKoZI
# hvcNAQEBBQADggEPADCCAQoCggEBAMLmYYRnxYr1DQikRcpja1HXOhFCvQp1dU2U
# tAxQtSYQ/h3Ib5FrDJbnGlxI70Tlv5thzRWRYlq4/2cLnGP9NmqB+in43Stwhd4C
# GPN4bbx9+cdtCT2+anaH6Yq9+IRdHnbJ5MZ2djpT0dHTWjaPxqPhLxs6t2HWc+xO
# bTOKfF1FLUuxUOZBOjdWhtyTI433UCXoZObd048vV7WHIOsOjizVI9r0TXhG4wOD
# MSlKXAwxikqMiMX3MFr5FK8VX2xDSQn9JiNT9o1j6BqrW7EdMMKbaYK02/xWVLwf
# oYervnpbCiAvSwnJlaeNsvrWY4tOpXIc7p96AXP4Gdb+DUmEvQECAwEAAaOCAbgw
# ggG0MA4GA1UdDwEB/wQEAwIHgDAMBgNVHRMBAf8EAjAAMBYGA1UdJQEB/wQMMAoG
# CCsGAQUFBwMIMEEGA1UdIAQ6MDgwNgYJYIZIAYb9bAcBMCkwJwYIKwYBBQUHAgEW
# G2h0dHA6Ly93d3cuZGlnaWNlcnQuY29tL0NQUzAfBgNVHSMEGDAWgBT0tuEgHf4p
# rtLkYaWyoiWyyBc1bjAdBgNVHQ4EFgQUNkSGjqS6sGa+vCgtHUQ23eNqerwwcQYD
# VR0fBGowaDAyoDCgLoYsaHR0cDovL2NybDMuZGlnaWNlcnQuY29tL3NoYTItYXNz
# dXJlZC10cy5jcmwwMqAwoC6GLGh0dHA6Ly9jcmw0LmRpZ2ljZXJ0LmNvbS9zaGEy
# LWFzc3VyZWQtdHMuY3JsMIGFBggrBgEFBQcBAQR5MHcwJAYIKwYBBQUHMAGGGGh0
# dHA6Ly9vY3NwLmRpZ2ljZXJ0LmNvbTBPBggrBgEFBQcwAoZDaHR0cDovL2NhY2Vy
# dHMuZGlnaWNlcnQuY29tL0RpZ2lDZXJ0U0hBMkFzc3VyZWRJRFRpbWVzdGFtcGlu
# Z0NBLmNydDANBgkqhkiG9w0BAQsFAAOCAQEASBzctemaI7znGucgDo5nRv1CclF0
# CiNHo6uS0iXEcFm+FKDlJ4GlTRQVGQd58NEEw4bZO73+RAJmTe1ppA/2uHDPYuj1
# UUp4eTZ6J7fz51Kfk6ftQ55757TdQSKJ+4eiRgNO/PT+t2R3Y18jUmmDgvoaU+2Q
# zI2hF3MN9PNlOXBL85zWenvaDLw9MtAby/Vh/HUIAHa8gQ74wOFcz8QRcucbZEnY
# Ipp1FUL1LTI4gdr0YKK6tFL7XOBhJCVPst/JKahzQ1HavWPWH1ub9y4bTxMd90oN
# cX6Xt/Q/hOvB46NJofrOp79Wz7pZdmGJX36ntI5nePk2mOHLKNpbh6aKLzCCBTEw
# ggQZoAMCAQICEAqhJdbWMht+QeQF2jaXwhUwDQYJKoZIhvcNAQELBQAwZTELMAkG
# A1UEBhMCVVMxFTATBgNVBAoTDERpZ2lDZXJ0IEluYzEZMBcGA1UECxMQd3d3LmRp
# Z2ljZXJ0LmNvbTEkMCIGA1UEAxMbRGlnaUNlcnQgQXNzdXJlZCBJRCBSb290IENB
# MB4XDTE2MDEwNzEyMDAwMFoXDTMxMDEwNzEyMDAwMFowcjELMAkGA1UEBhMCVVMx
# FTATBgNVBAoTDERpZ2lDZXJ0IEluYzEZMBcGA1UECxMQd3d3LmRpZ2ljZXJ0LmNv
# bTExMC8GA1UEAxMoRGlnaUNlcnQgU0hBMiBBc3N1cmVkIElEIFRpbWVzdGFtcGlu
# ZyBDQTCCASIwDQYJKoZIhvcNAQEBBQADggEPADCCAQoCggEBAL3QMu5LzY9/3am6
# gpnFOVQoV7YjSsQOB0UzURB90Pl9TWh+57ag9I2ziOSXv2MhkJi/E7xX08PhfgjW
# ahQAOPcuHjvuzKb2Mln+X2U/4Jvr40ZHBhpVfgsnfsCi9aDg3iI/Dv9+lfvzo7oi
# PhisEeTwmQNtO4V8CdPuXciaC1TjqAlxa+DPIhAPdc9xck4Krd9AOly3UeGheRTG
# TSQjMF287DxgaqwvB8z98OpH2YhQXv1mblZhJymJhFHmgudGUP2UKiyn5HU+upgP
# hH+fMRTWrdXyZMt7HgXQhBlyF/EXBu89zdZN7wZC/aJTKk+FHcQdPK/P2qwQ9d2s
# rOlW/5MCAwEAAaOCAc4wggHKMB0GA1UdDgQWBBT0tuEgHf4prtLkYaWyoiWyyBc1
# bjAfBgNVHSMEGDAWgBRF66Kv9JLLgjEtUYunpyGd823IDzASBgNVHRMBAf8ECDAG
# AQH/AgEAMA4GA1UdDwEB/wQEAwIBhjATBgNVHSUEDDAKBggrBgEFBQcDCDB5Bggr
# BgEFBQcBAQRtMGswJAYIKwYBBQUHMAGGGGh0dHA6Ly9vY3NwLmRpZ2ljZXJ0LmNv
# bTBDBggrBgEFBQcwAoY3aHR0cDovL2NhY2VydHMuZGlnaWNlcnQuY29tL0RpZ2lD
# ZXJ0QXNzdXJlZElEUm9vdENBLmNydDCBgQYDVR0fBHoweDA6oDigNoY0aHR0cDov
# L2NybDQuZGlnaWNlcnQuY29tL0RpZ2lDZXJ0QXNzdXJlZElEUm9vdENBLmNybDA6
# oDigNoY0aHR0cDovL2NybDMuZGlnaWNlcnQuY29tL0RpZ2lDZXJ0QXNzdXJlZElE
# Um9vdENBLmNybDBQBgNVHSAESTBHMDgGCmCGSAGG/WwAAgQwKjAoBggrBgEFBQcC
# ARYcaHR0cHM6Ly93d3cuZGlnaWNlcnQuY29tL0NQUzALBglghkgBhv1sBwEwDQYJ
# KoZIhvcNAQELBQADggEBAHGVEulRh1Zpze/d2nyqY3qzeM8GN0CE70uEv8rPAwL9
# xafDDiBCLK938ysfDCFaKrcFNB1qrpn4J6JmvwmqYN92pDqTD/iy0dh8GWLoXoIl
# HsS6HHssIeLWWywUNUMEaLLbdQLgcseY1jxk5R9IEBhfiThhTWJGJIdjjJFSLK8p
# ieV4H9YLFKWA1xJHcLN11ZOFk362kmf7U2GJqPVrlsD0WGkNfMgBsbkodbeZY4Ui
# jGHKeZR+WfyMD+NvtQEmtmyl7odRIeRYYJu6DC0rbaLEfrvEJStHAgh8Sa4TtuF8
# QkIoxhhWz0E0tmZdtnR79VYzIi8iNrJLokqV2PWmjlIxggKGMIICggIBATCBhjBy
# MQswCQYDVQQGEwJVUzEVMBMGA1UEChMMRGlnaUNlcnQgSW5jMRkwFwYDVQQLExB3
# d3cuZGlnaWNlcnQuY29tMTEwLwYDVQQDEyhEaWdpQ2VydCBTSEEyIEFzc3VyZWQg
# SUQgVGltZXN0YW1waW5nIENBAhANQkrgvjqI/2BAIc4UAPDdMA0GCWCGSAFlAwQC
# AQUAoIHRMBoGCSqGSIb3DQEJAzENBgsqhkiG9w0BCRABBDAcBgkqhkiG9w0BCQUx
# DxcNMjIwMTMxMTg0NzUwWjArBgsqhkiG9w0BCRACDDEcMBowGDAWBBTh14Ko4ZG+
# 72vKFpG1qrSUpiSb8zAvBgkqhkiG9w0BCQQxIgQggMEfZ/CydiiND+FAKAeHoskD
# +BsFABvX4Zsn7ksK4pcwNwYLKoZIhvcNAQkQAi8xKDAmMCQwIgQgsxCQBrwK2YMH
# kVcp4EQDQVyD4ykrYU8mlkyNNXHs9akwDQYJKoZIhvcNAQEBBQAEggEAaZo4IIl7
# IG3SvVKEp1uZErJnYX0ID/eA5+ElxOpe3iN4LkdQidrXuZoHEHbmkcK+nYidMxkt
# WGqjsvKVwQW+WaguvBJC2NkhmYC0X7cD2S7koFwlHvBNaxqEPrFhW2BuT5S4tMSN
# ifXDPPiaV6qnGm2zNKrQZZ0+hlnuQztDZqhZzhX2IQCeXHs8+VrK0Ts0ryif/6Td
# 0e1bMCAhjt/22QWIfOY1pHY0+dL0jFgu1ZtNk6tfLhMO9SXIqDG791NEDuO73ZEI
# 21QSbuICmOLeNaOjFgEZ3AjqG7ktOrLTxJ4ax0mJMsuPEhj2x+YpXbpYHOnD2HOU
# zoel6Pavqx6EtQ==
# SIG # End signature block
