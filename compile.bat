setlocal

set ICU_LIB=C:/relax/icu/lib
set ICU_INCLUDE=C:/relax/icu/include
set JS_DIR=C:/relax/seamonkey-2.0.6/comm-1.9.1/mozilla/js/src
set CURL_LIB=C:/relax/curl-7.21.1/lib/LIB-Release
set CURL_INCLUDE=C:/relax/curl-7.21.1/include

call rebar compile

copy couchjs\couchjs.exe .
copy spawnkillable\spawnkillable.exe apps\couch\priv