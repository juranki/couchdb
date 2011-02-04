setlocal

for /f "tokens=1,2 delims= " %%a in (..\releases\start_erl.data) do (
    set ERTS_VSN=%%a
    set APP_VSN=%%b
)

set BINDIR=..\erts-%ERTS_VSN%\bin

%BINDIR%\erl -boot ..\releases\%APP_VSN%\couchdb -args_file ..\etc\vm.args
