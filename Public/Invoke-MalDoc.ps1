function Invoke-MalDoc {
    <#
    .SYNOPSIS
    A module to programatically execute Microsoft Word and Exel Documents containing macros.

    .DESCRIPTION
    A module to programatically execute Microsoft Word and Exel Documents containing macros. The module will temporarily add a registry key to allow PowerShell to interact with VBA.
    .PARAMETER macroCode
    [Required] The VBA code to be executed. By default, this macro code will be wrapped in a sub routine, called "Test" by default. If you don't want your macro code to be wrapped in a subroutine use the `-noWrap` flag. To specify the subroutine name use the `-sub` parameter.
    .PARAMETER officeVersion
    [Required] The Microsoft Office version to use for executing the document. e.g. "16.0"
    .PARAMETER officeProduct
    [Required] The Microsoft Office application in which to create and execute the macro, either "Word" or "Excel".
    .PARAMETER sub
    [Optional] The name of the subroutine in the macro code to call for execution. Also the name of the subroutine to wrap the supplied `macroCode` in if `noWrap` is not specified.
    .PARAMETER noWrap
    [Optional] A switch that specifies that the supplied `macroCode` should be used as-is and not wrapped in a subroutine.
    
    .EXAMPLE
    C:\PS> Invoke-Maldoc -macroCode "MsgBox `"Hello`"" -officeVersion "16.0" -officeProduct "Word"
    -----------
    Create a macro enabled Microsoft Word Document (using the installed Office version 16.0). The macro code `MsgBox "Hello"` will be wrapped inside of a subroutine call "Test" and then executed.
    
    .EXAMPLE
    C:\PS> $macroCode = Get-Content path/to/macro.txt -Raw
    C:\PS> Invoke-Maldoc -macroCode $macroCode -officeVersion "16.0" -officeProduct "Word"
    -----------
    Create a macro enabled Microsoft Word Document (using the installed Office version 16.0). The macro code read from `path/to/macro.txt` will be wrapped inside of a subroutine call "Test" and then executed.
    
    .EXAMPLE
    C:\PS> Invoke-Maldoc -macroCode "MsgBox `"Hello`"" -officeVersion "15.0" -officeProduct "Excel" -sub "DoIt"
    -----------
    Create a macro enabled Microsoft Excel Document (using the installed Office version 15.0). The macro code `MsgBox "Hello"` will be wrapped inside of a subroutine call "DoIt" and then executed.

    .EXAMPLE
    C:\PS> Invoke-Maldoc -macroCode "Sub Exec()`nMsgBox `"Hello`"`nEnd Sub" -officeVersion "16.0" -officeProduct "Word" -noWrap -sub "Exec"
    -----------
    Create a macro enabled Microsoft Word Document (using the installed Office version 16.0). The macroCode will be unmodified (i.e. not wrapped insided a subroutine) and the "Exec" subroutine will be executed.
#>

    Param(
        [Parameter(Position = 0, Mandatory = $True)]
        [String]$macroCode,

        [Parameter(Position = 1, Mandatory = $True)]
        [String]$officeVersion,

        [Parameter(Position = 2, Mandatory = $True)]
        [ValidateSet("Word", "Excel")]
        [String]$officeProduct,

        [Parameter(Position = 3, Mandatory = $false)]
        [String]$sub = "Test",

        [Parameter(Position = 4, Mandatory = $false)]
        [switch]$noWrap
    )

    Set-ItemProperty -Path "HKCU:\Software\Microsoft\Office\$officeVersion\$officeProduct\Security\" -Name 'AccessVBOM' -Value 1
    if (-not $noWrap) {
        $macroCode = "Sub $sub()`n" + $macroCode + "`nEnd Sub"
    } 
    $app = New-Object -ComObject "$officeProduct.Application"
    if ($officeProduct -eq "Word") {
        $doc = $app.Documents.Add()
    }
    else {
        $doc = $app.Workbooks.Add()
    }
    $comp = $doc.VBProject.VBComponents.Add(1)
    $comp.CodeModule.AddFromString($macroCode)
    $app.Run($sub)
    $doc.Close(0)
    $app.Quit()
    [System.Runtime.InteropServices.Marshal]::ReleaseComObject($comp) | Out-Null
    [System.Runtime.InteropServices.Marshal]::ReleaseComObject($doc) | Out-Null
    [System.Runtime.InteropServices.Marshal]::ReleaseComObject($app) | Out-Null
    [System.GC]::Collect()
    [System.GC]::WaitForPendingFinalizers()
    Remove-ItemProperty -Path "HKCU:\Software\Microsoft\Office\$officeVersion\$officeProduct\Security\" -Name 'AccessVBOM' -ErrorAction Ignore
}