@echo off
SET SSDIR=\\192.168.0.2\VSS
SET SSUSER=YourUser
SET SSPASSWORD=YourPassword
SET SSLOGIN=-Y%SSUSER%,%SSPASSWORD%
SET WORKDIR=C:\VSS Client

cd /d "%WORKDIR%"

SS Create "$/TestApp" %SSLOGIN% -C"Main test application"
SS Create "$/TestApp/Source" %SSLOGIN% -C"Source code"  
SS Create "$/TestApp/Resources" %SSLOGIN% -C"Binary resources"
SS Create "$/TestApp/Docs" %SSLOGIN% -C"Documentation"
SS Create "$/TestApp/Shared" %SSLOGIN% -C"Shared components"

echo program TestApp; > TestApp.dpr
echo {Test application for VSS migration} >> TestApp.dpr
echo {Тестово приложение за миграция} >> TestApp.dpr
echo uses >> TestApp.dpr  
echo   SysUtils, Forms, MainUnit; >> TestApp.dpr
echo begin >> TestApp.dpr
echo   Application.Initialize; >> TestApp.dpr
echo   Application.Title := 'Test App - Тестово приложение'; >> TestApp.dpr
echo   WriteLn('Starting - Стартиране v1.0'); >> TestApp.dpr
echo   Application.Run; >> TestApp.dpr
echo end. >> TestApp.dpr

echo unit MainUnit; > MainUnit.pas
echo interface >> MainUnit.pas
echo uses >> MainUnit.pas
echo   Windows, Messages, SysUtils, Forms; >> MainUnit.pas
echo type >> MainUnit.pas
echo   TMainForm = class(TForm) >> MainUnit.pas
echo     procedure FormCreate(Sender: TObject); >> MainUnit.pas
echo   private >> MainUnit.pas
echo     procedure LogMessage(const aMessage: string); >> MainUnit.pas
echo   public >> MainUnit.pas
echo     function GetVersion: string; >> MainUnit.pas
echo   end; >> MainUnit.pas
echo. >> MainUnit.pas
echo implementation >> MainUnit.pas
echo. >> MainUnit.pas
echo procedure TMainForm.FormCreate(Sender: TObject); >> MainUnit.pas
echo var >> MainUnit.pas
echo   tmpWelcome: string; >> MainUnit.pas
echo begin >> MainUnit.pas
echo   tmpWelcome := 'Добре дошли! Welcome!'; >> MainUnit.pas
echo   LogMessage('Form created - Формата е създадена'); >> MainUnit.pas
echo   Caption := tmpWelcome; >> MainUnit.pas
echo end; >> MainUnit.pas
echo. >> MainUnit.pas
echo function TMainForm.GetVersion: string; >> MainUnit.pas
echo var >> MainUnit.pas
echo   tmpVersion: string; >> MainUnit.pas
echo begin >> MainUnit.pas
echo   tmpVersion := '1.0'; >> MainUnit.pas
echo   Result := 'Version ' + tmpVersion + ' - Версия ' + tmpVersion; >> MainUnit.pas
echo end; >> MainUnit.pas
echo. >> MainUnit.pas
echo procedure TMainForm.LogMessage(const aMessage: string); >> MainUnit.pas
echo begin >> MainUnit.pas
echo   OutputDebugString(PChar(aMessage)); >> MainUnit.pas
echo end; >> MainUnit.pas
echo. >> MainUnit.pas
echo end. >> MainUnit.pas

echo unit SharedUtils; > SharedUtils.pas
echo {Shared utility module - Споделен модул} >> SharedUtils.pas
echo interface >> SharedUtils.pas
echo function FormatMessage(const aText: string): string; >> SharedUtils.pas
echo implementation >> SharedUtils.pas
echo function FormatMessage(const aText: string): string; >> SharedUtils.pas
echo var >> SharedUtils.pas
echo   tmpResult: string; >> SharedUtils.pas
echo begin >> SharedUtils.pas
echo   tmpResult := '[MSG] ' + aText; >> SharedUtils.pas
echo   Result := tmpResult; >> SharedUtils.pas
echo end; >> SharedUtils.pas
echo end. >> SharedUtils.pas

echo ÿÿÿÿÿÿÿÿÿÿÿÿÿÿÿÿÿÿÿÿÿÿÿÿÿÿÿÿÿÿÿÿÿÿÿÿÿÿÿÿÿÿÿÿÿ > app.ico

echo # Test Documentation > README.txt
echo Test project for VSS to Git migration >> README.txt
echo Тестов проект за миграция от VSS към Git >> README.txt

echo Temporary file for deletion test > TempFile.txt
echo File for permanent destruction > DestroyMe.txt
echo File to be purged after deletion > PurgeMe.txt

SS CP "$/TestApp/Source/" %SSLOGIN%
SS Add TestApp.dpr %SSLOGIN% -C"Main project file"
SS Add MainUnit.pas %SSLOGIN% -C"Главен модул с българско съдържание"

SS CP "$/TestApp/Shared/" %SSLOGIN%
SS Add SharedUtils.pas %SSLOGIN% -C"Shared utility module"

SS CP "$/TestApp/Resources/" %SSLOGIN%
SS Add app.ico %SSLOGIN% -C"Application icon"
SS Filetype "$/TestApp/Resources/app.ico" -B %SSLOGIN%

SS CP "$/TestApp/Docs/" %SSLOGIN%
SS Add README.txt %SSLOGIN% -C"Project documentation"
SS Add TempFile.txt %SSLOGIN% -C"File for deletion test"
SS Add DestroyMe.txt %SSLOGIN% -C"File for destroy test"
SS Add PurgeMe.txt %SSLOGIN% -C"File for purge test"

REM Get all files with proper directory structure - using working pattern
mkdir TestApp
cd TestApp
SS CP "$/TestApp" %SSLOGIN%
echo Y | SS Get *.* -R -I-Y %SSLOGIN%

REM Create version history
cd Source
SS CP "$/TestApp/Source/" %SSLOGIN%
SS Checkout MainUnit.pas %SSLOGIN% -C"Adding new functionality"
echo     procedure ShowAbout; >> MainUnit.pas
echo. >> MainUnit.pas
echo procedure TMainForm.ShowAbout; >> MainUnit.pas
echo var >> MainUnit.pas
echo   tmpAbout: string; >> MainUnit.pas
echo begin >> MainUnit.pas
echo   tmpAbout := 'Test App v1.1 - Тест приложение v1.1'; >> MainUnit.pas
echo   ShowMessage(tmpAbout); >> MainUnit.pas
echo end; >> MainUnit.pas
SS Checkin MainUnit.pas %SSLOGIN% -C"Добавена About функция"

cd ..
SS CP "$/TestApp" %SSLOGIN%
echo v1.0 | SS Label . %SSLOGIN% -C"Първа версия"

REM Test file sharing
SS CP "$/TestApp/Source" %SSLOGIN%
SS Share "$/TestApp/Shared/SharedUtils.pas" %SSLOGIN% -C"Share utils to main source"

REM Check links
SS Links SharedUtils.pas %SSLOGIN%

REM Create branch project
SS Create "$/TestApp_Branch" %SSLOGIN% -C"Branch project"
SS CP "$/TestApp_Branch" %SSLOGIN%
SS Share "$/TestApp/Source" -E %SSLOGIN% -C"Branch Source"
SS Share "$/TestApp/Shared" -E %SSLOGIN% -C"Branch Shared"
SS Share "$/TestApp/Resources" -E %SSLOGIN% -C"Branch Resources"
SS Share "$/TestApp/Docs" -E %SSLOGIN% -C"Branch Docs"

cd ..
mkdir TestApp_Branch
cd TestApp_Branch
SS CP "$/TestApp_Branch" %SSLOGIN%
echo Y | SS Get *.* -R -I-Y %SSLOGIN%

cd Source
SS CP "$/TestApp_Branch/Source" %SSLOGIN%
SS Checkout MainUnit.pas %SSLOGIN% -C"Branch modifications"
echo     procedure ShowBranchInfo; >> MainUnit.pas
echo. >> MainUnit.pas
echo procedure TMainForm.ShowBranchInfo; >> MainUnit.pas
echo var >> MainUnit.pas
echo   tmpBranchInfo: string; >> MainUnit.pas
echo begin >> MainUnit.pas
echo   tmpBranchInfo := 'Branch feature - Функция от клона'; >> MainUnit.pas
echo   ShowMessage(tmpBranchInfo); >> MainUnit.pas
echo end; >> MainUnit.pas
SS Checkin MainUnit.pas %SSLOGIN% -C"Промени в клона"

cd ..\..
cd TestApp\Shared
SS CP "$/TestApp/Shared" %SSLOGIN%
SS Checkout SharedUtils.pas %SSLOGIN% -C"Modify shared file"
echo function GetCurrentTime: string; >> SharedUtils.pas
echo var >> SharedUtils.pas
echo   tmpTime: string; >> SharedUtils.pas
echo begin >> SharedUtils.pas
echo   tmpTime := TimeToStr(Now); >> SharedUtils.pas
echo   Result := tmpTime; >> SharedUtils.pas
echo end; >> SharedUtils.pas
SS Checkin SharedUtils.pas %SSLOGIN% -C"Добавена функция за време"

cd ..
SS CP "$/TestApp" %SSLOGIN%
echo before-merge | SS Label . %SSLOGIN% -C"Преди merge"

cd Source
SS CP "$/TestApp/Source" %SSLOGIN%
SS Checkout MainUnit.pas %SSLOGIN% -C"Prepare for merge"
SS Merge "$/TestApp_Branch/Source/MainUnit.pas" MainUnit.pas %SSLOGIN% -C"Merge branch to main"
SS Checkin MainUnit.pas %SSLOGIN% -C"Merged changes"

cd ..
SS CP "$/TestApp" %SSLOGIN%
echo after-merge | SS Label . %SSLOGIN% -C"След merge"

cd Docs
SS CP "$/TestApp/Docs" %SSLOGIN%  
SS Delete TempFile.txt %SSLOGIN%
echo Y | SS Destroy DestroyMe.txt %SSLOGIN%
SS Delete PurgeMe.txt %SSLOGIN%
SS Purge PurgeMe.txt %SSLOGIN%
SS Dir -D %SSLOGIN%
SS Recover TempFile.txt %SSLOGIN%

cd ..\Source
SS CP "$/TestApp/Source" %SSLOGIN%
SS Checkout TestApp.dpr %SSLOGIN% -C"Final update"
echo   WriteLn('Final version - Финална версия 1.2'); >> TestApp.dpr
SS Checkin TestApp.dpr %SSLOGIN% -C"Финална версия"

cd ..
SS CP "$/TestApp" %SSLOGIN%
echo v1.2-final | SS Label . %SSLOGIN% -C"Финална версия"

cd ..\TestApp_Branch
SS CP "$/TestApp_Branch" %SSLOGIN%
echo branch-final | SS Label . %SSLOGIN% -C"Финална версия Branch"

cd "%WORKDIR%"
echo.
echo VSS MIGRATION TEST REPOSITORY CREATED
echo All scenarios tested: files, sharing, branching, merging, deletion
echo.

del TestApp.dpr MainUnit.pas SharedUtils.pas app.ico README.txt TempFile.txt DestroyMe.txt PurgeMe.txt 2>nul
pause