<#

.SYNOPSIS
    This script generates package.xml files for SalesForce projects.

.DESCRIPTION
    If the dir parameter is included then only one sub-directory of /src/ will
    be built and output. If dir is not specified then the entire package file is built from /src/.

.PARAMETER root
The directory of the project src folder

.PARAMETER dir
Optional subdirectory inside the root

.PARAMETER apiVersion
the API version to be specified in the package, defaults to 31.0

.PARAMETER packageName
The file name of the generated XML package, defaults to "package.xml"

.PARAMETER xmlns
The source URL of the Salesforce XML namespace, defaults to "http://soap.sforce.com/2006/04/metadata"

.INPUTS
    Script accepts no input other than arguments

.OUTPUTS
    Script creates a new XML package file in the current directory if -dir is not specified.
    If -dir is specified then the script outputs the package members XML

.EXAMPLE
    ./xml_package_builder.ps1
    ./xml_package_builder.ps1 -apiVersion 27.0 -packageName my_package.xml
    ./xml_package_builder.ps1 -dir classes | clip

.LINK
    https://github.com/AcumenSolutions/AssetLibrary/tree/master/scripts

#>

param(
    [string] $root = (Get-Location),
    [string] $dir = "",
    [string] $apiVersion = "31.0",
    [string] $packageName = "package.xml",
    [string] $xmlnsSource = "http://soap.sforce.com/2006/04/metadata"
)

$fileExcludePatterns = ("*.txt", "*.log", "*.xml")

$folderToName = @{
    "aura" = "AuraDefinitionBundle"
    "classes" = "ApexClass"
    "components" = "ApexComponent"
    "pages" = "ApexPage"
    "triggers" = "ApexTrigger"
    "staticresources" = "StaticResource"
    "objects" = "CustomObject"
    "profiles" = "Profile"
}

$foldersToMembers = @{}

Set-Variable INDENT_CHAR      -option Constant -value "`t"
Set-Variable MEMBER           -option Constant -value "members"
Set-Variable NAME             -option Constant -value "name"
Set-Variable NEWLINE_CHAR     -option Constant -value "`r`n"
Set-Variable SALESFORCE_XMLNS -option Constant -value $xmlnsSource
Set-Variable PACKAGE          -option Constant -value "Package"
Set-Variable TYPES            -option Constant -value "types"
Set-Variable VERSION          -option Constant -value "version"
Set-Variable XMLNS            -option Constant -value "xmlns"

function Main {
    if($dir) {
        Output-Single-Directory
    } else {
        Write-Package-Xml
    }
}

function Output-Single-Directory {
    $output = ""
    $allFiles = Get-ChildItem ($root + "\" + $dir) -recurse -force -exclude $exludePatterns | % {$_.BaseName}
    $allFiles | ForEach-Object {$output += ("{0}{1}{2}`r`n" -f "<members>", $_, "</members>")}
    Write-Output $output
}

function Write-Package-Xml {
    $subFolders = Get-Folders
    $files = Get-Files $subFolders

    $xmlWriterSettings = Get-Xml-Writer-Settings
    $filePath = $root + "/" + $packageName
    $writer = Get-Xml-Writer $filePath $xmlWriterSettings

    Write-Package $packageName $files $subFolders $writer
}

function Get-Folders {
    Get-ChildItem $root -force | Where { $_.PSIsContainer }
}

function Get-Files {
    param([System.Object] $folders)

    $files = New-Object System.Collections.ArrayList

    foreach($folder in $folders) {
        $files.Add((Get-Members $folder)) > $Null
    }
    return $files
}

function Get-Xml-Writer-Settings {
    $xmlWriterSettings = New-Object System.Xml.XmlWriterSettings
    Set-Xml-Writer-Settings $xmlWriterSettings

    return $xmlWriterSettings
}

function Set-Xml-Writer-Settings {
    param([System.Xml.XmlWriterSettings] $settings)

    $settings.Encoding = [System.Text.Encoding]::UTF8
    $settings.Indent = $TRUE
    $settings.IndentChars = $INDENT_CHAR
    $settings.NewLineChars = $NEWLINE_CHAR
}

function Get-Xml-Writer {
    param(
        [String] $filePath,
        [System.Xml.XmlWriterSettings] $settings
    )

    $xmlWriter = [System.Xml.XmlWriter]::Create($filePath, $settings)
    return $xmlWriter
}

function Write-Package {
    param(
        [String] $packageName,
        [System.Collections.ArrayList] $files,
        [System.Object] $subFolders,
        [System.Xml.XmlWriter] $writer
    )

    Start-Xml-Document $writer
    Write-Xml-Document $packageName $files $subFolders $writer
    End-Xml-Document $writer
    Close-Xml-Writer $writer
}

function Start-Xml-Document {
    param([System.Xml.XmlWriter] $w)

    $w.WriteStartDocument() # does not allow explicit specification of encoding attribute AFAIK
    $w.WriteStartElement($PACKAGE, $SALESFORCE_XMLNS)
    $w.WriteAttributeString($XMLNS, $SALESFORCE_XMLNS)
}

function Write-Xml-Document {
    param(
        [String] $packageName,
        [System.Collections.ArrayList] $files,
        [System.Object] $subFolders,
        [System.Xml.XmlWriter] $writer
    )

    $i = 0
    foreach($folder in $subFolders) {
        Write-Types $folder $packageName $files[$i] $writer
        $i++
    }
    Write-Api-Version $apiVersion $writer
}

function End-Xml-Document {
    param([System.Xml.XmlWriter] $w)

    $w.WriteEndElement()
    $w.WriteEndDocument()
}

function Close-Xml-Writer {
    param([System.Xml.XmlWriter] $w)

    $w.Finalize
    $w.Flush()
    $w.Close()
}

function Get-Members {
    param([System.Object] $folder)

    $fileNames = Get-ChildItem $folder -exclude $fileExcludePatterns | % { $_.BaseName }
    $foundMsg = "*** Looking in " + $folder + " found " + $fileNames.Count + " files"
    Write-Verbose -Message $foundMsg
    return $fileNames
}

function Write-Types {
    param(
        [System.Object] $folder,
        [string] $packageName,
        [System.Collections.ArrayList] $members,
        [System.Xml.XmlWriter] $w
    )

    $w.WriteStartElement($TYPES)
    Write-Members $w $members
    $w.WriteElementString($NAME, ($folderToName[$folder.Name]))
    $w.WriteEndElement()
}

function Write-Members {
    param(
        [System.Xml.XmlWriter] $w,
        [System.Collections.ArrayList] $members
    )

    foreach($m in $members) {
        $w.WriteElementString($MEMBER, $m)
    }
}

function Write-Api-Version {
    param(
        [string] $apiVersion,
        [System.Xml.XmlWriter] $w
    )

    $w.WriteElementString($VERSION, $apiVersion)
}

Main