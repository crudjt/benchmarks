%%! -smp enable -pa _build/default/lib/*/ebin
%% escript src/my_lib.erl
-module(my_lib).
-export([main/1]).

-define(MAX_HASH_SIZE, 256).
-define(HMAC_SECRET, <<"Cm7B68NWsMNNYjzMDREacmpe5sI1o0g40ZC9w1yQW3WOes7Gm59UsittLOHR2dciYiwmaYq98l3tG8h9yXVCxg==">>).
-define(ALG, <<"HS256">>).
-define(REQUESTS, 40000).
-define(ROUNDS, 10).

main(_) ->
    %% ensure dependencies
    application:ensure_all_started(jwt),
    application:ensure_all_started(msgpack),

    %% OS + Erlang info
    {OsFamily, OsName} = os:type(),
    OsVersion =
    case OsFamily of
        unix ->
            case OsName of
                darwin -> string:trim(os:cmd("sw_vers -productVersion"));
                linux  -> string:trim(os:cmd("uname -r"));
                _      -> "unknown"
            end;
        win32 ->
            string:trim(os:cmd("ver"))
    end,
    io:format("OS: ~p (~p) version ~s~n", [OsFamily, OsName, OsVersion]),
    io:format("Erlang/OTP: ~s~n", [erlang:system_info(otp_release)]),

    %% Current ISO timestamp
    IsoNow = now_iso8601(),

    %% Initial data
    Data0 = [
        {user_id, 414243},
        {role, 11},
        {devices, [
            {ios_expired_at, IsoNow},
            {android_expired_at, IsoNow},
            {external_api_integration_expired_at, IsoNow}
        ]},
        {a, lists:duplicate(100, $a)}
    ],

    %% Resize to max hash size
    Data = adjust_data(Data0, ?HMAC_SECRET),
    io:format("Hash bytesize: ~p~n", [data_size(Data)]),

    %% run benchmark
    run_benchmarks(?ROUNDS, ?REQUESTS, Data).


%% ---------------- Adjust data ----------------
adjust_data(Data, Secret) ->
    Bin = term_to_binary(Data),
    Size = byte_size(Bin),
    case Size =< ?MAX_HASH_SIZE of
        true -> Data;
        false ->
            %% Trim "a" field
            case lists:keyfind(a, 1, Data) of
                false -> Data;
                {a, AList} ->
                    case length(AList) of
                        0 -> Data;
                        Len ->
                            A1 = lists:sublist(AList, Len - 1),
                            NewData = lists:keyreplace(a, 1, Data, {a, A1}),
                            adjust_data(NewData, Secret)
                    end
            end
    end.


%% --------- msgpack size ---------
data_size(D) ->
    Packed = term_to_binary(D),
    byte_size(Packed).

%% --------- benchmarks ---------
run_benchmarks(Rounds, Requests, Data) ->
    CreateTimes = [],
    VerifyTimes = [],
    {CT, VT} = loop(Rounds, Requests, Data, CreateTimes, VerifyTimes),
    print_stats("On Create", CT),
    print_stats("On Read", VT).

loop(0, _, _, CT, VT) -> {CT, VT};
loop(N, Requests, Data, CT, VT) ->
    io:format("~n=== Round ~p ===~n", [?ROUNDS - N + 1]),
    %% create tokens
    {CreateUs, Tokens} = timer:tc(fun() ->
        [create_jwt(Data) || _ <- lists:seq(1, Requests)]
    end),
    CreateSec = CreateUs / 1000000,
    io:format("Create time for ~p tokens: ~.3f sec~n",
              [Requests, CreateSec]),

    %% verify tokens
    {VerifyUs, _} = timer:tc(fun() ->
        lists:foreach(fun(T) -> verify_jwt(T) end, Tokens)
    end),
    VerifySec = VerifyUs / 1000000,
    io:format("Read time for ~p tokens: ~.3f sec~n",
              [Requests, VerifySec]),

    loop(N - 1, Requests, Data,
         [CreateSec|CT], [VerifySec|VT]).

%% --------- create/verify JWT ---------
create_jwt(Data) ->
    %% Data вже у вигляді [{Key,Value},...]
    {ok, Token} = jwt:encode(?ALG, Data, ?HMAC_SECRET),
    Token.

verify_jwt(Token) ->
    {ok, _Claims} = jwt:decode(Token, ?HMAC_SECRET),
    ok.

%% --------- helpers ---------
print_stats(Label, Times) ->
    Sorted = lists:sort(Times),
    Len = length(Sorted),
    Median =
        case Len rem 2 of
            1 -> lists:nth((Len + 1) div 2, Sorted);
            0 -> (lists:nth(Len div 2, Sorted)
                  + lists:nth(Len div 2 + 1, Sorted)) / 2
        end,
    io:format("~n~s~nMediana: ~p~nMin: ~p~nMax: ~p~n",
              [Label, Median, hd(Sorted), lists:last(Sorted)]).

now_iso8601() ->
    {Date, Time} = calendar:universal_time(),
    {Y,M,D} = Date,
    {H,Min,S} = Time,
    lists:flatten(io_lib:format("~4..0B-~2..0B-~2..0BT~2..0B:~2..0B:~2..0BZ",
                               [Y,M,D,H,Min,S])).
