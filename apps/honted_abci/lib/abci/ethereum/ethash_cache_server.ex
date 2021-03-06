#   Copyright 2018 OmiseGO Pte Ltd
#
#   Licensed under the Apache License, Version 2.0 (the "License");
#   you may not use this file except in compliance with the License.
#   You may obtain a copy of the License at
#
#       http://www.apache.org/licenses/LICENSE-2.0
#
#  Unless required by applicable law or agreed to in writing, software
#   distributed under the License is distributed on an "AS IS" BASIS,
#   WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
#   See the License for the specific language governing permissions and
#   limitations under the License.

defmodule HonteD.ABCI.Ethereum.EthashCacheServer do
  @moduledoc """
  Stores cache for ethash. Stores cache for a single epoch.
  Cache is used for generating DAG used in Ethereum proof of work (section J.3.2 in yellowpaper)
  TODO: Store cache for a few LRU epochs
  """
  use GenServer

  @epoch_length 30_000 # Epoch length in number of blocks. Cache is the same for each block in an epoch.
  @timeout 600_000

  alias HonteD.ABCI.Ethereum.EthashCache

  def init(args) do
     {:ok, args}
   end

  @doc """
  Starts cache store
  """
  def start(block_number) do
    epoch = epoch(block_number)
    cache = EthashCache.make_cache(block_number)
    GenServer.start_link(__MODULE__, %{epoch => cache}, [name: __MODULE__])
  end

  @doc """
  Gets cache for a given block number
  """
  def get_cache(block_number) do
    GenServer.call(__MODULE__, {:get, block_number}, @timeout)
  end

  def handle_call({:get, block_number}, _from, state) do
    epoch = epoch(block_number)
    case Map.fetch(state, epoch) do
      {:ok, cache} -> {:reply, {:ok, cache}, state}
      :error -> {:reply, :missing_cache, state}
    end
  end

  defp epoch(block_number), do: div(block_number, @epoch_length)

end
