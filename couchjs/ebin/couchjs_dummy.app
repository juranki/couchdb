%% -*- mode:erlang;tab-width:4;erlang-indent-level:4;indent-tabs-mode:nil -*-
%% fake an erlang app
{application, couchjs_dummy,
 [
  {description, ""},
  {vsn, "1"},
  {modules, []},
  {registered, []},
  {applications, []},
  {mod, { mysample_app, []}},
  {env, []}]}.
