%%%-------------------------------------------------------------------
%%% @author balegas
%%% @copyright (C) 2014, <COMPANY>
%%% @doc
%%%
%%% @end
%%% Created : 10. Jan 2014 11:50
%%%-------------------------------------------------------------------
-author("balegas").
-record(worker, {id :: term(), lnk:: term() , last_permission_request :: pos_integer(), bucket :: binary(), port :: pos_integer() | {binary(),binary()}}).