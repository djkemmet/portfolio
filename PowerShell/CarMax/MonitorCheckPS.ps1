function Decode {
    <#
    .DESCRIPTION
    This function is responsible for decoding the following values into something human readables:
    ProductCodeID
    ManufacturerName
    #>

    If ($args[0] -is [System.Array]) {
        [System.Text.Encoding]::ASCII.GetString($args[0])
    }
    Else {
        "Not Found"
    }
}

Get-WmiObject -Namespace 'root/wmi' -Query "select * from WmiMonitorID" | ForEach-Object -Process {
    $Make = Decode $_.ManufacturerName
    $Model = Decode $_.ProductCodeID
    $ProductionYear = $_.YearOfManufacture
    Write-Host $Make, $Model, $ProductionYear
}