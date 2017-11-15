defmodule HonteD.Events.Eventer do
  @moduledoc """
  Handles stream of send events from HonteD.ABCI and forwards them to subscribers.

  This implementation is as simple as it can be.

  Generic process registries are a bad fit since we want to hyper-optimize for
  particular use case (bloom filters etc).
  """
  use GenServer
  require Logger

  @typep event :: HonteD.Transaction.t
  @typep topic :: HonteD.address
  @typep height :: pos_integer
  @typep queue :: Qex.t({height, event})
  @typep subs :: BiMultiMap.t([topic], pid)
  @typep token :: HonteD.token
  @typep state :: %{
    :subs => subs,
    :monitors => %{pid => reference},
    # Events that are waiting to be finalized.
    # Assumes one source of finality for each of the tokens.
    # Works ONLY for Send transactions
    # TODO: pull those events from Tendermint
    :committed => %{optional(token) => queue},
    :height => height,
  }

  def start_link(args, opts) do
    GenServer.start_link(__MODULE__, args, opts)
  end

  def child_spec(_) do
    %{id: __MODULE__,
      start: {__MODULE__, :start_link, [[], [name: __MODULE__]]},
      type: :worker,
      restart: :permanent,
    }
  end

  ## callbacks

  @spec init([]) :: {:ok, state}
  def init([]) do
    {:ok, %{subs: BiMultiMap.new(),
            committed: Map.new(),
            monitors: Map.new(),
            height: 1
           }}
  end

  def handle_cast({:event, %HonteD.Transaction.Send{} = event, _}, state) do
    state = insert_committed(event, state)
    do_notify(:committed, event, state[:subs])
    {:noreply, state}
  end

  def handle_cast({:event, %HonteD.Transaction.SignOff{} = event, tokens}, state) when is_list(tokens) do
    state = finalize_events(tokens, event.height, state)
    {:noreply, state}
  end

  def handle_cast({:event, %HonteD.Events.NewBlock{} = event, _}, state) do
    {:noreply, %{state | height: event.height}}
  end

  def handle_cast({:event, event, context}, state) do
    _ = Logger.warn("Warning: unhandled event #{inspect event} with context #{inspect context}")
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

  defp finalize_events(tokens, height, state) do
    notify_token = fn(token, acc) ->
      {:ok, events, acc} = pop_committed(token, height, acc)
      for event <- events, do: do_notify(:finalized, event, acc[:subs])
      acc
    end
    Enum.reduce(tokens, state, notify_token)
  end

  defp insert_committed(event, state = %{committed: committed, height: height}) do
    token = get_token(event)
    insert = fn(queue) -> Qex.push(queue, {height, event}) end
    committed = Map.update(committed, token, Qex.new([{height, event}]), insert)
    %{state | :committed => committed}
  end

  defp pop_committed(token, signed_off_height, state = %{committed: committed}) do
    case Map.get(committed, token, nil) do
      nil ->
        {:ok, [], state}
      queue ->
        is_older = fn({h, _event}) -> h <= signed_off_height end
        {finalized_tuples, rest} = Enum.split_while(queue, is_older)
        {_, finalized} = Enum.unzip(finalized_tuples)
        committed = Map.put(committed, token, Qex.new(rest))
        {:ok, finalized, %{state | committed: committed}}
    end
  end

  defp get_token(%HonteD.Transaction.Send{} = event) do
    event.asset
  end

  defp do_notify(event_type, event_content, all_subs) do
    pids = subscribed(event_topics_for(event_content), all_subs)
    _ = Logger.info("do_notify: #{inspect event_type}, #{inspect event_content}, pid: #{inspect pids}")
    prepared_message = message(event_type, event_content)
    for pid <- pids, do: send(pid, {:event, prepared_message})
    :ok
  end

  defp message(event_type, %HonteD.Transaction.Send{} = event_content)
  when event_type in [:committed, :finalized]
    do
    # FIXME: consider mappifying the tx: transaction: %{type: :send, payload: Map.from_struct(event_content)}
    %{source: :filter, type: event_type, transaction: event_content}
  end

  defp event_topics_for(%HonteD.Transaction.Send{to: dest}), do: [dest]

  # FIXME: this maps get should be done for set of all subsets
  defp subscribed(topics, subs) do
    BiMultiMap.get(subs, topics)
  end

end
