@echo off
setlocal

cd /d "%~dp0"

rem CMake picks the newest Visual Studio unless SOLOUD_CMAKE_GENERATOR names
rem one, for example "Visual Studio 17 2022".
set "GENERATOR="
if defined SOLOUD_CMAKE_GENERATOR set GENERATOR=-G "%SOLOUD_CMAKE_GENERATOR%"

echo Building SoLoud Windows x64 DLL...
cmake -S contrib -B contrib\build-win64 %GENERATOR% -A x64 ^
  -DCMAKE_BUILD_TYPE=Release ^
  -DBUILD_SHARED_LIBS=ON -DSOLOUD_DYNAMIC=ON -DSOLOUD_STATIC=OFF -DSOLOUD_C_API=ON ^
  -DSOLOUD_GENERATE_GLUE=OFF -DSOLOUD_BUILD_DEMOS=OFF -DSOLOUD_BACKEND_SDL2=OFF ^
  -DSOLOUD_BACKEND_ALSA=OFF -DSOLOUD_BACKEND_OPENSLES=OFF -DSOLOUD_BACKEND_COREAUDIO=OFF ^
  -DSOLOUD_BACKEND_WASAPI=ON -DSOLOUD_BACKEND_WINMM=ON -DSOLOUD_BACKEND_NULL=ON ^
  -DSOLOUD_MSVC_STATIC_RUNTIME=ON
if %errorlevel% neq 0 exit /b %errorlevel%

cmake --build contrib\build-win64 --config Release
if %errorlevel% neq 0 exit /b %errorlevel%

if not exist bin mkdir bin
if not exist lib mkdir lib

copy /Y contrib\build-win64\Release\soloud.dll bin\soloud.dll
copy /Y contrib\build-win64\Release\soloud.dll bin\soloud_x64.dll
copy /Y contrib\build-win64\Release\soloud.lib lib\soloud.lib
copy /Y contrib\build-win64\Release\soloud.lib lib\soloud_x64.lib

echo.
echo ========================================================
echo Build complete:
echo   bin\soloud.dll (x64)
echo   bin\soloud_x64.dll
echo   lib\soloud.lib
echo   lib\soloud_x64.lib
echo ========================================================
