<#
	.SYNOPSIS
        1. Create the updates markdown from the excel file
        2. List is sort in Descending order on RevisionDateMMYY
        3. First new and then deprecated 


	.DESCRIPTION

    Use Excel to create the updates in the pollict file based on the excel file



	.EXAMPLE
	   .\createUpdateMarkdown.ps1
	   
	.LINK

	.Notes
		NAME:      createUpdateMarkdown.ps1
		AUTHOR(s): Mathieu Rietman <marietma@microsoft.com>
		LASTEDIT:  16-6-2023
		KEYWORDS:  policy management Management
#>

[cmdletbinding()] 
Param (
    #paramter for the input exel file
    [Parameter(Mandatory = $false)]
    [string]$inputExcelFile = "data.xlsx",

    #parameter for tab in excel file
    [Parameter(Mandatory = $false)]
    [string]$inputExcelTab = "v2.2.4",

    #parameter for the output json file
    [Parameter(Mandatory = $false)]
    [string]$outputMardown = "updates.md"
    
       

)

function ConvertTo-MarkdownTable {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [PSObject]$InputObject,

        #parameter for the heading of the table 
        [Parameter(Mandatory = $false)]
        [string]$Heading = $null
        
    )

    # Get the property names and values from the $inputobject keep original order


    $propertyNames = $InputObject | Get-Member -MemberType NoteProperty | Select-Object -ExpandProperty Name   
    $propertyValues = $InputObject | ForEach-Object { $_.PSObject.Properties.Value -join " | " }
    # Create the markdown table header
    $header = "| " + ($Heading ) + " |"
    $separator = "| " + (($propertyNames | ForEach-Object { "---" }) -join " | ") + " |"

    # Create the markdown table rows
    $rows = $propertyValues | ForEach-Object {
        "| " + ($_ -join " | ") + " |"
    }

    # Combine the header, separator, and rows into a single string
    $markdownTable = $header + "`n" + $separator + "`n" + ($rows -join "`n")

    return $markdownTable
}

#check is PSExcel is installed else install
if (!(Get-Module -ListAvailable -Name PSExcel)) {
    Write-Host "PSExcel is not installed, installing PSExcel" -ForegroundColor Yellow
    Install-Module -Name PSExcel -Force
}
Install-Module -Name PSExcel -Force


$root = $PSScriptRoot
$resultFolder = "$root\..\results\"
$policyInfoFile = "$resultFolder\$inputExcelFile"
$resultfile = "$resultFolder\$outputMardown"



# validate if file $policyInfo exist else message and exit
if (!(Test-Path $policyInfoFile)) {
    Write-Host "File $policyInfo does not exist" -ForegroundColor Red
    exit
}

# Read the Excel file and create a object with the data
$inputExcelFile = Import-XLSX -Path $policyInfoFile -sheet $inputExcelTab -RowStart 1


#select from inputAll the unique revisions and 
$inputGroups = $inputExcelFile|  Select-Object -Property RevisionDateMMYY  -Unique | Sort-Object -Property RevisionDateMMYY -Descending



$markdown = @()
$markdown = "# Updates overview per  version"
$markdown += "`n"
$markdown += "`n"
# add tekst to $markdown that explains that this overview contains the updates per version and is generated by a acript
$markdown += "This overview contains the updates per version and is generated by a script."
$markdown += "`nSee for our update process [here](../updates/readme.md)."  
#Loop trough the groups and create the markdown
foreach ($group in $inputGroups) {

    if ($group.RevisionDateMMYY -eq "" -or $group.RevisionDateMMYY -eq $null) {
       
    } else {

        $markdown += "`n"
        $markdown += "`n"
        $markdown += "## Version $($group.RevisionDateMMYY)"
        $markdown += "`n"
        $markdown += "`n"

        $otherupdatesfile = "$resultFolder/otherUpdates.$($group.RevisionDateMMYY).md"
        if ((Test-Path $otherupdatesfile)) {
            
            $markdown += "### Minor updates `n"
            $markdown += "`n"
            $markdown +=  Get-Content -path $otherupdatesfile -Encoding UTF8 -Raw
            $markdown += "`n"
            $markdown += "`n"


        }



        $inputAll = $inputExcelFile | Where-Object { ($_.RevisionDateMMYY -ne "") -and ($_.RevisionDateMMYY -ne $null)  }  | Sort-Object -Property RevisionDateMMYY  -Descending 

    
        $inputline = ($inputAll | Where-Object { $_.RevisionDateMMYY -eq $group.RevisionDateMMYY } | Select-Object -Property PolicyName, policyDisplayName, Category -Unique) -join ","

        #markdown is markdown + new line and tekst the new policies
        $markdown += "### New policies in version $($group.RevisionDateMMYY)"
        $markdown += "`n"
        $markdown += "`n"

      
        #select from inputAll where $group.RevisionDateMMYY is equal to the current group and deprecated is empty
        $inputline = $inputAll | Where-Object { $_.RevisionDateMMYY -eq $group.RevisionDateMMYY -and ($_.deprecated -eq $null -or $_.deprecated -eq "" )} | Select-Object -Property PolicyName, policyDisplayName, Remarks, GroupName -Unique  | Group-Object -Property policyName | Select-Object  Name  , @{Name="policyDisplayname";Expression={  $_.Group[0].policyDisplayName  } } ,  @{Name="Category";Expression={$_.Group.GroupName -join ","}},  @{Name="Remarks";Expression={  $_.Group[0].Remarks  } } 

        $markdown += ConvertTo-MarkdownTable -InputObject $inputline  -Heading "PolicyName|policyDisplayName|Category|Remarks"
        #markdown is markdown + new line 
        $markdown += "`n"
        $markdown += "`n"



        $markdown += "### Deprecated policies in version $($group.RevisionDateMMYY)"
        $markdown += "`n"
        $markdown += "`n"

        $inputline = $inputAll | Where-Object { $_.RevisionDateMMYY -eq $group.RevisionDateMMYY -and ($_.deprecated -eq "TRUE" ) } | Select-Object -Property PolicyName, policyDisplayName, Remarks -Unique
        #select from inputAll where $group.RevisionDateMMYY is equal to the current group and deprecated is not empty
       
        $markdown += ConvertTo-MarkdownTable -InputObject $inputline -Heading "PolicyName|policyDisplayName|Remarks"


    }

}

  
$markdown | Out-File -FilePath $resultfile -Encoding utf8



