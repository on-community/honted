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

defmodule HonteD.API.Tools do
  @moduledoc """
  Shared functionality used by HonteD.API _not to be auto-exposed_
  """

  alias HonteD.API.{Tendermint, Transaction}

  @doc """
  Uses a Tendermint.RPC `client` to get the current nonce for the `from` address. Returns raw Tendermint response
  in case of any failure
  """
  def get_nonce(client, from) do
    get_and_decode(client, "/nonces/#{from}")
  end

  @doc """
  Uses a Tendermint.RPC `client` to the issuer for a token
  """
  def get_issuer(client, token) do
    get_and_decode(client, "/tokens/#{token}/issuer")
  end

  @doc """
  Uses a Tendermint.RPC `client` to query anything from the abci and decode to map
  """
  def get_and_decode(client, key) do
    rpc_response = Tendermint.RPC.abci_query(client, "", key)
    with {:ok, %{"response" => %{"code" => 0, "value" => encoded}}} <- rpc_response,
         do: Poison.decode(encoded)
  end

  @doc """
  Enriches the standards Tendermint tx information with a HonteD-specific status flag
    :failed, :committed, :finalized, :committed_unknown
  """
  def append_status(tx_info, client) do
    tx_info
    |> Map.put(:status, get_tx_status(tx_info, client))
  end

  def encode_tx(tx_info) do
    tx_info
    |> Map.update!("tx", &(Base.encode16(&1)))
  end

  defp get_tx_status(tx_info, client) do
    with :committed <- get_tx_tendermint_status(tx_info),
         do: tx_info["tx"]
             |> HonteD.TxCodec.decode!
             |> get_sign_off_status_for_committed(client, tx_info["height"])
  end

  def get_block_hash(height) do
    get_block_hash(height, Tendermint.RPC, Tendermint.RPC.client())
  end

  def get_block_hash(height, tendermint_module, client) do
    case tendermint_module.block(client, height) do
      {:ok, block} -> {:ok, block_hash(block)}
      nil -> false
    end
  end

  defp get_tx_tendermint_status(tx_info) do
    case tx_info do
      %{"height" => _, "tx_result" => %{"code" => 0, "data" => "", "log" => ""}} -> :committed
      %{"tx_result" => _} -> :failed # successful look up of failed tx
    end
  end

  defp get_sign_off_status_for_committed(%HonteD.Transaction.SignedTx{raw_tx: %HonteD.Transaction.Send{} = tx},
                                         client,
                                         tx_height) do
    {:ok, issuer} = get_issuer(client, tx.asset)

    case get_and_decode(client, "/sign_offs/#{issuer}") do
      {:ok, %{"response" => %{"code" => 1}}} ->
        # indicates the sign off hasn't been found
        :committed
      {:ok, %{"height" => sign_off_height, "hash" => sign_off_hash}} ->
        {:ok, real_blockhash} = get_block_hash(sign_off_height, Tendermint.RPC, client)
        Transaction.Finality.status(tx_height, sign_off_height, sign_off_hash, real_blockhash)
    end
  end
  defp get_sign_off_status_for_committed(_, _, _), do: :committed

  # private

  defp block_hash(block) do
    block["block_meta"]["block_id"]["hash"]
  end
end
