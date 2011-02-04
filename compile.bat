setlocal

set ICU_LIB=C:/relax/icu/lib
set ICU_INCLUDE=C:/relax/icu/include
set ICU_BIN=C:\relax\icu\bin
set JS_DIR=C:/relax/seamonkey-2.0.6/comm-1.9.1/mozilla/js/src
set JS_BIN=C:\relax\seamonkey-2.0.6\comm-1.9.1\mozilla\js\src
::set JS_DIR=C:/relax/comm-1.9.1/mozilla/js/src
set CURL_LIB=C:/relax/curl-7.21.1/lib/LIB-Release
set CURL_INCLUDE=C:/relax/curl-7.21.1/include

call rebar compile

pushd rel
echo {data_dir, "../var/lib/couchdb"}.> dev.config
echo {view_dir, "../var/lib/couchdb"}.>> dev.config
echo {couchdb_port, 5984}.>> dev.config
echo {ssl_port, 6985}.>> dev.config
echo {prefix, ".."}.>> dev.config
echo {view_dir, "../var/lib/couchdb"}.>> dev.config
echo {node_name, "-sname dev"}.>> dev.config
popd
