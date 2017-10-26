defmodule HonteD.Eventer do
  @moduledoc """
  Handles stream of send events from HonteD.ABCI and forwards them to subscribers.

  This implementation is as simple as it can be.

  Generic process registries are a bad fit since we want to hyper-optimize for
  particular use case (bloom filters etc).
  """
  use GenServer

  @typep topic :: binary
  @typep subs :: BiMultiMap.t([topic], pid)
  @typep state :: %{:subs => subs,
                    :monitors => %{pid => reference}}

  ## API

  def notify_committed(server \\ __MODULE__, event) do
    GenServer.cast(server, {:event, event})
  end

  def subscribe_send(server \\ __MODULE__, pid, receiver) do
    with true <- is_valid_subscriber(pid),
         true <- is_valid_topic(receiver),
    do: GenServer.call(server, {:subscribe, pid, [receiver]})
  end

  def unsubscribe_send(server \\ __MODULE__, pid, receiver) do
    with true <- is_valid_subscriber(pid),
         true <- is_valid_topic(receiver),
      do: GenServer.call(server, {:unsubscribe, pid, [receiver]})
  end

  def subscribed?(server \\ __MODULE__, pid, receiver) do
    with true <- is_valid_subscriber(pid),
         true <- is_valid_topic(receiver),
      do: GenServer.call(server, {:is_subscribed, pid, [receiver]})
  end

  def start_link(args, opts \\ [name: __MODULE__]) do
    GenServer.start_link(__MODULE__, args, opts)
  end

  ## guards

  # Note that subscriber defined via registered atom is useless
  # as it will lead to loss of messages in case of its downtime.
  defp is_valid_subscriber(pid) when is_pid(pid), do: true
  defp is_valid_subscriber(_), do: {:error, :subscriber_must_be_pid}

  defp is_valid_topic(topic) when is_binary(topic), do: true
  defp is_valid_topic(_), do: {:error, :topic_must_be_a_string}

  ## callbacks

  @spec init([]) :: {:ok, state}
  def init([]) do
    {:ok, %{subs: BiMultiMap.new(),
            monitors: Map.new()}}
  end

  def handle_cast({:event, {_, :send, _, _, _, _, _} = event}, state) do
    do_notify(event, state[:subs])
    {:noreply, state}
  end

  def handle_cast({:event, _}, state) do
    {:noreply, state}
  end

  def handle_cast(msg, state) do
    {:stop, {:unhandled_cast, msg}, state}
  end


  def handle_call({:subscribe, pid, topics}, _from, state) do
    mons = state[:monitors]
    subs = state[:subs]
    mons = Map.put_new_lazy(mons, pid, fn -> Process.monitor(pid) end)
    subs = BiMultiMap.put(subs, topics, pid)
    {:reply, :ok, %{state | subs: subs, monitors: mons}}
  end

  def handle_call({:unsubscribe, pid, topics}, _from, state) do
    subs = state[:subs]
    subs = BiMultiMap.delete(subs, topics, pid)
    mons = case BiMultiMap.has_value?(subs, pid) do
             false ->
               state[:monitors]
             true ->
               Process.demonitor(state[:monitors][pid], [:flush]);
               Map.delete(state[:monitors], pid)
           end
    {:reply, :ok, %{state | subs: subs, monitors: mons}}
  end

  def handle_call({:is_subscribed, pid, topics}, _from, state) do
    {:reply, {:ok, BiMultiMap.member?(state[:subs], topics, pid)}, state}
  end

  def handle_call(msg, from, state) do
    {:stop, {:unhandled_call, from, msg}, state}
  end


  def handle_info({:DOWN, _monref, :process, pid, _reason},
                  state = %{subs: subs, monitors: mons}) do
    mons = Map.delete(mons, pid)
    subs = BiMultiMap.delete_value(subs, pid)
    {:noreply, %{state | subs: subs, monitors: mons}}
  end

  def handle_info(msg, state) do
    {:stop, {:unhandled_info, msg}, state}
  end

  ## internals

  defp do_notify(event, all_subs) do
    pids = subscribed(event_topics(event), all_subs)
    for pid <- pids, do: send(pid, {:committed, event})
  end

  defp event_topics({_, :send, _, _, _, dest, _}), do: [dest]

  # FIXME: this maps get should be done for set of all subsets
  defp subscribed(topics, subs) do
    BiMultiMap.get(subs, topics)
  end

end