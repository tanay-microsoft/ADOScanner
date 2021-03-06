﻿Set-StrictMode -Version Latest 
class WriteDataFile: FileOutputBase
{   
    hidden static [WriteDataFile] $Instance = $null;
    hidden [int] $JsonDepth = 10;

    static [WriteDataFile] GetInstance()
    {
        if ( $null -eq  [WriteDataFile]::Instance)
        {
            [WriteDataFile]::Instance = [WriteDataFile]::new();
        }
    
        return [WriteDataFile]::Instance
    }

    [void] RegisterEvents()
    {
        $this.UnregisterEvents();       

        $this.RegisterEvent([AzSKRootEvent]::GenerateRunIdentifier, {
            $currentInstance = [WriteDataFile]::GetInstance();
            try 
            {
                $currentInstance.SetRunIdentifier([AzSKRootEventArgument] ($Event.SourceArgs | Select-Object -First 1));            
            }
            catch 
            {
                $currentInstance.PublishException($_);
            }
        });

        $this.RegisterEvent([SVTEvent]::CommandStarted, {
            $currentInstance = [WriteDataFile]::GetInstance();
            try 
            {
                $currentInstance.SetFilePath($Event.SourceArgs.SubscriptionContext, [FileOutputBase]::ETCFolderPath, ("SecurityEvaluationData-" + $currentInstance.RunIdentifier + ".json"));
            }
            catch 
            {
                $currentInstance.PublishException($_);
            }
        });
        
        $this.RegisterEvent([SVTEvent]::CommandCompleted, {
            $currentInstance = [WriteDataFile]::GetInstance();
            $currentInstance.PushAIEventsfromHandler("WriteDataFile CommandCompleted"); 
            try 
            {
                if (!$currentInstance.IsSecurityEvaluationJsonFileRequired()) { return; };
                $currentInstance.WriteToJson($Event.SourceArgs);
                $currentInstance.FilePath = "";
            }
            catch 
            {
                $currentInstance.PublishException($_);
            }
        });

    }

    [void] WriteToJson([SVTEventContext[]] $arguments)
    {
        if ([string]::IsNullOrEmpty($this.FilePath)) {
            return;
        }

		if($arguments)
		{
			if (($arguments | Measure-Object).Count -gt 0) 
			{				
				[JsonHelper]::ConvertToJsonCustom($arguments) | Out-File $this.FilePath
				#[JsonHelper]::ConvertToPson($arguments) | Out-File $($this.FilePath.Replace(".json", ".pson"))
			}
		}
    }

    [bool] IsSecurityEvaluationJsonFileRequired()
    {
        $generateSecurityEvaluationJsonFile = $false
        $ControlSettings = [ConfigurationManager]::LoadServerConfigFile("ControlSettings.json");
        if([Helpers]::CheckMember($ControlSettings, "GenerateSecurityEvaluationJsonFile") -and $ControlSettings.GenerateSecurityEvaluationJsonFile -eq $true){
            $generateSecurityEvaluationJsonFile = $true
        }
        return $generateSecurityEvaluationJsonFile;
    }
}
