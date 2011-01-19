setlocal

rd /s /q rel\dev
call rebar generate target_dir=dev overlay_vars=dev.config

