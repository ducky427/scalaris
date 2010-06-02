% @copyright 2008-2010 Konrad-Zuse-Zentrum fuer Informationstechnik Berlin

%   Licensed under the Apache License, Version 2.0 (the "License");
%   you may not use this file except in compliance with the License.
%   You may obtain a copy of the License at
%
%       http://www.apache.org/licenses/LICENSE-2.0
%
%   Unless required by applicable law or agreed to in writing, software
%   distributed under the License is distributed on an "AS IS" BASIS,
%   WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
%   See the License for the specific language governing permissions and
%   limitations under the License.

%% @author Thorsten Schuett <schuett@zib.de>
%% @doc sample routing table
%% @end
%% @version $Id: rt_simple.erl 758 2010-04-30 15:06:20Z kruber@zib.de $
-module(rt_simple).
-author('schuett@zib.de').
-vsn('$Id$').

-behaviour(rt_beh).
-include("scalaris.hrl").

% routingtable behaviour
-export([empty/1, empty_ext/1,
         hash_key/1, getRandomNodeId/0, next_hop/2, init_stabilize/3,
         filterDeadNode/2, to_pid_list/1, get_size/1, get_keys_for_replicas/1,
         dump/1, to_list/1, export_rt_to_dht_node/4, n/0, to_html/1,
         update_pred_succ_in_dht_node/3, handle_custom_message/2,
         check/6, check/5, check_fd/2,
         check_config/0]).

-export([normalize/1]).

%% userdevguide-begin rt_simple:types
% @type key(). Identifier.
-type(key()::non_neg_integer()).
% @type rt(). Routing Table.
-type(rt()::{node:node_type(), gb_tree()}).
-type(external_rt()::{node:node_type(), gb_tree()}).
-type(custom_message() :: any()).
%% userdevguide-end rt_simple:types

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%% Key Handling
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

%% userdevguide-begin rt_simple:empty
%% @doc Creates an empty routing table.
%%      Per default the empty routing should already include the successor.
-spec empty(node:node_type()) -> rt().
empty(Succ) ->
    {Succ, gb_trees:empty()}.
%% userdevguide-end rt_simple:empty

%% userdevguide-begin rt_simple:hash_key
%% @doc Hashes the key to the identifier space.
-spec hash_key(iodata() | integer()) -> key().
hash_key(Key) when is_integer(Key) ->
    <<N:128>> = erlang:md5(erlang:term_to_binary(Key)),
    N;
hash_key(Key) ->
    <<N:128>> = erlang:md5(Key),
    N.
%% userdevguide-end rt_simple:hash_key

%% @doc Generates a random node id
%%      In this case it is a random 128-bit string.
-spec getRandomNodeId() -> key().
getRandomNodeId() ->
    hash_key(randoms:getRandomId()).

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%% RT Management
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

%% userdevguide-begin rt_simple:init_stabilize
%% @doc Triggered by a new stabilization round.
-spec init_stabilize(key(), node:node_type(), rt()) -> rt().
init_stabilize(_Id, Succ, _RT) ->
    % renew routing table
    empty(Succ).
%% userdevguide-end rt_simple:init_stabilize

%% userdevguide-begin rt_simple:filterDeadNode
%% @doc Removes dead nodes from the routing table.
-spec filterDeadNode(rt(), cs_send:mypid()) -> rt().
filterDeadNode(RT, _DeadPid) ->
    RT.
%% userdevguide-end rt_simple:filterDeadNode

%% userdevguide-begin rt_simple:to_pid_list
%% @doc Returns the pids of the routing table entries.
-spec to_pid_list(rt() | external_rt()) -> [cs_send:mypid()].
to_pid_list({Succ, _RoutingTable} = _RT) ->
    [node:pidX(Succ)].
%% userdevguide-end rt_simple:to_pid_list

%% @doc Returns the size of the routing table.
-spec get_size(rt() | external_rt()) -> non_neg_integer().
get_size(_RT) ->
    1.

%% userdevguide-begin rt_simple:get_keys_for_replicas
normalize(Key) ->
    Key band 16#FFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF.

n() ->
    16#100000000000000000000000000000000.

%% @doc Returns the replicas of the given key.
-spec get_keys_for_replicas(key()) -> [key()].
get_keys_for_replicas(Key) ->
    HashedKey = hash_key(Key),
    [HashedKey,
     HashedKey bxor 16#40000000000000000000000000000000,
     HashedKey bxor 16#80000000000000000000000000000000,
     HashedKey bxor 16#C0000000000000000000000000000000
    ].
%% userdevguide-end rt_simple:get_keys_for_replicas


%% userdevguide-begin rt_simple:dump
%% @doc Dumps the RT state for output in the web interface.
-spec dump(rt()) -> ok.
dump(_State) ->
    ok.
%% userdevguide-end rt_simple:dump

%% @doc Prepare routing table for printing in web interface.
-spec to_html(rt()) -> [char(),...].
to_html({Succ, _}) ->
    io_lib:format("succ: ~p", [Succ]).

%% @doc Checks whether config parameters of the rt_simple process exist and are
%%      valid (there are no config parameters).
-spec check_config() -> true.
check_config() ->
    true.

-include("rt_generic.hrl").

%% @doc There are no custom messages here.
-spec handle_custom_message(custom_message(), rt_loop:state_init()) -> unknown_event.
handle_custom_message(_Message, _State) ->
    unknown_event.

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% Communication with dht_node
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

-spec empty_ext(node:node_type()) -> external_rt().
empty_ext(Succ) ->
    empty(Succ).

%% userdevguide-begin rt_simple:next_hop
%% @doc Returns the next hop to contact for a lookup.
-spec next_hop(dht_node_state:state(), key()) -> cs_send:mypid().
next_hop(State, _Key) ->
    dht_node_state:get(State, succ_pid).
%% userdevguide-end rt_simple:next_hop

-spec export_rt_to_dht_node(rt(), key(), node:node_type(), node:node_type()) -> external_rt().
export_rt_to_dht_node(RT, _Id, _Pred, _Succ) ->
    RT.

-spec update_pred_succ_in_dht_node(node:node_type(), node:node_type(), external_rt())
      -> external_rt().
update_pred_succ_in_dht_node(_Pred, Succ, {_Succ, Tree} = _RT) ->
    {Succ, Tree}.

%% @doc Converts the (external) representation of the routing table to a list
%%      in the order of the fingers, i.e. first=succ, second=shortest finger,
%%      third=next longer finger,...
-spec to_list(dht_node_state:state()) -> nodelist:nodelist().
to_list(State) ->
    [dht_node_state:get(State, node), dht_node_state:get(State, succ)].
