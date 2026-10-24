@echo off
setlocal

if "%FIREBASE_AUTH_EMULATOR_HOST%"=="" (
  echo FIREBASE_AUTH_EMULATOR_HOST is required.
  exit /b 1
)

if "%FIRESTORE_EMULATOR_HOST%"=="" (
  echo FIRESTORE_EMULATOR_HOST is required.
  exit /b 1
)

if "%ANDROID_DEVICE_ID%"=="" set "ANDROID_DEVICE_ID=emulator-5554"

call npm.cmd --prefix firestore-rules-test run seed
if errorlevel 1 exit /b %errorlevel%

call flutter.bat test integration_test\firebase_emulator_android_test.dart -d %ANDROID_DEVICE_ID% -r compact --dart-define=USE_FIREBASE_EMULATORS=true > android-validation.log 2>&1
set "TEST_EXIT_CODE=%errorlevel%"
type android-validation.log
exit /b %TEST_EXIT_CODE%
