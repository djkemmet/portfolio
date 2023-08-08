@{
    Root = 'c:\Repos\ComputerConfigurator\ComputerConfigurator.ps1'
    OutputPath = 'c:\Repos\ComputerConfigurator\out'
    Package = @{
        Enabled = $true
        Obfuscate = $false
        HideConsoleWindow = $false
        DotNetVersion = 'v4.6.2'
        FileVersion = '1.0.0'
        FileDescription = 'GUI Utility for managing App Assignment groups for computers in AD'
        ProductName = 'Computer Configurator'
        ProductVersion = 'V0.3'
        Copyright = 'CarMax 2022'
        RequireElevation = $false
        ApplicationIconPath = ''
        PackageType = 'Console'
    }
    Bundle = @{
        Enabled = $true
        Modules = $true
        # IgnoredModules = @()
    }
}
        