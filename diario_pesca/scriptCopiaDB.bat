@echo off
set ADB="%LOCALAPPDATA%\Android\Sdk\platform-tools\adb.exe"
set PKG=com.example.diario_pesca
set DB_NAME=diario_pesca.db
set DEST=C:\Users\Celeste\Documents\GitHub\LC_Tesi\diario_pesca

echo [1/4] Chiusura app per salvare eventuali modifiche pendenti...
%ADB% shell am force-stop %PKG%

echo [2/4] Controllo file sul telefono...
%ADB% shell "run-as %PKG% ls -la databases"

echo [3/4] Estrazione database...
%ADB% shell "run-as %PKG% cat databases/%DB_NAME% > /data/local/tmp/%DB_NAME%"

echo [4/4] Copia sul PC...
%ADB% pull /data/local/tmp/%DB_NAME% "%DEST%\%DB_NAME%"

echo.
echo Operazione completata! Premi F5 in DBeaver per aggiornare i dati.
pause