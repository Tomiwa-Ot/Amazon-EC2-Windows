#----------------------------------------------------------------------------------------------------
#
#    Copyright 2017 Amazon.com, Inc. or its affiliates. All Rights Reserved.
#
#    Licensed under the Customer Agreement (the "License").
#
#    You may not use this file except in compliance with the License.
#
#    A copy of the License is located at
#
#          http://aws.amazon.com/agreement
#
#    or in the "license" file accompanying this file.
#
#    This file is distributed on an "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND,
#    either express or implied. See the License for the specific language governing permissions
#    and limitations under the License.
#
#----------------------------------------------------------------------------------------------------

function Get-HttpBinaryFile ($url,$proxy,$file)
{
  try
  {
    $webProxy = New-Object System.Net.WebProxy ($proxy,$false)
    $request = [System.Net.WebRequest]::Create($url)
    $request.Timeout = "120000"
    $request.Proxy = $webProxy
    $response = $request.GetResponse()
    $statusCode = ($response.StatusCode) -as [int]

    if ($statusCode -ne "200")
    {
      return $false;
    }

    $stream = $response.GetResponseStream()
    $ms = New-Object System.IO.MemoryStream

    $stream.CopyTo($ms)

    $data = $ms.ToArray()

    [System.IO.File]::WriteAllBytes($file,$data)

    return $true
  }
  catch
  {
    return $false;
  }
}

function Send-HttpPostJson ($url,$proxy,$json)
{
  try
  {
    $webProxy = New-Object System.Net.WebProxy ($proxy,$false)
    $request = [System.Net.WebRequest]::Create($url)
    $request.Method = "POST"
    $request.ContentType = 'application/json; charset=utf-8'
    $request.Proxy = $webProxy

    $stream = $request.GetRequestStream()
    $streamWriter = New-Object System.IO.StreamWriter ($stream)
    $streamWriter.Write($json)
    $streamWriter.Dispose();
    $stream.Dispose();

    $request.Timeout = "20000"
    $response = $request.GetResponse()
    $statusCode = ($response.StatusCode) -as [int]

    if ($statusCode -ne "200")
    {
      return $null;
    }

    $reqstream = $response.GetResponseStream()
    $sr = New-Object System.IO.StreamReader $reqstream
    $result = $sr.ReadToEnd()
    return $result
  }
  catch
  {
    return $null;
  }
}

function Pop-DnLexerChar ([System.Text.StringBuilder]$dn)
{
  if ($dn.Length -gt 0)
  {
    $res = Read-DnLexerChar $dn
    [void]$dn.Remove([int]0,[int]1)
    return $res
  }
  throw "Invalid DN - unexpected end"
}

function Read-DnLexerChar ([System.Text.StringBuilder]$dn)
{
  if ($dn.Length -gt 0)
  {
    [char[]]$arr = 'c'
    [void]$dn.CopyTo(0,$arr,0,1)

    return $arr[0]
  }
  return '`0'
}

function Skip-DnLexerWhitespace ([System.Text.StringBuilder]$dn)
{
  while ($true)
  {
    $c = Read-DnLexerChar $dn
    if ($c -eq '`0' -or ![System.Char]::IsWhiteSpace($c))
    {
      break
    }
    [void](Pop-DnLexerChar $dn)
  }
}

function Skip-DnLexerToCommaOrSemicolon ([System.Text.StringBuilder]$dn)
{
  while ($true)
  {
    $c = Read-DnLexerChar $dn
    if ($c -eq ',' -or $c -eq ';')
    {
      [void](Pop-DnLexerChar $dn)
      break
    }
    if ($c -eq '`0')
    {
      break
    }
    if (![System.Char]::IsWhiteSpace($c))
    {
      throw "Unexpected character when comma was expected"
    }
    [void](Pop-DnLexerChar $dn)
  }
}

function Read-DnAttributeKey ([System.Text.StringBuilder]$dn)
{
  Skip-DnLexerWhitespace $dn
  if ((Read-DnLexerChar $dn) -eq '`0')
  {
    return $null
  }

  $attrkey = ""
  for ($c = (Pop-DnLexerChar $dn); $c -ne '=' -and $c -ne '+'; $c = (Pop-DnLexerChar $dn))
  {
    $attrkey = $attrkey + $c
  }

  $attrkey = $attrkey.Trim().ToUpper()

  if ($attrkey.Length -eq 0)
  {
    throw "Invalid DN - empty attribute key"
  }

  return $attrkey
}

function Read-DnAttributeValue ([System.Text.StringBuilder]$dn)
{
  [void](Skip-DnLexerWhitespace $dn)

  if ((Read-DnLexerChar $dn) -eq '"')
  {
    [void](Pop-DnLexerChar $dn)
    $val = Read-DnAttributeValueWithTerminator $dn '"' '"'
    [void](Skip-DnLexerToCommaOrSemicolon $dn)
    return $val
  }

  return Read-DnAttributeValueWithTerminator $dn ',' ';'
}

function Test-DnLexerIsHexDigit ($escaped)
{
  if ([System.Char]::IsDigit($escaped))
  {
    return $true
  }
  if ($escaped -ge 'a' -and $escaped -le 'f')
  {
    return $true
  }
  if ($escaped -ge 'A' -and $escaped -le 'F')
  {
    return $true
  }
  return $false
}

function Add-DnLexerPendingWhitespaceToBytestream ([System.Collections.Generic.List[System.Byte]]$byteStream,[System.String]$pendingWhitespace)
{
  if ($pendingWhitespace.Length -gt 0)
  {
    $byteStream.AddRange([System.Text.Encoding]::UTF8.GetBytes($pendingWhitespace))
  }

  return ''
}

function Add-DnLexerBytestream ([System.Collections.Generic.List[System.Byte]]$byteStream,[System.Char]$c)
{
  if ($c -le 0x7f)
  {
    $byteStream.Add($c)
  }
  else
  {
    $byteStream.AddRange([System.Text.Encoding]::UTF8.GetBytes($c))
  }
}

function Read-DnAttributeValueWithTerminator ([System.Text.StringBuilder]$dn,$terminator1,$terminator2)
{
  [System.Collections.Generic.List[System.Byte]]$byteStream = (New-Object System.Collections.Generic.List[System.Byte])
  [string]$accumulatedWhitespace = ''

  while ((Read-DnLexerChar $dn) -ne '`0')
  {
    $c = Pop-DnLexerChar $dn

    if ($c -eq $terminator1 -or $c -eq $terminator2)
    {
      break
    }

    if ($c -eq '\')
    {
      $escaped = Pop-DnLexerChar $dn

      $accumulatedWhitespace = Add-DnLexerPendingWhitespaceToBytestream $byteStream $accumulatedWhitespace

      if ((Test-DnLexerIsHexDigit $escaped))
      {
        $next = Pop-DnLexerChar $dn
        $hex = "" + $escaped + $next
        $byteStream.Add([System.Byte]::Parse($hex,[System.Globalization.NumberStyles]::HexNumber))
      }
      else
      {
        Add-DnLexerBytestream $byteStream $escaped
      }
    }
    elseif ([System.Char]::IsWhiteSpace($c))
    {
      $accumulatedWhitespace += $c
    }
    else
    {
      $accumulatedWhitespace = Add-DnLexerPendingWhitespaceToBytestream $byteStream $accumulatedWhitespace
      Add-DnLexerBytestream $byteStream $c
    }
  }

  $str = [System.Text.Encoding]::UTF8.GetString($byteStream.ToArray())
  return $str
}

function Read-DistinguishedName ($rdn)
{
  [System.Text.StringBuilder]$dn = New-Object System.Text.StringBuilder
  [void]$dn.Append($rdn)

  $result = @{}

  while ($dn.Length -gt 0)
  {
    $key = Read-DnAttributeKey $dn
    $value = Read-DnAttributeValue $dn

    if ($key -eq $null) {
      continue
    }

    [void]$result.Add($key,$value)
    [void](Skip-DnLexerWhitespace $dn)
  }
  return $result
}

function Test-DnConstraints ($rdn,$constraints)
{
  [System.Collections.Hashtable]$constr = Read-DistinguishedName $constraints
  [System.Collections.Hashtable]$subj = Read-DistinguishedName $rdn

  foreach ($kvp in $constr.GetEnumerator())
  {
    if ($subj.ContainsKey($kvp.Key))
    {
      if ($subj[$kvp.Key] -ne $kvp.Value)
      {
        [System.Console]::WriteLine("Signature check failed : '$($subj[$kvp.Key])' != '$($kvp.Value)'")
        return $false
      }
    }
    else
    {
      [System.Console]::WriteLine("Signature check failed : $($kvp.Key) field missing")
      return $false
    }
  }

  return $true
}

function Test-CertificateIsAws ($file)
{
  $auth = Get-AuthenticodeSignature $file
  $subj = $auth.SignerCertificate.Subject

  $dnAws = "CN=`"Amazon Web Services, Inc.`", O=`"Amazon Web Services, Inc.`", L=Seattle, S=Washington, C=US"
  $dnAmzn = "CN=Amazon Services LLC, OU=Software Services, O=Amazon Services LLC, L=Seattle, S=Washington, C=US"

  return ($auth.Status -eq "Valid") -and ((Test-DnConstraints $subj $dnAws) -or (Test-DnConstraints $subj $dnAmzn))
}

function Get-EgpuSoftwareVersion ($key)
{
  try
  {
    $item = Get-ItemProperty -Path ("HKLM:\SOFTWARE\Amazon\EC2ElasticGPUs\$key") -ErrorAction "Ignore"

    if ($item -eq $null)
    {
      return $null
    }

    return $item.Version
  }
  catch
  {
    return $null
  }
}

function Install-EgpuManager ()
{
  try
  {

    $installedVer = Get-EgpuSoftwareVersion "EC2ElasticGPUs_Manager"

    if (($installedVer -ne "") -and ($installedVer -ne $null))
    {
      Write-Log "ElasticGPU already installed - version $installedVer"
      throw
    }

    $metadataAvailable = Get-Metadata -UrlFragment "meta-data"

    if ($metadataAvailable -eq $null)
    {
      Write-ErrorLog "Metadata cannot be accessed on this instance"
      throw
    }

    $request = Get-Metadata -UrlFragment "meta-data/elastic-gpus/associations/"

    if ($request -eq $null)
    {
      Write-Log "EG is not available on this instance"
      return $null
    }

    $egpu = $request.Split("\r\n")[0]

    $egpuInfo = Get-Metadata -UrlFragment "meta-data/elastic-gpus/associations/$egpu"
    $json = ConvertFrom-Json $egpuInfo
    $proxy = "http://$($json.connectionConfig.ipv4Address):$($json.connectionConfig.port)"

    $versionsJson = Send-HttpPostJson "http://gam:8080/gam/rest/versions" $proxy "{}"
    $downloadUrl = (ConvertFrom-Json $versionsJson).components[0].Path

    $guid = [System.Guid]::NewGuid().ToString("N")
    $file = "$env:temp\egaim_$guid.msi"
    $logfile = "$env:temp\egaim_$guid.log"

    $downloadSuccess = Get-HttpBinaryFile http://gam:8080/$downloadUrl $proxy $file

    if ($downloadSuccess -eq $false)
    {
      Write-ErrorLog "Download failed"
      throw
    }

    $signatureValid = Test-CertificateIsAws $file

    if ($signatureValid)
    {
      Start-Process -FilePath "msiexec.exe" -ArgumentList "/i `"$file`" /qn /log `"$logfile`"" -Wait -PassThru | Out-Null
    }
    else
    {
      Write-ErrorLog "Signature is not valid"
    }

    $installedVer = Get-EgpuSoftwareVersion "EC2ElasticGPUs_Manager"

    if (($installedVer -eq "") -or ($installedVer -eq $null))
    {
      Write-ErrorLog "ElasticGPUs installation failed ?"
    }

    Write-Log "Installed ElasticGPUs manager $installedVer"

    Remove-Item $file
  }
  catch
  {
    Write-ErrorLog "Error installing eGPU"
  }
}

# SIG # Begin signature block
# MIIfJgYJKoZIhvcNAQcCoIIfFzCCHxMCAQExDzANBglghkgBZQMEAgEFADB5Bgor
# BgEEAYI3AgEEoGswaTA0BgorBgEEAYI3AgEeMCYCAwEAAAQQH8w7YFlLCE63JNLG
# KX7zUQIBAAIBAAIBAAIBAAIBADAxMA0GCWCGSAFlAwQCAQUABCAmdxXDkmpM/+sq
# XKXQnSkoQciGCmG6fiyS99DVuxPsRqCCDlUwggawMIIEmKADAgECAhAIrUCyYNKc
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
# CQQxIgQgVdblij4c7PsN9dRxwgJePAVzXjs0pN1ORB7W7FJSWoMwDQYJKoZIhvcN
# AQEBBQAEggGAGpmJxcMGBEf6nxG34N5uPuL7yYPxrPMfILMLEmoogRuajhyIzDv3
# m2X0zbFPj9YrrHmnhwEI7v1aOu+/T7/9s9n567qrPGbOY3yteubPESy3PaA/cFur
# MKci3gbi0CeZX15zgYcbi9A/B6JfZmQnZjV4b5U/48PCiu2IXwG3Q59pDAARCOPE
# tvplQRcWPtO3SKutI3lKBWzGzgVxiBQ5DKyVbDhQeNpz5OcsfeFs8YL4Ef789pUa
# vdSALuN9x2EUionoit0rtXsQa45Tc/UqgbQc1AbyubwfMUlx/Az7xCd84JjYN9vf
# 8yGnPSvykBQx041C1x+CU79mwc6nI9CG25YLfeusQkKsXundpqZk3+rdi/2TT/nL
# 5tYt60GqwafcJiZUZHi8JoIBM7k4SPCbSuUAUcBM8k5v3Uq9qkej3L9wv32w9VZy
# C98N++mFXkfqR2RdtRJNlXfsfnQFYaXa5V3z4M6z2wWVbJcSO/mglxae00MV8Z56
# Izt89RZ3SWmXoYINfTCCDXkGCisGAQQBgjcDAwExgg1pMIINZQYJKoZIhvcNAQcC
# oIINVjCCDVICAQMxDzANBglghkgBZQMEAgEFADB3BgsqhkiG9w0BCRABBKBoBGYw
# ZAIBAQYJYIZIAYb9bAcBMDEwDQYJYIZIAWUDBAIBBQAEIFnS/w15AxNQWGtvZdKZ
# N/RV3Pq1z2nip+MlHlpmQ/xWAhAT1lSEhlavf5CAdp13qPzEGA8yMDIyMDEzMTE4
# NDc1OVqgggo3MIIE/jCCA+agAwIBAgIQDUJK4L46iP9gQCHOFADw3TANBgkqhkiG
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
# DxcNMjIwMTMxMTg0NzU5WjArBgsqhkiG9w0BCRACDDEcMBowGDAWBBTh14Ko4ZG+
# 72vKFpG1qrSUpiSb8zAvBgkqhkiG9w0BCQQxIgQgNGZlp5okgGpW8bCVs1lVHcN2
# UP04jy2/Dt9hNwU5Qy8wNwYLKoZIhvcNAQkQAi8xKDAmMCQwIgQgsxCQBrwK2YMH
# kVcp4EQDQVyD4ykrYU8mlkyNNXHs9akwDQYJKoZIhvcNAQEBBQAEggEAj/RqNuoO
# 6PdKDJ+umsxzWedj57mFi6/2Y7MQMTkFTciEhi0MYaNCSGqIqYackzZfiHyJG6VS
# 20dj8368O0uZc0TR+zsUJRtXHob3af8qF3Mx4uVafBf5EF7iRQAlhP2Cr7vTUrQ6
# VRUpSj9F1HKm/iR3v+qXtaFox3nH8wXaxvFRtGs/fRFB7U1MtAsPXQ4ElT91xaHp
# d9T+44pJeRYqjMzDc9qdq3dT6F/6wTQSHO/ZzVR/MOJCCG9JhQSJAuYpYeA9Txd/
# RkInCIpASFQDfso3DRt9NFagjPouibj/HfKTUZNTfQqUR+4F51qhWv6iL5FwZA0i
# cz0vHdnGoyfxaA==
# SIG # End signature block
