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

defmodule HonteD.Transaction do
  @moduledoc """
  Used to manipulate the transaction structures

  # FIXME: sometime let's reduce this boilerplate code that now is spread accross here, tx_codec, api
  #        it's pretty consistent but drying this would be nice, hopefully without complicating too much
  """
  alias HonteD.Transaction.Validation

  defmodule CreateToken do
    @moduledoc false
    defstruct [:nonce, :issuer]

    @type t :: %CreateToken{
      nonce: HonteD.nonce,
      issuer: HonteD.address,
    }
  end

  defmodule Issue do
    @moduledoc false
    defstruct [:nonce, :asset, :amount, :dest, :issuer]

    @type t :: %Issue{
      nonce: HonteD.nonce,
      asset: HonteD.token,
      amount: pos_integer,
      dest: HonteD.address,
      issuer: HonteD.address,
    }
  end

  defmodule Unissue do
    @moduledoc false
    defstruct [:nonce, :asset, :amount, :issuer]

    @type t :: %Unissue{
            nonce: HonteD.nonce(),
            asset: HonteD.token(),
            amount: pos_integer,
            issuer: HonteD.address()
          }
  end

  defmodule Send do
    @moduledoc false
    defstruct [:nonce, :asset, :amount, :from, :to]

    @type t :: %Send{
      nonce: HonteD.nonce,
      asset: HonteD.token,
      amount: pos_integer,
      from: HonteD.address,
      to: HonteD.address,
    }
  end

  defmodule SignOff do
    @moduledoc false
    defstruct [:nonce, :height, :hash, :sender, :signoffer]

    @type t :: %SignOff{
      nonce: HonteD.nonce,
      height: pos_integer,
      hash: HonteD.block_hash,
      sender: HonteD.address,
      signoffer: HonteD.address,
    }
  end

  defmodule Allow do
    @moduledoc false
    defstruct [:nonce, :allower, :allowee, :privilege, :allow]

    @type t :: %Allow{
      nonce: HonteD.nonce,
      allower: HonteD.address,
      allowee: HonteD.address,
      privilege: HonteD.privilege,
      allow: boolean,
    }
  end

  defmodule EpochChange do
    @moduledoc false
    defstruct [:nonce, :sender, :epoch_number]

    @type t :: %EpochChange{
      nonce: HonteD.nonce,
      sender: HonteD.address,
      epoch_number: HonteD.epoch_number
    }
  end

  defmodule SignedTx do
    @moduledoc false
    defstruct [:raw_tx, :signature]

    @type t :: %SignedTx{
      raw_tx: HonteD.Transaction.t,
      signature: HonteD.signature,
    }
  end

  @type t :: CreateToken.t | Issue.t | Unissue.t | Send.t | SignOff.t | Allow.t | EpochChange.t | SignedTx.t

  @doc """
  Creates a CreateToken transaction, ensures state-less validity and encodes
  """
  @spec create_create_token([nonce: HonteD.nonce, issuer: HonteD.address]) ::
    {:ok, CreateToken.t} | {:error, atom}
  def create_create_token([nonce: nonce, issuer: issuer] = args)
  when is_integer(nonce) and
       is_binary(issuer) do
    create(CreateToken, args)
  end

  @doc """
  Creates a Issue transaction, ensures state-less validity and encodes
  """
  @spec create_issue([nonce: HonteD.nonce,
                      asset: HonteD.token,
                      amount: pos_integer,
                      dest: HonteD.address,
                      issuer: HonteD.address]) ::
    {:ok, Issue.t} | {:error, atom}
  def create_issue([nonce: nonce,
                    asset: asset,
                    amount: amount,
                    dest: dest,
                    issuer: issuer] = args)
  when is_integer(nonce) and
       is_binary(asset) and
       is_integer(amount) and
       amount > 0 and
       is_binary(issuer) and
       is_binary(dest) do
    create(Issue, args)
  end

  @doc """
  Creates a Unissue transaction, ensures state-less validity and encodes
  """
  @spec create_unissue(
          nonce: HonteD.nonce(),
          asset: HonteD.token(),
          amount: pos_integer,
          issuer: HonteD.address()
        ) :: {:ok, Unissue.t()} | {:error, atom}
  def create_unissue([nonce: nonce, asset: asset, amount: amount, issuer: issuer] = args)
      when is_integer(nonce) and is_binary(asset) and is_integer(amount) and amount > 0 and
             is_binary(issuer) do
    create(Unissue, args)
  end

  @doc """
  Creates a Send transaction, ensures state-less validity and encodes
  """
  @spec create_send([nonce: HonteD.nonce,
                     asset: HonteD.token,
                     amount: pos_integer,
                     from: HonteD.address,
                     to: HonteD.address]) ::
    {:ok, Send.t} | {:error, atom}
  def create_send([nonce: nonce,
                   asset: asset,
                   amount: amount,
                   from: from,
                   to: to] = args)
  when is_integer(nonce) and
       is_binary(asset) and
       is_integer(amount) and
       amount > 0 and
       is_binary(from) and
       is_binary(to) do
    create(Send, args)
  end

  @doc """
  Creates a SignOff transaction, ensures state-less validity and encodes
  """
  @spec create_sign_off([nonce: HonteD.nonce,
                         height: HonteD.block_height,
                         hash: HonteD.block_hash,
                         sender: HonteD.address,
                         signoffer: HonteD.address]) ::
    {:ok, SignOff.t} | {:error, atom}
  def create_sign_off([nonce: nonce,
                       height: height,
                       hash: hash,
                       sender: sender,
                       signoffer: signoffer] = args)
  when is_integer(nonce) and
       is_integer(height) and
       height > 0 and
       is_binary(hash) and
       is_binary(sender) and
       is_binary(signoffer) do
    create(SignOff, args)
  end
  def create_sign_off([nonce: _, height: _, hash: _, sender: sender] = args) do
    args
    |> Keyword.merge([signoffer: sender])
    |> create_sign_off
  end

  @doc """
  Creates an Allow transaction, ensures state-less validity and encodes
  """
  @spec create_allow([nonce: HonteD.nonce,
                      allower: HonteD.address,
                      allowee: HonteD.address,
                      privilege: HonteD.privilege,
                      allow: boolean]) ::
    {:ok, Allow.t} | {:error, atom}
  def create_allow([nonce: nonce,
                    allower: allower,
                    allowee: allowee,
                    privilege: privilege,
                    allow: allow] = args)
  when is_integer(nonce) and
       is_binary(allower) and
       is_binary(allowee) and
       is_binary(privilege) and
       is_boolean(allow) do
    create(Allow, args)
  end

  @doc """
  Creates an Epoch Change transaction, ensures state-less validity and encodes
  """
  @spec create_epoch_change([nonce: HonteD.nonce,
                            sender: HonteD.address,
                            epoch_number: HonteD.epoch_number]) ::
    {:ok, EpochChange.t} | {:error, atom}
  def create_epoch_change([nonce: nonce,
                    sender: sender,
                    epoch_number: epoch_number] = args)
  when is_integer(nonce) and
       is_binary(sender) and
       is_integer(epoch_number) and
       epoch_number > 0 do
    create(EpochChange, args)
  end

  defp create(type, args) do
    with tx <- struct(type, args),
         :ok <- Validation.valid?(tx),
         do: {:ok, tx}
  end

  @doc """
  Signs transaction, returns wire-encoded, hex-wrapped signed transaction.
  """
  @spec sign(binary, binary) :: binary
  def sign(tx, priv) when is_binary(tx) do
    wire_encoded = Base.decode16!(tx)
    {:ok, decoded} = HonteD.TxCodec.decode(wire_encoded)
    sig = HonteD.Crypto.signature(wire_encoded, priv)
    decoded
    |> with_signature(sig)
    |> HonteD.TxCodec.encode()
    |> Base.encode16()
  end

  def with_signature(tx, signature) do
    %SignedTx{raw_tx: tx, signature: signature}
  end
end
