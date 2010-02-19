% Licensed under the Apache License, Version 2.0 (the "License"); you may not
% use this file except in compliance with the License. You may obtain a copy of
% the License at
%
%   http://www.apache.org/licenses/LICENSE-2.0
%
% Unless required by applicable law or agreed to in writing, software
% distributed under the License is distributed on an "AS IS" BASIS, WITHOUT
% WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied. See the
% License for the specific language governing permissions and limitations under
% the License.

%%%-------------------------------------------------------------------
%%% File    : couch_fs.erl
%%% Author  :  <juhani@juranki.com>
%%% Description : Isolate CouchDB from filesystems differences between platforms
%%%-------------------------------------------------------------------
-module(couch_fs).

-behaviour(gen_server).

%% API
-export([start_link/0]).
-export([delete/1,delete_versioned/1,file_deleted/1,all_databases/0]).
-export([next_versioned_filepath/1,current_versioned_filepath/1]).

%% gen_server callbacks
-export([init/1, handle_call/3, handle_cast/2, handle_info/2,
         terminate/2, code_change/3]).

-record(state, {db_dir,pending_deletes}).

-define(PENDING_DELETES_FILE,".pending_deletes").


%%====================================================================
%% API
%%====================================================================

start_link() ->
    gen_server:start_link({local, ?MODULE}, ?MODULE, [], []).

delete(Filepath) ->
    gen_server:call(?MODULE,{delete,Filepath},infinity).

delete_versioned(Filepath) ->
    gen_server:call(?MODULE,{delete_versioned,Filepath},infinity).

file_deleted(Filepath) ->
    gen_server:cast(?MODULE,{file_deleted,Filepath}).
    
all_databases() ->
    gen_server:call(?MODULE,all_databases,infinity).

next_versioned_filepath(Filepath) ->
    case current_version_number(Filepath) of
        nil -> Filepath ++ ".0";
        N ->   Filepath ++ "." ++ integer_to_list(N + 1)
    end.
current_versioned_filepath(Filepath) ->
    case current_version_number(Filepath) of
        nil -> {error, enoent};
        N ->   Filepath ++ "." ++ integer_to_list(N)
    end.

%%====================================================================
%% gen_server callbacks
%%====================================================================

init([]) ->
    DbDir = couch_config:get("couchdb","database_dir"),
    PendingDeletes = load_pending_deletes(DbDir),
    error_logger:info_report(started_couch_fs),
    timer:send_interval(10000,process_pending_deletes),
    {ok, #state{db_dir=DbDir,
                pending_deletes=PendingDeletes}}.



handle_call({delete,Filepath}, From, 
            #state{db_dir=DbDir,
                   pending_deletes=PendingDeletes} = State) ->
    case current_versioned_filepath(Filepath) of
        {error,Reason} -> {reply, {error,Reason} , State};
        VersionedFilename ->
            case file:delete(VersionedFilename) of
                {error, eacces} ->
                    NewPendingDeletes = [VersionedFilename|PendingDeletes],
                    store_pending_deletes(DbDir,NewPendingDeletes),
                    {reply, ok, State#state{pending_deletes=NewPendingDeletes}};
                Other ->
                    {reply, Other, State}
            end
    end;
handle_call({delete_versioned,Filepath}, _From, 
            #state{db_dir=DbDir,
                   pending_deletes=PendingDeletes} = State) ->
    case file:delete(Filepath) of
        {error, eacces} ->
            NewPendingDeletes = [Filepath|PendingDeletes],
            store_pending_deletes(DbDir,NewPendingDeletes),
            {reply, ok, State#state{pending_deletes=NewPendingDeletes}};
        {error,eperm} ->
            case file:del_dir(Filepath) of
                {error, eacces} ->
                    NewPendingDeletes = [Filepath|PendingDeletes],
                    store_pending_deletes(DbDir,NewPendingDeletes),
                    {reply, ok, State#state{pending_deletes=NewPendingDeletes}};
                {error, eexist} ->
                    NewPendingDeletes = [Filepath|PendingDeletes],
                    store_pending_deletes(DbDir,NewPendingDeletes),
                    {reply, ok, State#state{pending_deletes=NewPendingDeletes}};
                Other ->
                    {reply, Other, State}
            end;
        Other ->
            {reply, Other, State}
    end;
handle_call({create,Filepath}, _From, State) ->
    VersionedFilepath = next_versioned_filepath(Filepath),
    {reply, file:open(VersionedFilepath, [read, write, raw, binary]), State};
handle_call({open,Filepath}, _From, State) ->
    case current_versioned_filepath(Filepath) of
        nil ->
            {reply, {error, enoent}, State};
        VersionedFilepath ->
            {reply, file:open(VersionedFilepath, [read, write, raw, binary]),State}
    end;
handle_call(all_databases, _From, #state{db_dir=DbDir,
                                         pending_deletes=PendingDeletes} = State) ->
    Filenames =
        filelib:fold_files(DbDir, "^[a-z0-9\\_\\$()\\+\\-]*[\\.]couch[\\.][0-9]+$", true,
            fun(Filename, AccIn) ->
                case lists:member(Filename,PendingDeletes) of
                    true ->
                        AccIn;
                    false ->
                        case Filename -- DbDir of
                            [$/ | RelativeFilename] -> ok;
                            RelativeFilename -> ok
                        end,
                        DBName = re:replace(RelativeFilename,
                                            "\.couch\.[0-9]+$","",[{return,binary}]),
                        [DBName | AccIn]
                end
            end,[]),
    {reply, {ok, lists:usort(Filenames)}, State};
handle_call(_Request, _From, State) ->
    Reply = ok,
    {reply, Reply, State}.



handle_cast({file_deleted,Filepath}, #state{pending_deletes=PendingDeletes,
                                            db_dir=DbDir}=State) ->
    NewPendingDeletes = lists:delete(Filepath,PendingDeletes),
    store_pending_deletes(DbDir,NewPendingDeletes),
    {noreply, State#state{pending_deletes=NewPendingDeletes}};
handle_cast(_Msg, State) ->
    {noreply, State}.


handle_info(process_pending_deletes,
            #state{pending_deletes=PendingDeletes}=State) ->
    process_pending_deletes(PendingDeletes),
    {noreply, State};
handle_info({'DOWN', _Ref, process, _Pid2, _Reason},
            #state{pending_deletes=PendingDeletes}=State) ->
    process_pending_deletes(PendingDeletes),
    {noreply, State};
handle_info(_Info, State) ->
    {noreply, State}.


terminate(_Reason, _State) ->
    ok.

code_change(_OldVsn, State, _Extra) ->
    {ok, State}.


%%--------------------------------------------------------------------
%%% Internal functions
%%--------------------------------------------------------------------

load_pending_deletes(DbDir) ->
    Filepath = filename:join(DbDir, ?PENDING_DELETES_FILE),
    case file:read_file(Filepath) of
        {ok,Bin} ->
            string:tokens(binary_to_list(Bin),"\n");
        {error,enoent} ->
            []
    end.

store_pending_deletes(DbDir, Files) ->
    Filepath = filename:join(DbDir, ?PENDING_DELETES_FILE),
    Data = list_to_binary(string:join(Files,"\n")),
    file:write_file(Filepath,Data).


find_file_versions(Filepath) ->
    Root = filename:dirname(Filepath),
    Base = filename:basename(Filepath),
    filelib:fold_files(Root,"^" ++ Base ++ "\.[0-9]+$",false,
                       fun(File,AccIn) ->
                               [File | AccIn]
                       end, []).

current_version_number(Filepath) ->
    case find_file_versions(Filepath) of
        [] -> nil;
        Filepaths ->
            L = length(Filepath) + 1,
            lists:max(
              lists:map(fun(P) ->
                                list_to_integer(lists:nthtail(L,P))
                        end,
                        Filepaths))
    end.

process_pending_deletes(Filepaths) ->
    %error_logger:info_report({process_pending_deletes,Filepaths}),
    spawn(fun() ->
                  lists:foreach(fun(Filepath) ->
                                        %error_logger:info_report({deleting,Filepath}),
                                        case file:delete(Filepath) of
                                            ok ->
                                                couch_fs:file_deleted(Filepath);
                                            {error,enoent} ->
                                                couch_fs:file_deleted(Filepath);

                                            {error,eperm} ->
                                                case file:del_dir(Filepath) of
                                                    ok ->
                                                        couch_fs:file_deleted(Filepath); 
                                                   _ ->
                                                        ok
                                                end;
                                            _ ->
                                                ok
                                        end
                                end,
                                Filepaths)
          end).
