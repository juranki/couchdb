setlocal
rd /q /s build
mkdir build
pushd js
copy /b json2.js+filter.js+mimeparse.js+render.js+state.js+util.js+validate.js+views.js+loop.js ..\build\main.js
popd
copy /y %ICU_BIN%\*.dll .
copy /y %JS_BIN%\*.dll .
