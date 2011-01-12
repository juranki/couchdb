setlocal

set CC=cl
set DRV_CFLAGS=$ERL_CFLAGS
set DRV_LDFLAGS=/LD /MD /link /LIBPATH:$ERL_EI_LIBS erl_interface.lib ei.lib

set REBAR_CC_TEMPLATE=$CC /c $DRV_CFLAGS ~s /Fo~s
set REBAR_LINK_TEMPLATE=$CC ~s /Fe~s $DRV_LDFLAGS

rebar compile
