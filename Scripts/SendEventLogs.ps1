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

<#
.SYNOPSIS

    Sends windows event logs to console output based on congifuration in EventLogConfig.json.

.DESCRIPTION

    Event logs can be used to troubleshoot your instance and the script replies on EventLogConfig.json.
    If you execute this script, your instance must restart to show event logs in console output.
    The script can be scheduled to be executed on every startup. If the script is scheduled, the event logs
    appear in console output three minutes after your instance restarts.

.PARAMETER Schedule

    Provide this parameter to register script as scheduledtask and trigger it at startup. If you want to run
    script immediately, run it without this parameter.

.EXAMPLE

    ./SendEventLogs.ps1 -Schedule

#>
param(
  # Scheduling the script as task collect and sends event logs to console at startup.
  # If this argument is not provided, script is executed immediately.
  [Parameter(Mandatory = $false)]
  [switch]$Schedule = $false
)

Set-Variable rootPath -Option Constant -Scope Local -Value (Join-Path $env:ProgramData -ChildPath "Amazon\EC2-Windows\Launch")
Set-Variable modulePath -Option Constant -Scope Local -Value (Join-Path $rootPath -ChildPath "Module\Ec2Launch.psd1")
Set-Variable scriptPath -Option Constant -Scope Local -Value (Join-Path $PSScriptRoot -ChildPath $MyInvocation.MyCommand.Name)
Set-Variable scheduleName -Option Constant -Scope Local -Value "Event logs to Console"

# Import Ec2Launch module to prepare to use helper functions.
Import-Module $modulePath

# Before calling any function, initialize the log with filename
Initialize-Log -FileName "EventlogsToConsole.log" -AllowLogToConsole

if ($Schedule)
{
  # Scheduling script with no argument tells script to start normally.
  Register-ScriptScheduler -ScriptPath $scriptPath -ScheduleName $scheduleName
  Write-Log "Sending eventlogs to console is scheduled successfully"
  Complete-Log
  exit 0
}

try
{
  Write-Log "Sending event logs to console started"

  $outputs = @()
  $eventLogConfigs = Get-EventLogConfig
  if (-not $eventLogConfigs)
  {
    throw New-Object System.Exception ("Could not find the event log config or it is empty")
  }

  foreach ($eventLogConfig in $eventLogConfigs)
  {
    $filter = @{}

    if ($eventLogConfig.LogName)
    {
      $filter += @{ LogName = $eventLogConfig.LogName; }
    }

    if ($eventLogConfig.Source)
    {
      $filter += @{ ProviderName = $eventLogConfig.Source; }
    }

    if ($eventLogConfig.Level)
    {
      $filter += @{ Level = $eventLogConfig.Level; }
    }

    # Get event logs based on configuration above.
    try
    {
      $results = Get-WinEvent -FilterHashtable $filter -MaxEvents $eventLogConfig.NumEntries -ErrorAction SilentlyContinue
    }
    catch
    {
      continue
    }

    foreach ($result in $results)
    {
      $timeCreated = "{0:M/dd/yyyy hh:mm:ss tt}" -f $result.TimeCreated
      $outputs += "EventLogEntry: {0}  {1}  {2}  {3}  {4}" -f $result.LogName,$result.LevelDisplayName,
      $result.ProviderName,$timeCreated,$result.Message
    }
  }

  # Serial port COM1 must be opened before sending eventlogs to console.
  Open-SerialPort

  # Finally, send the outputs to console.
  for ($i = $outputs.Length - 1; $i -ge 0; $i --)
  {
    Write-Log $outputs[$i] -LogToConsole
  }

  Write-Log "Sending event logs to console done"
  exit 0
}
catch
{
  Write-ErrorLog ("Failed to continue collect and send eventlogs: {0}" -f $_.Exception.Message)
  exit 1
}
finally
{
  # Serial port COM1 must be closed before ending.
  Close-SerialPort

  # Before finishing the script, complete the log.
  Complete-Log
}


# SIG # Begin signature block
# MIIfJgYJKoZIhvcNAQcCoIIfFzCCHxMCAQExDzANBglghkgBZQMEAgEFADB5Bgor
# BgEEAYI3AgEEoGswaTA0BgorBgEEAYI3AgEeMCYCAwEAAAQQH8w7YFlLCE63JNLG
# KX7zUQIBAAIBAAIBAAIBAAIBADAxMA0GCWCGSAFlAwQCAQUABCDgXBomf73NxzsJ
# +u7LxDfpstYOknbdlB1+f2Fb9OVTVqCCDlUwggawMIIEmKADAgECAhAIrUCyYNKc
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
# CQQxIgQgpyBBo1dOjAfw8aoIkfvRtPBAl5too0eQqM1oUJHbAx8wDQYJKoZIhvcN
# AQEBBQAEggGAIXoQPxuXZAWrH2EJ5GrwP1BDyZUZ4GbGxyoKY3goeoVsbIFEINHT
# 0/PGBMW9RDRJ5KN2Nu+ZRHX8L13aoBTQLrQfv7Mmm2mJopmqwNnFqmWs7FoJy4vS
# lHPUWne0NJRuXTzdNNtLAWnfctsYeoCirulRClIOAd34oNRS2obp24UVydADePja
# VcnXjO5kJgy2Fde2F07SkkI5M/yg5OdeLyp8u+OIAo0hqA9/apoEpHE9nTDl8Hqg
# Zoz76c+wtDQZUaT+R5PbtEWVtGaVxAKg5CQabn/cjxTZ9c2UzTbGrVDmPXIVGduR
# YDKaJ8BfyxPObpmK5bMztSg/lLukbIt4la9fuSJDQ54cwDgcFHj2Pi+XRfvvxcwa
# Zqt7cdQyA6JEtSV140Fs39IEK/9oEk4dI3obPh1mjQ730bMlytCAduI+3qsyYgZW
# EYKL7gpGQeH+f7wLjIxV94mNxU8DNzYT8Nf2LaWvthIqrc+DGdCOI3w9el+OEFoo
# W+mZvRyETpaGoYINfTCCDXkGCisGAQQBgjcDAwExgg1pMIINZQYJKoZIhvcNAQcC
# oIINVjCCDVICAQMxDzANBglghkgBZQMEAgEFADB3BgsqhkiG9w0BCRABBKBoBGYw
# ZAIBAQYJYIZIAYb9bAcBMDEwDQYJYIZIAWUDBAIBBQAEIOHQpMnc7902777Z88qn
# okjFf+jgyyMVrhc8VgI79uHDAhAv+MpZrZiFtz29g3imZz3nGA8yMDIyMDEzMTE4
# NTM1MFqgggo3MIIE/jCCA+agAwIBAgIQDUJK4L46iP9gQCHOFADw3TANBgkqhkiG
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
# DxcNMjIwMTMxMTg1MzUwWjArBgsqhkiG9w0BCRACDDEcMBowGDAWBBTh14Ko4ZG+
# 72vKFpG1qrSUpiSb8zAvBgkqhkiG9w0BCQQxIgQgWDaSSupGRxjRvLRgs9QqD/4W
# eEAnhQXdAy+G2c/RJcUwNwYLKoZIhvcNAQkQAi8xKDAmMCQwIgQgsxCQBrwK2YMH
# kVcp4EQDQVyD4ykrYU8mlkyNNXHs9akwDQYJKoZIhvcNAQEBBQAEggEAhApkeIT8
# 7CoO1ldmypUgenga9xRft3MrR9/vTMGDZWnDQ9718x0TNDRU135iM7oJWKMH7JEd
# BH8PDGPpn1xm6GBGdf4TLTiVbJLdjyfIrNNoQg9au9AgGabx4FTtJ1GoPG+bPwiu
# FdcZAagnbOs13cACf5OGIwFjB8Oe0b+9sDAb+Z/7w/vPniEUeme7YAoWsttP1YNr
# u75/8z9abmr28/KB4BjeWyln/Dow5a5Py/I9yQKtP9lPeNvsMtyhYdhQmUJMX9+d
# pp8zaf/tn9nZPjjHpqfsEH8cKXujdNPxmC2iRZ1pGacfdV1O8DInUrzqyslsiy83
# liB1vaOE/L+u2g==
# SIG # End signature block
