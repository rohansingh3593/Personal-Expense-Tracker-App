@echo off
setlocal enabledelayedexpansion

where flutter >nul 2>nul
if errorlevel 1 (
  echo flutter not found in PATH
  exit /b 127
)

set HAS_SAFE_FLAVOR=0
if exist android\app\build.gradle (
  findstr /R /C:"productFlavors" /C:"create(\"safe\")" /C:"safe[ ]*{" android\app\build.gradle >nul && set HAS_SAFE_FLAVOR=1
)
if exist android\app\build.gradle.kts (
  findstr /R /C:"productFlavors" /C:"create(\"safe\")" /C:"safe[ ]*{" android\app\build.gradle.kts >nul && set HAS_SAFE_FLAVOR=1
)

call flutter clean || exit /b %errorlevel%
call flutter pub get || exit /b %errorlevel%

if "%HAS_SAFE_FLAVOR%"=="1" (
  echo Detected safe flavor. Running flavored release build...
  call flutter build apk --flavor safe --release
) else (
  echo No safe flavor detected. Running default release build...
  call flutter build apk --release
)
exit /b %errorlevel%
