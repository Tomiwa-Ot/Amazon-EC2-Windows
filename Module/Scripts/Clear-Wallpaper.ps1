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
    Clear-Wallpaper clears the customized wallpaper
-------------------------------------------------------------------------------------------------------------#>
function Clear-Wallpaper
{
  try
  {
    # Import wallpaper pinvoke functions
    Import-WallpaperUtil

    $currentWallpaperPath = [WallpaperUtil.Helper]::GetWallpaper()
    $originalWallpaperPath = Join-Path $env:LOCALAPPDATA -ChildPath $script:originalWallpaperName
    $customWallpaperPath = Join-Path $env:LOCALAPPDATA -ChildPath $script:customWallpaperName

    # If wallpaper is set with custom wallpaper, set it with original wallpaper
    if ($currentWallpaperPath -ieq $customWallpaperPath)
    {
      [WallpaperUtil.Helper]::SetWallpaper($originalWallpaperPath)
    }

    # Custom wallpaper is removed if it exists.
    if (Test-Path $customWallpaperPath)
    {
      Remove-Item -Path $customWallpaperPath -Force -Confirm:$false
    }

    # Remove wallpapers copied to default profile
    $defaultLocalPath = "C:\Users\Default\AppData\Local"
    $defaultLocalCustomWallpaperPath = Join-Path $defaultLocalPath -ChildPath $script:customWallpaperName
    if (Test-Path $defaultLocalCustomWallpaperPath)
    {
      Remove-Item $defaultLocalCustomWallpaperPath -Force -Confirm:$false
    }

    # Remove legacy wallpaper setup files created with version below v1.1.2
    $legacyStartupPath = Join-Path $env:ProgramData -ChildPath "Microsoft\Windows\Start Menu\Programs\StartUp"
    $legacyInitWallpaperSetupPath = Join-Path $legacyStartupPath -ChildPath $script:initWallpaperSetupName
    $legacyWallpaperSetupPath = Join-Path $legacyStartupPath -ChildPath $script:wallpaperSetupName
    if (Test-Path $legacyInitWallpaperSetupPath)
    {
      Remove-Item $legacyInitWallpaperSetupPath -Force -Confirm:$false
    }
    if (Test-Path $legacyWallpaperSetupPath)
    {
      Remove-Item $legacyWallpaperSetupPath -Force -Confirm:$false
    }

    # Remove the wallpaper setup files from all user's startup directory
    foreach ($userDir in (Get-ChildItem "C:\Users" -Force -Directory).FullName)
    {
      $startupPath = Join-Path $userDir -ChildPath "AppData\Roaming\Microsoft\Windows\Start Menu\Programs\Startup"
      if (Test-Path $startupPath)
      {
        $initWallpaperSetupPath = Join-Path $startupPath -ChildPath $script:initWallpaperSetupName
        $wallpaperSetupPath = Join-Path $startupPath -ChildPath $script:wallpaperSetupName
        if (Test-Path $initWallpaperSetupPath)
        {
          Remove-Item $initWallpaperSetupPath -Force -Confirm:$false
        }
        if (Test-Path $wallpaperSetupPath)
        {
          Remove-Item $wallpaperSetupPath -Force -Confirm:$false
        }
      }
    }
  }
  catch
  {
    Write-ErrorLog ("Failed to clear the wallpaper: {0}" -f $_.Exception.Message)
  }
}

# SIG # Begin signature block
# MIIfJwYJKoZIhvcNAQcCoIIfGDCCHxQCAQExDzANBglghkgBZQMEAgEFADB5Bgor
# BgEEAYI3AgEEoGswaTA0BgorBgEEAYI3AgEeMCYCAwEAAAQQH8w7YFlLCE63JNLG
# KX7zUQIBAAIBAAIBAAIBAAIBADAxMA0GCWCGSAFlAwQCAQUABCArPSQRSLofVixR
# PG2DGhLf6vJ+NH7166ToTWtOByr+1KCCDlUwggawMIIEmKADAgECAhAIrUCyYNKc
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
# CQQxIgQgRfgEto6Nuzx9rOCAQGWWGt/jQtu1glF8hGsPkXMUfA8wDQYJKoZIhvcN
# AQEBBQAEggGAh4L0yEyDigjLYRREaRHYGc9uj+10WWYfcZhN0pvZDQNOEKLHghXJ
# SnH97GqgP0x/ehrw3ZQfQRX0ANrkUf7EHyq2zXWMU2Lu2eFVAWc3rOXs2K7k0UYf
# pr770DUo5Av9TU2N2kqo5YhozfvMGIFniO8fNZm42unVi1SPLZkUTyZO9+FQwwcx
# RzKfRX2i8kVVO2DElnF8jlhz3Z521t5hLwLLfUXiS8ySBbhn+rH4xvAOsHDYcHpN
# 00bH5vXbAaTfXqpIpHuXRxeMBJZNJXsGeNSUdyzHBCT4NtK0kVg+kBqcKC8vrYJm
# JkPglvTdGxHDm/cZzYy8JlAWfXeo2n4AZfvq0hCT3tA3Yc+0wpo+BQzS8gaSUNsk
# QUEOIt7qN7cPaOjw04DnoQN9qVxMroW5DaCNeDMaXL4zYlsohkgazado/MPei9Bm
# VLzABjX4HIQ22xQL9NTw71oyExaFu/J/z003rfu2SZ5811HIaq2yZRnigMZUf8J6
# R+2/gFh9jcYxoYINfjCCDXoGCisGAQQBgjcDAwExgg1qMIINZgYJKoZIhvcNAQcC
# oIINVzCCDVMCAQMxDzANBglghkgBZQMEAgEFADB4BgsqhkiG9w0BCRABBKBpBGcw
# ZQIBAQYJYIZIAYb9bAcBMDEwDQYJYIZIAWUDBAIBBQAEIBr4TMd+J0iPurT6YMpu
# jcQJcmc6yn+5TmKqkpzbo4+oAhEAulpKWpVagO1MSQcnpM/RshgPMjAyMjAxMzEx
# ODUxMDBaoIIKNzCCBP4wggPmoAMCAQICEA1CSuC+Ooj/YEAhzhQA8N0wDQYJKoZI
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
# MQ8XDTIyMDEzMTE4NTEwMFowKwYLKoZIhvcNAQkQAgwxHDAaMBgwFgQU4deCqOGR
# vu9ryhaRtaq0lKYkm/MwLwYJKoZIhvcNAQkEMSIEIL0zbTSFUdzG7L4Jbs1u22aE
# qhuWvZK/bysQGwgTx5wUMDcGCyqGSIb3DQEJEAIvMSgwJjAkMCIEILMQkAa8CtmD
# B5FXKeBEA0Fcg+MpK2FPJpZMjTVx7PWpMA0GCSqGSIb3DQEBAQUABIIBAKssjkZZ
# G2zd32V+uo+yZ8Vy84fP0+1gmEPhquMtDdcPy1RtiXtRhoPCN7gZW72s528BS83g
# JVe3MabT9Vx1BfpCP46/HKWdSm3c6spvvndLcEJfazmxmrnOx0ANqF1p6aKFwKAH
# OpB/dTm8QBAYx/WCGUDSWpFTbjShgdA+pQUFiQZVM0R7+7AvqvpIq4lT3jjVBZbQ
# ctlEA8I9SQZCTEndbl8zbwAciq/KPQwdP/Vlw4zVL/Wopbc+YgRN0P1kM0xWFAZf
# KS9xiZQV8g6yTa9lrN83uDUiNzYokHIdm4yAzFg7j0Z/9/I0KZnnyKoCKDjva2xo
# hbe6wzi7X7h8tv8=
# SIG # End signature block
