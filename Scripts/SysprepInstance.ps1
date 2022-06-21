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

	Start sysprep with answer file provided in the current directory.

.DESCRIPTION

    Ensure Unattend.xml is located under Sysprep directory.

.PARAMETER NoShutdown

    NoShutdown prevents sysprep to shutdown the instance.

.EXAMPLE

    ./SysprepInstance

#>
param(
  [Parameter(Mandatory = $false)]
  [switch]$NoShutdown
)

Set-Variable rootPath -Option Constant -Scope Local -Value (Join-Path $env:ProgramData -ChildPath "Amazon\EC2-Windows\Launch")
Set-Variable modulePath -Option Constant -Scope Local -Value (Join-Path $rootPath -ChildPath "Module\Ec2Launch.psd1")
Set-Variable scriptPath -Option Constant -Scope Local -Value (Join-Path $PSScriptRoot -ChildPath $MyInvocation.MyCommand.Name)
Set-Variable sysprepResDir -Option Constant -Scope Local -Value (Join-Path $rootPath -ChildPath "Sysprep")
Set-Variable beforeSysprepFile -Option Constant -Scope Local -Value (Join-Path $sysprepResDir -ChildPath "BeforeSysprep.cmd")
Set-Variable answerFilePath -Option Constant -Scope Local -Value (Join-Path $sysprepResDir -ChildPath "Unattend.xml")
Set-Variable sysprepPath -Option Constant -Scope Local -Value (Join-Path $env:windir -ChildPath "System32\Sysprep\Sysprep.exe")
Set-Variable powershellPath -Option Constant -Scope Local -Value (Join-Path $env:windir -ChildPath "System32\WindowsPowerShell\v1.0\powershell.exe")
Set-Variable assistPath -Option Constant -Scope Local -Value (Join-Path $sysprepResDir -ChildPath "Randomize-LocalAdminPassword.ps1")

# Import Ec2Launch module to prepare to use helper functions.
Import-Module $modulePath

# Check if answer file is located in correct path.
if (-not (Test-Path $answerFilePath))
{
  throw New-Object System.IO.FileNotFoundException ("{0} not found" -f $answerFilePath)
}

if (-not (Test-Path $sysprepPath))
{
  throw New-Object System.IO.FileNotFoundException ("{0} not found" -f $sysprepPath)
}

# Update the unattend.xml.
try
{
  # Get the locale and admin name to update unattend.xml
  $localAdmin = Get-CimInstance -ClassName Win32_UserAccount -Filter "LocalAccount='True'" | Where-Object { $_.SID -like 'S-1-5-21-*' -and $_.SID -like '*-500' }
  $localAdminName = $localAdmin.Name
  $locale = ([cultureinfo]::CurrentCulture).IetfLanguageTag

  # Get content as xml
  $content = [xml](Get-Content $answerFilePath)

  # Search for empty locales and assign the correct locale for current OS
  $localeTarget = ($content.unattend.settings | Where-Object { $_.pass -ieq 'oobeSystem' }).component | `
     Where-Object { $_.Name -ieq 'Microsoft-Windows-International-Core' }
  if ($localeTarget.InputLocale -eq '') { $localeTarget.InputLocale = $locale }
  if ($localeTarget.SystemLocale -eq '') { $localeTarget.SystemLocale = $locale }
  if ($localeTarget.UILanguage -eq '') { $localeTarget.UILanguage = $locale }
  if ($localeTarget.UserLocale -eq '') { $localeTarget.UserLocale = $locale }

  # Search for the first empty RunSynchronousCommand and assign the correct command for current OS
  $adminTarget = (($content.unattend.settings | Where-Object { $_.pass -ieq 'specialize' }).component | `
       Where-Object { $_.Name -ieq 'Microsoft-Windows-Deployment' }).RunSynchronous | `
     ForEach-Object { $_.RunSynchronousCommand | Where-Object { $_.Order -eq 1 } }
  if ($adminTarget.Path -eq '') { $adminTarget.Path = "$powershellPath {0} {1}" -f $assistPath,$localAdmin.Name }

  # Save the final xml content
  $content.Save($answerFilePath)
}
catch
{
  Write-Warning "Failed to update the custom answer file. Ignore this message if you modified the file."
}

# Clear instance information from wallpaper.
try
{
  Clear-Wallpaper
}
catch
{
  Write-Warning ("Failed to update the wallpaper: {0}" -f $_.Exception.Message)
}

#Disable hibernation
try
{
  Disable-HibernateOnSleep
}
catch
{
  Write-Warning ("Failed to disable hibernation prior to sysprep: {0}" -f $_.Exception.Message)
}

# Unregister userdata scheduled task.
try
{
  Invoke-Userdata -OnlyUnregister
}
catch
{
  Write-Warning ("Failed to unreigster the userdata scheduled task: {0}" -f $_.Exception.Message)
}

# Perform commands in BeforeSysprep.cmd.
if (Test-Path $beforeSysprepFile)
{
  & $beforeSysprepFile
}

# Finally, perform sysprep.
if ($NoShutdown)
{
  Start-Process -FilePath $sysprepPath -ArgumentList ("/oobe /quit /generalize `"/unattend:{0}`"" -f $answerFilePath) -Wait -NoNewWindow
}
else
{
  Start-Process -FilePath $sysprepPath -ArgumentList ("/oobe /shutdown /generalize `"/unattend:{0}`"" -f $answerFilePath) -Wait -NoNewWindow
}


# SIG # Begin signature block
# MIIfJgYJKoZIhvcNAQcCoIIfFzCCHxMCAQExDzANBglghkgBZQMEAgEFADB5Bgor
# BgEEAYI3AgEEoGswaTA0BgorBgEEAYI3AgEeMCYCAwEAAAQQH8w7YFlLCE63JNLG
# KX7zUQIBAAIBAAIBAAIBAAIBADAxMA0GCWCGSAFlAwQCAQUABCAPNbmhc6r10xx1
# TM/oH8lSo5w7df9ci77djGQdW8Hdj6CCDlUwggawMIIEmKADAgECAhAIrUCyYNKc
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
# CQQxIgQgTZNgcZ0T9PBDsZUeKnCrUWOOovVjeujGoU8H5IlxN4gwDQYJKoZIhvcN
# AQEBBQAEggGAVT5uM200cflVjyMJHYhGUprpBrUVUSMgjluLb0+WYyDzCL2Z0Jzy
# oVRxF4gmxAKd3S6/cJ5tbIjT+Eup0jfzqwtY+Rpyh4FGL6KF7yBfPCCcuKwwjdIr
# 48BuVYG9Tmx3oqUmNJGop75CiDzYlgAub6bKXO0Vcq5rPhwzF8e8QbbeXmfbCmJZ
# Cy4dmk/muXZeGG5AJnV974em1Xn5D8oLYvf9u/D6KstzurYmydLcms7CBn8YZ8Qk
# 18NBXCmrAN7axHndFlnGGxf5IPFVqkOSP7I/AhJNYr2KJyALbr41Cxm7idxycB9F
# oX82gEvjRr7A2lD12IT8YMQP/hY8Hw4gmM6KcpeoYyWp7i9mrtakaCTHW1s8C2ad
# DZW03xRmQQqSe+2tyXlcTrfgPysObHmrpbifbX2hDJjWlWkM3m8/nNe0mzq8g8gk
# THbP0shG8M8XfhRxowUHajiCDJdL5EaAbgNcgTup1uCBpmt5685HQc9m3U7XtnzG
# BaJjV4MfgnuOoYINfTCCDXkGCisGAQQBgjcDAwExgg1pMIINZQYJKoZIhvcNAQcC
# oIINVjCCDVICAQMxDzANBglghkgBZQMEAgEFADB3BgsqhkiG9w0BCRABBKBoBGYw
# ZAIBAQYJYIZIAYb9bAcBMDEwDQYJYIZIAWUDBAIBBQAEICn4FWKiBcIPfityiTek
# 9p2Mhd09FtN9RY8tpgN8CnoIAhB2QEeoM7YbJgVAGx47aOgYGA8yMDIyMDEzMTE4
# NTQwN1qgggo3MIIE/jCCA+agAwIBAgIQDUJK4L46iP9gQCHOFADw3TANBgkqhkiG
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
# DxcNMjIwMTMxMTg1NDA3WjArBgsqhkiG9w0BCRACDDEcMBowGDAWBBTh14Ko4ZG+
# 72vKFpG1qrSUpiSb8zAvBgkqhkiG9w0BCQQxIgQgc2K29dMnBP25+PDwBqSVwUZp
# FZ04D7m1bg3j3DkvEiEwNwYLKoZIhvcNAQkQAi8xKDAmMCQwIgQgsxCQBrwK2YMH
# kVcp4EQDQVyD4ykrYU8mlkyNNXHs9akwDQYJKoZIhvcNAQEBBQAEggEATU7d2kE9
# 19JmGpP+y98+TcNgX9pqK1xaUSKubZmDmtD4rDyZnaET1JQrz+r4Cu3/g4Uw5pod
# iO71NkxJdUu3VgDnrSKaUN8nhrD3EhUJeLp/Iyx7Bd5WX2ar0x/lrFuLtYP5v/tH
# 2ogNK9gFKW/hNOdVqnXTXe+hty2g5kdVdYWm/izpW7UwLN1xLYxBI6jPkRKvmPFi
# 7BKi2TdsNrkn4bvB841jt/BdImv3L91p85dwFOH0LxYpwDZN8aYb4EV/cd53Xm9O
# nLkV9J/n4KCkz0YUsNBOvZ4Ie7Ye92CoakXxLhImNGC4zWi5A08wkHQen+xcDcMA
# CKbJ6pqzaHrSEQ==
# SIG # End signature block
