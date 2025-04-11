@echo off
echo Исправляем проблему с namespace для flutter_web_auth...

set FLUTTER_WEB_AUTH_PATH=%LOCALAPPDATA%\Pub\Cache\hosted\pub.dev\flutter_web_auth-0.5.0\android\build.gradle

echo Путь к файлу: %FLUTTER_WEB_AUTH_PATH%

if exist "%FLUTTER_WEB_AUTH_PATH%" (
    echo Файл найден. Добавляем namespace...
    
    (
        echo android {
        echo     namespace 'com.linusu.flutter_web_auth'
        type "%FLUTTER_WEB_AUTH_PATH%"
    ) > "%FLUTTER_WEB_AUTH_PATH%.tmp"
    
    move /y "%FLUTTER_WEB_AUTH_PATH%.tmp" "%FLUTTER_WEB_AUTH_PATH%"
    
    echo Исправление успешно применено!
) else (
    echo Ошибка: файл build.gradle для flutter_web_auth не найден!
    echo Проверьте путь: %FLUTTER_WEB_AUTH_PATH%
)

echo.
echo Нажмите любую клавишу для выхода...
pause > nul 