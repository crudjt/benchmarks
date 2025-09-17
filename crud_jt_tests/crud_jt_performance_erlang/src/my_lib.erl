-module(my_lib).

-export([main/1]).

-define(MAX_HASH_SIZE, 256).

data_size(Data) ->
    case 'Elixir.Msgpax':pack(Data) of
        {ok, Iodata} ->
            Bin = erlang:iolist_to_binary(Iodata),
            byte_size(Bin);
        _ ->
            0
    end.

main(_) ->
    AddPath = fun(Path) -> code:add_patha(Path) end,
    lists:foreach(AddPath, filelib:wildcard("_build/default/lib/*/ebin")),

    %% запускаємо бібліотеку
    crud_jt:start(#{encrypted_key =>
        <<"Cm7B68NWsMNNYjzMDREacmpe5sI1o0g40ZC9w1yQW3WOes7Gm59UsittLOHR2dciYiwmaYq98l3tG8h9yXVCxg==">>}),

    %% OS + version
    print_os(),

    %% CPU
    Arch = erlang:system_info(system_architecture),
    io:format("CPU: ~s~n", [Arch]),

    Requests = 40000,
    Data0 = #{
        <<"user_id">> => 414243,
        <<"role">> => 11,
        <<"devices">> => #{
            <<"ios_expired_at">> => <<"2025-02-18 20:41:59 +0200">>,
            <<"android_expired_at">> => <<"2025-02-18 20:41:59 +0200">>,
            <<"mobile_app_expired_at">> => <<"2025-02-18 20:41:59 +0200">>,
            <<"external_api_integration_expired_at">> => <<"2025-02-18 20:41:59 +0200">>
        },
        <<"a">> => <<"aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa">>
    },

    %% Підганяємо Data до 256 байтів
    Data = adjust_data(Data0),

    Updated = #{<<"user_id">> => 42, <<"role">> => 11},

    io:format("Hash bytesize:: ~p bytes~n", [data_size(Data)]),

    run_benchmarks(10, Requests, Data, Updated).

%% ---------------- Data adjuster ----------------
adjust_data(Data) ->
    case data_size(Data) of
        Size when Size =< ?MAX_HASH_SIZE ->
            Data;
        _ ->
            A0 = maps:get(<<"a">>, Data),
            Sz = byte_size(A0),
            case Sz of
                0 -> Data;
                _ ->
                    A1 = binary:part(A0, 0, Sz - 1),
                    adjust_data(Data#{<<"a">> := A1})
            end
    end.

%% ---------------- OS + Version ----------------
print_os() ->
    case os:type() of
        {unix, darwin} ->
            Version = string:trim(os:cmd("sw_vers -productVersion")),
            io:format("OS: darwin (~s)~n", [Version]);
        {unix, linux} ->
            Version = string:trim(os:cmd("uname -r")),
            io:format("OS: linux (~s)~n", [Version]);
        {win32, _} ->
            Version = string:trim(os:cmd("ver")),
            io:format("OS: windows (~s)~n", [Version]);
        Other ->
            io:format("OS: unknown (~p)~n", [Other])
    end.

%% ---------------- Benchmarks ----------------
run_benchmarks(Count, Requests, Data, Updated) ->
    CreateTimes = [],
    ReadTimes = [],
    UpdateTimes = [],
    DeleteTimes = [],
    {CT, RT, UT, DT} = loop(Count, Requests, Data, Updated,
                            CreateTimes, ReadTimes, UpdateTimes, DeleteTimes),
    print_stats("Create", CT),
    print_stats("Read", RT),
    print_stats("Update", UT),
    print_stats("Delete", DT).

loop(0, _, _, _, CT, RT, UT, DT) ->
    {CT, RT, UT, DT};
loop(N, Requests, Data, Updated, CT, RT, UT, DT) ->
    io:format("Checking scale load...~n", []),

    %% create
    {TimeC, List} = timer:tc(fun() ->
        lists:foldl(fun(_, Acc) -> [crud_jt:create(Data) | Acc] end, [], lists:seq(1, Requests))
    end),
    SecC = TimeC / 1000000,
    io:format("when creates 40k values: ~p~n", [SecC]),

    %% read
    {TimeR, _} = timer:tc(fun() ->
        lists:foreach(fun(V) -> crud_jt:read(V) end, List)
    end),
    SecR = TimeR / 1000000,
    io:format("when reads 40k values: ~p~n", [SecR]),

    %% update
    {TimeU, _} = timer:tc(fun() ->
        lists:foreach(fun(V) -> crud_jt:update(V, Updated) end, List)
    end),
    SecU = TimeU / 1000000,
    io:format("when updates 40k values: ~p~n", [SecU]),

    %% delete
    {TimeD, _} = timer:tc(fun() ->
        lists:foreach(fun(V) -> crud_jt:delete(V) end, List)
    end),
    SecD = TimeD / 1000000,
    io:format("when deletes 40k values: ~p~n", [SecD]),

    loop(N - 1, Requests, Data, Updated, [SecC|CT], [SecR|RT], [SecU|UT], [SecD|DT]).

%% ---------------- Helpers ----------------
print_stats(Label, Times) ->
    Sorted = lists:sort(Times),
    Len = length(Sorted),
    Median = lists:nth((Len div 2) + 1, Sorted),
    Min = hd(Sorted),
    Max = lists:last(Sorted),
    io:format("~nOn ~s~n", [Label]),
    io:format("Mediana: ~p~n", [Median]),
    io:format("Min: ~p~n", [Min]),
    io:format("Max: ~p~n", [Max]).
