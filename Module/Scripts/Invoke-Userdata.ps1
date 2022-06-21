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
    Invoke-Userdata retrieves and executes the userdata from metadata
    Currently, it supports powershell (+ with argument) and batch script.
-------------------------------------------------------------------------------------------------------------#>
function Invoke-Userdata
{
  param(
    [Parameter(Mandatory = $false,Position = 0)]
    [string]$Username,

    [Parameter(Mandatory = $false,Position = 1)]
    [string]$Password,

    [Parameter(Mandatory = $false)]
    [switch]$OnlyUnregister,

    [Parameter(Mandatory = $false)]
    [switch]$OnlyExecute,

    [Parameter(Mandatory = $false)]
    [switch]$FromPersist,

    [Parameter(Mandatory = $false)]
    $FinalizeTelemetry
  )

  $handleUserDataState = Get-LaunchConfig -Key HandleUserData
  if (!$handleUserDataState)
  {
    Write-Log "Handle user data is disabled"
    return $false
  }

  # Before calling any function, initialize the log with filename
  Initialize-Log -FileName "UserdataExecution.log"

  try
  {
    $scheduleName = "Userdata Execution"

    if ($OnlyUnregister)
    {
      Register-FunctionScheduler -Function $MyInvocation.MyCommand -ScheduleName $scheduleName -Unregister
      return $null
    }

    Write-Log "Userdata execution begins"

    $regexFormat = "(?is){0}(.*?){1}"

    $powershellContent = ""
    $powershellArgs = ""
    $batchContent = ""

    $fileLocation = Join-Path $env:LOCALAPPDATA -ChildPath "Temp\Amazon\EC2-Windows\Launch\InvokeUserData"
    New-Item -Item Directory $fileLocation -Force

    # Add Administrators, LocalSystem, and Current User FullControl
    $ACL = Get-Acl -Path $fileLocation
    $LocalSystem = New-Object System.Security.Principal.SecurityIdentifier 'S-1-5-18'
    $AllowLocalSystemFullControl = New-Object System.Security.AccessControl.FileSystemAccessRule (
      $LocalSystem,
      [System.Security.AccessControl.FileSystemRights]::FullControl,
      ([System.Security.AccessControl.InheritanceFlags]::ContainerInherit -bor [System.Security.AccessControl.InheritanceFlags]::ObjectInherit),
      [System.Security.AccessControl.PropagationFlags]::None,
      [System.Security.AccessControl.AccessControlType]::Allow
    )

    $AdministratorsGroup = New-Object System.Security.Principal.SecurityIdentifier 'S-1-5-32-544'
    $AllowAdministratorsFullControl = New-Object System.Security.AccessControl.FileSystemAccessRule (
      $AdministratorsGroup,
      [System.Security.AccessControl.FileSystemRights]::FullControl,
      ([System.Security.AccessControl.InheritanceFlags]::ContainerInherit -bor [System.Security.AccessControl.InheritanceFlags]::ObjectInherit),
      [System.Security.AccessControl.PropagationFlags]::None,
      [System.Security.AccessControl.AccessControlType]::Allow
    )

    $CurrentUser = [System.Security.Principal.WindowsIdentity]::GetCurrent().User
    $AllowCurrentUserFullControl = New-Object System.Security.AccessControl.FileSystemAccessRule (
      $CurrentUser,
      [System.Security.AccessControl.FileSystemRights]::FullControl,
      ([System.Security.AccessControl.InheritanceFlags]::ContainerInherit -bor [System.Security.AccessControl.InheritanceFlags]::ObjectInherit),
      [System.Security.AccessControl.PropagationFlags]::None,
      [System.Security.AccessControl.AccessControlType]::Allow
    )

    $ACL.AddAccessRule($AllowLocalSystemFullControl)
    $ACL.AddAccessRule($AllowAdministratorsFullControl)
    $ACL.AddAccessRule($AllowCurrentUserFullControl)
    (Get-Item $fileLocation).SetAccessControl($ACL)

    # Remove inheritance and dont keep inherited permissions
    $ACL = Get-Acl -Path $fileLocation
    $ACL.SetAccessRuleProtection($true,$false)
    (Get-Item $fileLocation).SetAccessControl($ACL)

    $userdata = Get-Metadata -UrlFragment "user-data"
    if (-not $userdata)
    {
      # If no userdata is provided, unregister the scheduled task if scheduled before.
      Register-FunctionScheduler -Function $MyInvocation.MyCommand -ScheduleName $scheduleName -Unregister
      Write-Log "Userdata was not provided"
      return $null
    }

    $userdataContent = $userdata.Trim()

    # Userdata is executed as local admin by default
    # But if password is empty, userdata is exeucted as local system by default
    $runAsLocalSystem = -not $Username -or -not $Password
    $persist = $false

    # Userdata can be persistent if <persist> tag is specified in userdata.
    # Parse persist from userdata and schedule a task if persist is true
    $persistRegex = [regex]($regexFormat -f "<persist>","</persist>")
    $persistMatch = $persistRegex.Matches($userdataContent)
    if ($persistMatch.Success -and $persistMatch.Captures.Count -eq 1 -and $persistMatch.Groups.Count -eq 2)
    {
      $persistValue = $persistMatch.Groups[1].Value
      Write-Log ("<persist> tag was provided: {0}" -f $persistValue)
      if ($persistValue -ieq "true")
      {
        Write-Log "Running userdata on every boot"
        $persist = $true
      }
    }
    else
    {
      Write-Log "Zero or more than one <persist> tag was not provided"
    }

    function Send-IsUserDataScheduledPerBoot
    {
      param(
        [Parameter(Mandatory = $true,Position = 0)]
        [bool]$Value
      )

      # We want to upload this telemetry field one time only. We filter by $FromPersist
      # as an attempt to filter out calls by the scheduled task. We are trying to only
      # upload this field the first time that the agent runs (when the instance is first
      # initialized).
      if (!$FromPersist)
      {
        Send-TelemetryBool -FieldName "IsUserDataScheduledPerBoot" -Value $Value
      }
    }

    # If we are only executing (running per boot), don't schedule as a separate task if persist is true
    if ($OnlyExecute)
    {
      Send-IsUserDataScheduledPerBoot -Value $false
      Write-Log ("Persist is {0}, executing inline and not as a separate task" -f $persist)
    }
    elseif ($persist)
    {
      Send-IsUserDataScheduledPerBoot -Value $true
      Register-FunctionScheduler -Function $MyInvocation.MyCommand -Arguments "-FromPersist" -ScheduleName $scheduleName
    }
    else
    {
      Send-IsUserDataScheduledPerBoot -Value $false
      Write-Log "Unregistering the persist scheduled task"
      Register-FunctionScheduler -Function $MyInvocation.MyCommand -ScheduleName $scheduleName -Unregister
      if ($FromPersist)
      {
        # If the function was called from scheduled task and persist tag is not found, don't execute it at all.
        return $persist
      }
    }

    if ($null -ne $FinalizeTelemetry) {
      # Must finalize telemetry and close the serial port before executing userdata. Otherwise console-log
      # output, such as the valuable Windows-Ready message, will be delayed. Such a scenario would be
      # particularly bad for customers with long-running userdata.
      & $FinalizeTelemetry
    }

    # Parse runAsLocalSystem from userdata
    $runAsLocalSystemRegex = [regex]($regexFormat -f "<runAsLocalSystem>","</runAsLocalSystem>")
    $runAsLocalSystemMatch = $runAsLocalSystemRegex.Matches($userdataContent)
    if ($runAsLocalSystemMatch.Success -and $runAsLocalSystemMatch.Captures.Count -eq 1 -and $runAsLocalSystemMatch.Groups.Count -eq 2)
    {
      $runAsLocalSystemValue = $runAsLocalSystemMatch.Groups[1].Value
      Write-Log ("<runAsLocalSystem> tag was provided: {0}" -f $runAsLocalSystemValue)
      if ($runAsLocalSystemValue -ieq "true")
      {
        Write-Log "Running userdata as local system"
        $runAsLocalSystem = $true
      }
    }
    else
    {
      Write-Log "Zero or more than one <runAsLocalSystem> tag was not provided"
    }

    # Parse script from userdata
    $scriptRegex = [regex]($regexFormat -f "<script>","</script>")
    $scriptMatch = $scriptRegex.Matches($userdataContent)
    if ($scriptMatch.Success -and $scriptMatch.Captures.Count -eq 1)
    {
      $batchContent = $scriptMatch.Groups[1].Value
    }
    else
    {
      Write-Log "Zero or more than one <script> tag was not provided"
    }

    # Parse powershell from userdata
    $powershellRegex = [regex]($regexFormat -f "<powershell>","</powershell>")
    $powershellMatch = $powershellRegex.Matches($userdataContent)
    if ($powershellMatch.Success -and $powershellMatch.Captures.Count -eq 1)
    {
      $powershellContent = $powershellMatch.Groups[1].Value
    }
    else
    {
      Write-Log "Zero or more than one <powershell> tag was not provided"
    }

    # Parse powershell arguments from userdata
    $powershellArgsRegex = [regex]($regexFormat -f "<powershellArguments>","</powershellArguments>")
    $powershellArgsMatch = $powershellArgsRegex.Matches($userdataContent)
    if ($powershellArgsMatch.Success -and $powershellArgsMatch.Captures.Count -eq 1)
    {
      $powershellArgs = $powershellArgsMatch.Groups[1].Value
    }
    else
    {
      Write-Log "Zero or more than one <powershellArguments> tag was not provided"
    }

    # Execute batch commands first
    if ($batchContent)
    {
      Write-Log "<script> tag was provided.. running script content"

      $errorFile = Join-Path $fileLocation -ChildPath "InvokeUserdataErrors.log"
      $outputFile = Join-Path $fileLocation -ChildPath "InvokeUserdataOutput.log"

      $filePath = "$env:LOCALAPPDATA\Temp\Amazon\EC2-Windows\Launch\InvokeUserData\UserScript.bat"
      $batchContent | Out-File $filePath -Encoding ascii

      if ($runAsLocalSystem)
      {
        Start-Process $script:cmdPath -ArgumentList "/C",`"$filePath`" -Wait -NoNewWindow -RedirectStandardOutput $outputFile -RedirectStandardError $errorFile
      }
      else
      {
        Invoke-CmdAsAdmin -Username $Username -Password $Password -Command "$script:cmdPath /C `"`"$filePath`" 1> `"$outputFile`" 2> `"$errorFile`"`""
      }

      # Originally UserScript.bat, outputFile & errorFile are all stored in Temp.
      # Changing the path of theses filesd may break customer's usage.
      # In order to continue allowing customer access these files from Temp folder, these files willl be copied to Temp folder
      Copy-Item -Path "$errorFile" -Destination "C:\Windows\Temp"
      Copy-Item -Path "$outputFile" -Destination "C:\Windows\Temp"
      Copy-Item -Path "$filePath" -Destination "C:\Windows\Temp"

      $output = Get-Content $errorFile -Raw
      if ($output)
      {
        Write-Log ("Message: The errors from user scripts: {0}" -f $output)
      }

      $output = Get-Content $outputFile -Raw
      if ($output)
      {
        Write-Log ("Message: The output from user scripts: {0}" -f $output)
      }
    }

    # Execute powershell commands
    if ($powershellContent)
    {
      Write-Log "<powershell> tag was provided.. running powershell content"

      $errorFile = Join-Path $fileLocation -ChildPath "InvokeUserdataErrors.log"
      $outputFile = Join-Path $fileLocation -ChildPath "InvokeUserdataOutput.log"

      $filePath = "$env:LOCALAPPDATA\Temp\Amazon\EC2-Windows\Launch\InvokeUserData\UserScript.ps1"
      $powershellContent | Out-File $filePath

      if (-not $powershellArgs)
      {
        # If argument is provided, we let user to define the entire argument portion
        # But if argument is not provided, argument is set for execution policy
        $powershellArgs = "-ExecutionPolicy Unrestricted"
      }

      if ($runAsLocalSystem)
      {
        Start-Process $script:psPath -ArgumentList $powershellArgs,".",`'$filePath`' -Wait -NoNewWindow -RedirectStandardOutput $outputFile -RedirectStandardError $errorFile
      }
      else
      {
        # If user rename the administrator, we need to get the correct name before executing powershell user data
        $user = Get-CimInstance -ClassName Win32_UserAccount -Filter "LocalAccount = 'True'" | Where-Object { $_.SID -like 'S-1-5-21-*' -and $_.SID -like '*-500' }
        $Username = $user.Name
        Invoke-CmdAsAdmin -Username $Username -Password $Password -Command "$script:cmdPath /C `"$script:psPath $powershellArgs . `'$filePath`' 1> `"$outputFile`" 2> `"$errorFile`"`""
      }

      # Originally UserScript.ps1, outputFile & errorFile are all stored in Temp.
      # Changing the path of theses filesd may break customer's usage.
      # In order to continue allowing customer access these files from Temp folder, these files willl be copied to Temp folder
      Copy-Item -Path "$errorFile" -Destination "C:\Windows\Temp"
      Copy-Item -Path "$outputFile" -Destination "C:\Windows\Temp"
      Copy-Item -Path "$filePath" -Destination "C:\Windows\Temp"

      $output = Get-Content $errorFile -Raw
      if ($output)
      {
        Write-Log ("Message: The errors from user scripts: {0}" -f $output)
      }

      $output = Get-Content $outputFile -Raw
      if ($output)
      {
        Write-Log ("Message: The output from user scripts: {0}" -f $output)
      }
    }

  }
  catch
  {
    Write-ErrorLog ("Unable to execute userdata: {0}" -f $_.Exception.Message)
  }
  finally
  {
    $Password = ""

    Write-Log "Userdata execution done"

    # Before finishing the script, complete the log.
    Complete-Log
  }

  return $persist
}

# SIG # Begin signature block
# MIIfJwYJKoZIhvcNAQcCoIIfGDCCHxQCAQExDzANBglghkgBZQMEAgEFADB5Bgor
# BgEEAYI3AgEEoGswaTA0BgorBgEEAYI3AgEeMCYCAwEAAAQQH8w7YFlLCE63JNLG
# KX7zUQIBAAIBAAIBAAIBAAIBADAxMA0GCWCGSAFlAwQCAQUABCCfbLVH2jQOX9R5
# KudzS40O5E7xi5C40NLuPeUECpjG6aCCDlUwggawMIIEmKADAgECAhAIrUCyYNKc
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
# ghAoMIIQJAIBATB9MGkxCzAJBgNVBAYTAlVTMRcwFQYDVQQKEw5EaWdpQ2VydCwg
# SW5jLjFBMD8GA1UEAxM4RGlnaUNlcnQgVHJ1c3RlZCBHNCBDb2RlIFNpZ25pbmcg
# UlNBNDA5NiBTSEEzODQgMjAyMSBDQTECEAF7gncXSKMwxPro7mDNAR8wDQYJYIZI
# AWUDBAIBBQCgfDAQBgorBgEEAYI3AgEMMQIwADAZBgkqhkiG9w0BCQMxDAYKKwYB
# BAGCNwIBBDAcBgorBgEEAYI3AgELMQ4wDAYKKwYBBAGCNwIBFTAvBgkqhkiG9w0B
# CQQxIgQgDNSyfDzl9/X9BCpzdN5p3i6mIzUL/a1ZbYEAX8IBmSowDQYJKoZIhvcN
# AQEBBQAEggGAn/YE1Nphc6EOSxSXoInTFM/MH2Obd8NFtcdsmCtE0t3uSO8klmg8
# Wz7D/T7yQJtyLDdICHmjaFrfU6Pyww8FxEkrujkvIvps+mSi/fFyr2lTxQW/skNa
# Z/y2TAgO3f1qXnDnjnlG1h/Lk34KskVBkK2sLL5RBmIebrt/MkOgtO56HqsubpF/
# T/1y6v4upMcq4u3rWcxNRCkkAeOZQDPpUU4/59eaLUglPX0yIx4++xMf/JtYocA1
# OiH1wGrxrcaTUi2sowEYbIfZaRY5Off/P8JS5uHDPJtInFeRWmyXU8qaDbaKktcD
# RTewY+RmHVSF89tQbyBoNR0u+yOZkaaCL7zU6mTHK/kaCWqjLlxSca6DQgcp818J
# KUFCztB8DUXGmmUWjVaoSItR0jqyAfZZQwg7xBSDBQodBs9UBRxcmXI2iHsFVej+
# 6v4g8VKlHu+tVQgmNbr7qxlDaGqEgMDOko/g5zSurtVjNaGnt2wvv53WYaTHWBdj
# JNjkTI5h9GxMoYINfjCCDXoGCisGAQQBgjcDAwExgg1qMIINZgYJKoZIhvcNAQcC
# oIINVzCCDVMCAQMxDzANBglghkgBZQMEAgEFADB4BgsqhkiG9w0BCRABBKBpBGcw
# ZQIBAQYJYIZIAYb9bAcBMDEwDQYJYIZIAWUDBAIBBQAEINOSgSkBcL9eQOy0/F51
# +BZzEp2LJZOJaozrOhXR6MOYAhEA+bK8hK8JEsD88r/I/1lznRgPMjAyMjAxMzEx
# ODQ4MjRaoIIKNzCCBP4wggPmoAMCAQICEA1CSuC+Ooj/YEAhzhQA8N0wDQYJKoZI
# hvcNAQELBQAwcjELMAkGA1UEBhMCVVMxFTATBgNVBAoTDERpZ2lDZXJ0IEluYzEZ
# MBcGA1UECxMQd3d3LmRpZ2ljZXJ0LmNvbTExMC8GA1UEAxMoRGlnaUNlcnQgU0hB
# MiBBc3N1cmVkIElEIFRpbWVzdGFtcGluZyBDQTAeFw0yMTAxMDEwMDAwMDBaFw0z
# MTAxMDYwMDAwMDBaMEgxCzAJBgNVBAYTAlVTMRcwFQYDVQQKEw5EaWdpQ2VydCwg
# SW5jLjEgMB4GA1UEAxMXRGlnaUNlcnQgVGltZXN0YW1wIDIwMjEwggEiMA0GCSqG
# SIb3DQEBAQUAA4IBDwAwggEKAoIBAQDC5mGEZ8WK9Q0IpEXKY2tR1zoRQr0KdXVN
# lLQMULUmEP4dyG+RawyW5xpcSO9E5b+bYc0VkWJauP9nC5xj/TZqgfop+N0rcIXe
# AhjzeG28ffnHbQk9vmp2h+mKvfiEXR52yeTGdnY6U9HR01o2j8aj4S8bOrdh1nPs
# Tm0zinxdRS1LsVDmQTo3VobckyON91Al6GTm3dOPL1e1hyDrDo4s1SPa9E14RuMD
# gzEpSlwMMYpKjIjF9zBa+RSvFV9sQ0kJ/SYjU/aNY+gaq1uxHTDCm2mCtNv8VlS8
# H6GHq756WwogL0sJyZWnjbL61mOLTqVyHO6fegFz+BnW/g1JhL0BAgMBAAGjggG4
# MIIBtDAOBgNVHQ8BAf8EBAMCB4AwDAYDVR0TAQH/BAIwADAWBgNVHSUBAf8EDDAK
# BggrBgEFBQcDCDBBBgNVHSAEOjA4MDYGCWCGSAGG/WwHATApMCcGCCsGAQUFBwIB
# FhtodHRwOi8vd3d3LmRpZ2ljZXJ0LmNvbS9DUFMwHwYDVR0jBBgwFoAU9LbhIB3+
# Ka7S5GGlsqIlssgXNW4wHQYDVR0OBBYEFDZEho6kurBmvrwoLR1ENt3janq8MHEG
# A1UdHwRqMGgwMqAwoC6GLGh0dHA6Ly9jcmwzLmRpZ2ljZXJ0LmNvbS9zaGEyLWFz
# c3VyZWQtdHMuY3JsMDKgMKAuhixodHRwOi8vY3JsNC5kaWdpY2VydC5jb20vc2hh
# Mi1hc3N1cmVkLXRzLmNybDCBhQYIKwYBBQUHAQEEeTB3MCQGCCsGAQUFBzABhhho
# dHRwOi8vb2NzcC5kaWdpY2VydC5jb20wTwYIKwYBBQUHMAKGQ2h0dHA6Ly9jYWNl
# cnRzLmRpZ2ljZXJ0LmNvbS9EaWdpQ2VydFNIQTJBc3N1cmVkSURUaW1lc3RhbXBp
# bmdDQS5jcnQwDQYJKoZIhvcNAQELBQADggEBAEgc3LXpmiO85xrnIA6OZ0b9QnJR
# dAojR6OrktIlxHBZvhSg5SeBpU0UFRkHefDRBMOG2Tu9/kQCZk3taaQP9rhwz2Lo
# 9VFKeHk2eie38+dSn5On7UOee+e03UEiifuHokYDTvz0/rdkd2NfI1Jpg4L6GlPt
# kMyNoRdzDfTzZTlwS/Oc1np72gy8PTLQG8v1Yfx1CAB2vIEO+MDhXM/EEXLnG2RJ
# 2CKadRVC9S0yOIHa9GCiurRS+1zgYSQlT7LfySmoc0NR2r1j1h9bm/cuG08THfdK
# DXF+l7f0P4TrweOjSaH6zqe/Vs+6WXZhiV9+p7SOZ3j5NpjhyyjaW4emii8wggUx
# MIIEGaADAgECAhAKoSXW1jIbfkHkBdo2l8IVMA0GCSqGSIb3DQEBCwUAMGUxCzAJ
# BgNVBAYTAlVTMRUwEwYDVQQKEwxEaWdpQ2VydCBJbmMxGTAXBgNVBAsTEHd3dy5k
# aWdpY2VydC5jb20xJDAiBgNVBAMTG0RpZ2lDZXJ0IEFzc3VyZWQgSUQgUm9vdCBD
# QTAeFw0xNjAxMDcxMjAwMDBaFw0zMTAxMDcxMjAwMDBaMHIxCzAJBgNVBAYTAlVT
# MRUwEwYDVQQKEwxEaWdpQ2VydCBJbmMxGTAXBgNVBAsTEHd3dy5kaWdpY2VydC5j
# b20xMTAvBgNVBAMTKERpZ2lDZXJ0IFNIQTIgQXNzdXJlZCBJRCBUaW1lc3RhbXBp
# bmcgQ0EwggEiMA0GCSqGSIb3DQEBAQUAA4IBDwAwggEKAoIBAQC90DLuS82Pf92p
# uoKZxTlUKFe2I0rEDgdFM1EQfdD5fU1ofue2oPSNs4jkl79jIZCYvxO8V9PD4X4I
# 1moUADj3Lh477sym9jJZ/l9lP+Cb6+NGRwYaVX4LJ37AovWg4N4iPw7/fpX786O6
# Ij4YrBHk8JkDbTuFfAnT7l3ImgtU46gJcWvgzyIQD3XPcXJOCq3fQDpct1HhoXkU
# xk0kIzBdvOw8YGqsLwfM/fDqR9mIUF79Zm5WYScpiYRR5oLnRlD9lCosp+R1PrqY
# D4R/nzEU1q3V8mTLex4F0IQZchfxFwbvPc3WTe8GQv2iUypPhR3EHTyvz9qsEPXd
# rKzpVv+TAgMBAAGjggHOMIIByjAdBgNVHQ4EFgQU9LbhIB3+Ka7S5GGlsqIlssgX
# NW4wHwYDVR0jBBgwFoAUReuir/SSy4IxLVGLp6chnfNtyA8wEgYDVR0TAQH/BAgw
# BgEB/wIBADAOBgNVHQ8BAf8EBAMCAYYwEwYDVR0lBAwwCgYIKwYBBQUHAwgweQYI
# KwYBBQUHAQEEbTBrMCQGCCsGAQUFBzABhhhodHRwOi8vb2NzcC5kaWdpY2VydC5j
# b20wQwYIKwYBBQUHMAKGN2h0dHA6Ly9jYWNlcnRzLmRpZ2ljZXJ0LmNvbS9EaWdp
# Q2VydEFzc3VyZWRJRFJvb3RDQS5jcnQwgYEGA1UdHwR6MHgwOqA4oDaGNGh0dHA6
# Ly9jcmw0LmRpZ2ljZXJ0LmNvbS9EaWdpQ2VydEFzc3VyZWRJRFJvb3RDQS5jcmww
# OqA4oDaGNGh0dHA6Ly9jcmwzLmRpZ2ljZXJ0LmNvbS9EaWdpQ2VydEFzc3VyZWRJ
# RFJvb3RDQS5jcmwwUAYDVR0gBEkwRzA4BgpghkgBhv1sAAIEMCowKAYIKwYBBQUH
# AgEWHGh0dHBzOi8vd3d3LmRpZ2ljZXJ0LmNvbS9DUFMwCwYJYIZIAYb9bAcBMA0G
# CSqGSIb3DQEBCwUAA4IBAQBxlRLpUYdWac3v3dp8qmN6s3jPBjdAhO9LhL/KzwMC
# /cWnww4gQiyvd/MrHwwhWiq3BTQdaq6Z+CeiZr8JqmDfdqQ6kw/4stHYfBli6F6C
# JR7Euhx7LCHi1lssFDVDBGiy23UC4HLHmNY8ZOUfSBAYX4k4YU1iRiSHY4yRUiyv
# KYnleB/WCxSlgNcSR3CzddWThZN+tpJn+1Nhiaj1a5bA9FhpDXzIAbG5KHW3mWOF
# IoxhynmUfln8jA/jb7UBJrZspe6HUSHkWGCbugwtK22ixH67xCUrRwIIfEmuE7bh
# fEJCKMYYVs9BNLZmXbZ0e/VWMyIvIjayS6JKldj1po5SMYIChjCCAoICAQEwgYYw
# cjELMAkGA1UEBhMCVVMxFTATBgNVBAoTDERpZ2lDZXJ0IEluYzEZMBcGA1UECxMQ
# d3d3LmRpZ2ljZXJ0LmNvbTExMC8GA1UEAxMoRGlnaUNlcnQgU0hBMiBBc3N1cmVk
# IElEIFRpbWVzdGFtcGluZyBDQQIQDUJK4L46iP9gQCHOFADw3TANBglghkgBZQME
# AgEFAKCB0TAaBgkqhkiG9w0BCQMxDQYLKoZIhvcNAQkQAQQwHAYJKoZIhvcNAQkF
# MQ8XDTIyMDEzMTE4NDgyNFowKwYLKoZIhvcNAQkQAgwxHDAaMBgwFgQU4deCqOGR
# vu9ryhaRtaq0lKYkm/MwLwYJKoZIhvcNAQkEMSIEIJzTONs31SFnuBvJ1OBf4nmF
# dDrTi1f6URgkUlc/cK74MDcGCyqGSIb3DQEJEAIvMSgwJjAkMCIEILMQkAa8CtmD
# B5FXKeBEA0Fcg+MpK2FPJpZMjTVx7PWpMA0GCSqGSIb3DQEBAQUABIIBAG3AHwqs
# NRRjUVOHevPqfv3C+VDJy159tbv63Nx4xeWnoRB4fGtNh+zHN+Fl2rKcD0PWQ4oG
# md+Zz5/qy7W92BCArMrbDh7Fy5/GLMX9ABQI7ZObUbZARqDunlkSL/bvyY6cagvy
# DIZiPFUmwD8A9EzIvSm7zUHaUTRZZqHO78/G+CDVPlIivpabyBDhJ51Na0GASTs6
# CZrxIqPLiwNMZLZq8ZeEZth1ipvZ2i0BNKOTVZquofdP55zv1zUnAw35gy8IVnG5
# gxHHkYfJ4Jc8HUga/43eDqmxY+w6Ar5aXM2Xu957dT4WqDmouKkY6YdLRQcilR5h
# r8ivFgMJnaKenik=
# SIG # End signature block
