function ConvertFrom-DirquotaList {
    <#
	.SYNOPSIS
	Convert output from Dirquota quota list to an object
	.NOTES
	Original code from Technet gallery by Ben Wilkinson https://gallery.technet.microsoft.com/scriptcenter/Find-and-Report-on-cc49120e
#>

    param(
        [Parameter(ValueFromPipeline = $True)]
        $InputObject
    )
    BEGIN {

        #region Helper functions
        function Convert-Size {
            <#
			.SYNOPSIS
			helper function to convert size to GB
			#>
            param (
                $string, $seperator, $Figure
            )
            if ($seperator -eq ',') {
                $String = $String -replace '\.'
            }

            $Whole, $Decimal = $String.split($seperator)
            [int]$Whole = $Whole -replace ' '
            [int]$Decimal = $Decimal -replace ' '
            if ($Figure -eq "TB") {
                [Math]::Round((($Whole + ($Decimal / 100)) * 1024), 2)
            } elseif ($Figure -eq "GB") {
                [Math]::Round(($Whole + ($Decimal / 100)), 2)
            } elseif ($Figure -eq "MB") {
                [Math]::Round((($Whole + ($Decimal / 100)) / 1024), 2)
            } elseif ($figure -eq "KB") {
                [Math]::Round((($Whole + ($Decimal / 100)) / 1024 / 1024), 2)
            }
        }
        #endregion

        $pattern = '^.{24}'
        $dirQuotaItems = @()
    }
    PROCESS {
        $dirQuotaItems += $InputObject
    }
    END {
        if ($dirQuotaItems.count -lt 4) {
            throw $dirQuotaItems
        }
        $dirQuotaItems = $dirQuotaItems -replace '˙'

        for ($i = 0; $i -lt $dirQuotaItems.count - 1; $i++) {
            if (($dirQuotaItems[$i] -match "Quota Path:") -or ($dirQuotaItems[$i] -match "Kontingentpfad:") -or ($dirQuotaItems[$i] -match "ka przydzia.u:")) {
                [String]$QuotaPath = ($dirQuotaItems[$i] -split $pattern)[1]
                if (($dirQuotaItems[$i + 1] -match "Share Path:") -or ($dirQuotaItems[$i + 1] -match "Freigabepfad:")) {
                    [String]$SharePath = ($dirQuotaItems[$i + 1] -split $pattern)[1]
                } else {
                    $SharePath = $null
                    $i--
                }
                [String]$Template, $TemplateMatch = (($dirQuotaItems[$i + 2] -split $pattern)[1] -split "\(")
                $templateMatch = $templateMatch.Substring(0, $templateMatch.Length - 1)
                [String]$QuotaStatus = ($dirQuotaItems[$i + 3] -split $pattern)[1]
                [String]$LimitString, $LimitFigure, $LimitType = (($dirQuotaItems[$i + 4] -split $pattern)[1] -split " ")
                if (!$seperator) {
                    if ($LimitString -match '\..*\,') {
                        $seperator = ','
                    } elseif ($LimitString -match '\.') {
                        $seperator = '.'
                    } else {
                        $seperator = ','
                    }
                }
                $limit = Convert-Size -Figure $LimitFigure -seperator $seperator -string $LimitString
                [String]$UsedString, $UsedFigure, $PercentageUsed = (($dirQuotaItems[$i + 5] -split $pattern)[1] -split " ")
                $Used = Convert-Size -string $UsedString -figure $UsedFigure -seperator $seperator
                [String]$AvailableString, $AvailableFigure = (($dirQuotaItems[$i + 6] -split $pattern)[1] -split " ")
                $Available = Convert-Size -seperator $seperator -figure $AvailableFigure -string $AvailableString
                [String]$PeakString, $PeakFigure, $PeakDate1, $PeakDate2 = (($dirQuotaItems[$i + 7] -split $pattern)[1] -split " ")
                $peak = Convert-Size -seperator $seperator -figure $PeakFigure -string $PeakString
                $PeakDate1 = $PeakDate1 -replace "\("
                $PeakDate2 = $PeakDate2 -replace "\)"
                $i = $i + 7
                [Int]$UsedPercentage = (($PercentageUsed -split "%")[0]).Substring(1)
                if ($UsedPercentage -gt 100) {
                    $AvailablePC = 0
                } else {
                    $AvailablePC = (100 - $UsedPercentage)
                }
                $Hash = @{
                    QuotaPath     = $QuotaPath
                    SharePath     = $SharePath
                    Status        = $QuotaStatus
                    LimitGB       = $Limit
                    LimitType     = ($LimitType).Substring(1, $LimitType.length - 2)
                    UsedGB        = $Used
                    UsedPC        = $UsedPercentage
                    AvailablePC   = $AvailablePC
                    AvailableGB   = $Available
                    PeakGB        = $Peak
                    PeakDate      = "$PeakDate1 $PeakDate2"
                    Template      = $Template
                    TemplateMatch = $templateMatch
                }
                New-Object PSObject -Property $Hash |
                    Select-Object -Property QuotaPath, SharePath, LimitGB, UsedGB, UsedPC, AvailableGB, AvailablePC, PeakGB, PeakDate, Template, TemplateMatch, LimitType, Status
            }
        }
    }
}
