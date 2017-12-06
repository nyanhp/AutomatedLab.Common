function Get-DscConfigurationImportedResource
{
    param(
        [Parameter(Mandatory, ParameterSetName = 'ByFile')]
        [string]$FilePath,
        
        [Parameter(Mandatory, ParameterSetName = 'ByName')]
        [string]$Name
    )
    
    $modules = New-Object System.Collections.ArrayList

    if ($Name)
    {
        $ast = (Get-Command -Name $Name).ScriptBlock.Ast
        $FilePath = $ast.FindAll( { $args[0] -is [System.Management.Automation.Language.ScriptBlockAst] }, $true)[0].Extent.File
    }
    
    $ast = [scriptblock]::Create((Get-Content -Path $FilePath -Raw)).Ast
    
    $configurations = $ast.FindAll( { $args[0] -is [System.Management.Automation.Language.ConfigurationDefinitionAst] }, $true)
    Write-Verbose "Script knwos about $($configurations.Count) configurations"
    foreach ($configuration in $configurations)
    {
        $importCmds = $configuration.Body.ScriptBlock.FindAll( { $args[0].Value -eq 'Import-DscResource' -and $args[0] -is [System.Management.Automation.Language.StringConstantExpressionAst] }, $true)
        Write-Verbose "Configuration $($configuration.InstanceName) knows about $($importCmds.Count) Import-DscResource commands"
    
        foreach ($importCmd in $importCmds)
        {
            $commandElements = $importCmd.Parent.CommandElements | Select-Object -Skip 1 | Where-Object {$_ -is [System.Management.Automation.Language.ArrayLiteralAst] -or $_ -is [System.Management.Automation.Language.StringConstantExpressionAst] }     
            
            $moduleNames = $commandElements.SafeGetValue()
            if ($moduleNames.GetType().IsArray)
            {
                $modules.AddRange($moduleNames)
            }
            else
            {
                [void]$modules.Add($moduleNames)
            }
        }
    }
    
    $compositeResources = $modules | Where-Object { $_ -ne 'PSDesiredStateConfiguration' } | ForEach-Object { Get-DscResource -Module $_ } | Where-Object { $_.ImplementedAs -eq 'Composite' }
    foreach ($compositeResource in $compositeResources)
    {
        $modulesInResource = Get-DscConfigurationImportedResource -FilePath $compositeResource.Path
        if ($modulesInResource.GetType().IsArray)
        {
            $modules.AddRange($modulesInResource)
        }
        else
        {
            [void]$modules.Add($modulesInResource)
        }
    }
    
    $modules | Select-Object -Unique
}