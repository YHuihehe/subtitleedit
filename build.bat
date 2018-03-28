@ECHO OFF
SETLOCAL

CD /D %~dp0

rem Check for the help switches
IF /I "%~1" == "help"   GOTO SHOWHELP
IF /I "%~1" == "/help"  GOTO SHOWHELP
IF /I "%~1" == "-help"  GOTO SHOWHELP
IF /I "%~1" == "--help" GOTO SHOWHELP
IF /I "%~1" == "/?"     GOTO SHOWHELP

for /f "usebackq tokens=1* delims=: " %%i in (`vswhere -latest -requires Microsoft.Component.MSBuild`) do (
  if /i "%%i"=="installationPath" set InstallDir=%%j
)

IF "%~1" == "" (
  SET "BUILDTYPE=Build"
) ELSE (
  IF /I "%~1" == "Build"     SET "BUILDTYPE=Build"   & GOTO START
  IF /I "%~1" == "/Build"    SET "BUILDTYPE=Build"   & GOTO START
  IF /I "%~1" == "-Build"    SET "BUILDTYPE=Build"   & GOTO START
  IF /I "%~1" == "--Build"   SET "BUILDTYPE=Build"   & GOTO START
  IF /I "%~1" == "Clean"     SET "BUILDTYPE=Clean"   & GOTO START
  IF /I "%~1" == "/Clean"    SET "BUILDTYPE=Clean"   & GOTO START
  IF /I "%~1" == "-Clean"    SET "BUILDTYPE=Clean"   & GOTO START
  IF /I "%~1" == "--Clean"   SET "BUILDTYPE=Clean"   & GOTO START
  IF /I "%~1" == "Rebuild"   SET "BUILDTYPE=Rebuild" & GOTO START
  IF /I "%~1" == "/Rebuild"  SET "BUILDTYPE=Rebuild" & GOTO START
  IF /I "%~1" == "-Rebuild"  SET "BUILDTYPE=Rebuild" & GOTO START
  IF /I "%~1" == "--Rebuild" SET "BUILDTYPE=Rebuild" & GOTO START

  ECHO. & ECHO Unsupported commandline switch!
  GOTO EndWithError
)


:START
PUSHD "src"

TITLE %BUILDTYPE%ing SubtitleEdit - Release^|Any CPU...

if exist "%InstallDir%\MSBuild\15.0\Bin\MSBuild.exe" (
  "%InstallDir%\MSBuild\15.0\Bin\MSBuild.exe" SubtitleEdit.sln /t:%BUILDTYPE% /p:Configuration=Release /p:Platform="Any CPU"^
 /maxcpucount /consoleloggerparameters:DisableMPLogging;Summary;Verbosity=minimal
  IF %ERRORLEVEL% NEQ 0 GOTO EndWithError
) else (
  ECHO Cannot find Visual Studio 2017
  GOTO EndWithError
)

IF /I "%BUILDTYPE%" == "Clean" GOTO END

ECHO.
ECHO ILRepack...
"packages\ILRepack.2.0.15\tools\ILRepack.exe" /parallel /internalize /targetplatform:v4 /out:"bin\Release\SubtitleEdit.exe" "bin\Release\SubtitleEdit.exe" "bin\Release\libse.dll" "bin\Release\zlib.net.dll" "bin\Release\NHunspell.dll" "DLLs\Interop.QuartzTypeLib.dll"
ECHO.
ECHO.
POPD

CALL :SubDetectSevenzipPath
IF DEFINED SEVENZIP IF EXIST "%SEVENZIP%" (
  CALL :SubGetVersion
  CALL :SubZipFile
)

CALL :SubDetectInnoSetup
IF DEFINED InnoSetupPath (
  TITLE Compiling installer...
  "%InnoSetupPath%" /O"." /Q "installer\Subtitle_Edit_installer.iss"
  IF %ERRORLEVEL% NEQ 0 GOTO EndWithError

  ECHO. & ECHO Installer compiled successfully!
) ELSE (
  ECHO Inno Setup wasn't found; the installer wasn't built
)


:END
TITLE Compiling Subtitle Edit finished!
ECHO.
ENDLOCAL
PAUSE
EXIT /B


:SubZipFile
TITLE Creating the ZIP file...
ECHO. & ECHO Creating the ZIP file...
PUSHD "src\bin\Release"
IF EXIST "temp_zip"                                RD /S /Q "temp_zip"
IF NOT EXIST "temp_zip"                            MD "temp_zip"
IF NOT EXIST "temp_zip\Languages"                  MD "temp_zip\Languages"
IF NOT EXIST "temp_zip\Tesseract4"                  MD "temp_zip\Tesseract4"
IF NOT EXIST "temp_zip\Tesseract4\tessdata"         MD "temp_zip\Tesseract4\tessdata"
IF NOT EXIST "temp_zip\Tesseract4\tessdata\configs" MD "temp_zip\Tesseract4\tessdata\configs"

COPY /Y /V "..\..\..\LICENSE.txt"                        "temp_zip\"
COPY /Y /V "..\..\..\Changelog.txt"                      "temp_zip\"
COPY /Y /V "Hunspellx86.dll"                             "temp_zip\"
COPY /Y /V "Hunspellx64.dll"                             "temp_zip\"
COPY /Y /V "SubtitleEdit.exe"                            "temp_zip\"
COPY /Y /V "Languages\*.xml"                             "temp_zip\Languages\"
COPY /Y /V "..\..\..\Tesseract4\tesseract.exe"            "temp_zip\Tesseract4\"
COPY /Y /V "..\..\..\Tesseract4\*.dll"            "temp_zip\Tesseract4\"
COPY /Y /V "..\..\..\Tesseract4\tessdata\configs\hocr"    "temp_zip\Tesseract4\tessdata\configs\"
COPY /Y /V "..\..\..\Tesseract4\tessdata\*.traineddata"   "temp_zip\Tesseract4\tessdata\"

PUSHD "temp_zip"
START "" /B /WAIT "%SEVENZIP%" a -tzip -mx=9 "SE%VERSION%.zip" * >NUL
IF %ERRORLEVEL% NEQ 0 GOTO EndWithError


ECHO. & ECHO ZIP file created successfully!
MOVE /Y "SE%VERSION%.zip" "..\..\..\.." >NUL
POPD
IF EXIST "temp_zip" RD /S /Q "temp_zip"
POPD

EXIT /B


:EndWithError
Title Compiling Subtitle Edit [ERROR]
ECHO. & ECHO.
ECHO  **ERROR: Build failed and aborted!**
PAUSE
ENDLOCAL
EXIT


:SHOWHELP
TITLE %~nx0 %1
ECHO. & ECHO.
ECHO Usage:   %~nx0 [Clean^|Build^|Rebuild]
ECHO.
ECHO Notes:   You can also prefix the commands with "-", "--" or "/".
ECHO          The arguments are not case sensitive.
ECHO. & ECHO.
ECHO Executing %~nx0 without any arguments is equivalent to "%~nx0 build"
ECHO.
ENDLOCAL
EXIT /B


:SubGetVersion
FOR /F delims^=^"^ tokens^=2 %%A IN ('FINDSTR /R /C:"AssemblyVersion" "src\Properties\AssemblyInfo.cs.template"') DO (
  rem 3.4.1.[REVNO]
  SET "VERSION=%%A"
)
rem 3.4.1: 0 from the left and -8 chars from the right
SET "VERSION=%VERSION:~0,-8%"
EXIT /B


:SubDetectSevenzipPath
FOR %%G IN (7z.exe) DO (SET "SEVENZIP_PATH=%%~$PATH:G")
IF EXIST "%SEVENZIP_PATH%" (SET "SEVENZIP=%SEVENZIP_PATH%" & EXIT /B)

FOR %%G IN (7za.exe) DO (SET "SEVENZIP_PATH=%%~$PATH:G")
IF EXIST "%SEVENZIP_PATH%" (SET "SEVENZIP=%SEVENZIP_PATH%" & EXIT /B)

FOR /F "tokens=2*" %%A IN (
  'REG QUERY "HKLM\SOFTWARE\7-Zip" /v "Path" 2^>NUL ^| FIND "REG_SZ" ^|^|
   REG QUERY "HKLM\SOFTWARE\Wow6432Node\7-Zip" /v "Path" 2^>NUL ^| FIND "REG_SZ"') DO SET "SEVENZIP=%%B\7z.exe"
EXIT /B


:SubDetectInnoSetup
FOR /F "tokens=5*" %%A IN (
  'REG QUERY "HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\Inno Setup 5_is1" /v "Inno Setup: App Path" 2^>NUL ^| FIND "REG_SZ" ^|^|
   REG QUERY "HKLM\SOFTWARE\Wow6432Node\Microsoft\Windows\CurrentVersion\Uninstall\Inno Setup 5_is1" /v "Inno Setup: App Path" 2^>NUL ^| FIND "REG_SZ"') DO SET "InnoSetupPath=%%B\ISCC.exe"
EXIT /B
