defmodule HonteD.CryptoTest do
  use ExUnit.Case, async: true
  @moduledoc """
  A sanity and compatibility check of the crypto implementation.
  """

  alias HonteD.Crypto

  @moduletag :crypto

  test "sha3 library usage, address generation" do
    # test vectors below were generated using pyethereum's sha3 and privtoaddr
    priv = :keccakf1600.sha3_256(<<"11">>)
    py_priv = "7880aec93413f117ef14bd4e6d130875ab2c7d7d55a064fac3c2f7bd51516380"
    py_pub = "c4d178249d840f548b09ad8269e8a3165ce2c170"
    assert {:ok, ^priv} = Base.decode16(py_priv, case: :lower)
    {:ok, pub} = Crypto.generate_public_key(priv)
    {:ok, address} = Crypto.generate_address(pub)
    assert {:ok, ^address} = Base.decode16(py_pub, case: :lower)
  end

  test "digest sign, recover" do
    {:ok, priv} = Crypto.generate_private_key
    {:ok, pub} = Crypto.generate_public_key(priv)
    {:ok, address} = Crypto.generate_address(pub)
    msg = :crypto.strong_rand_bytes(32)
    sig = Crypto.signature_digest(msg, priv)
    assert {:ok, ^address} = Crypto.recover(msg, sig)
  end

  test "sign, verify" do
    {:ok, priv} = Crypto.generate_private_key
    {:ok, pub} = Crypto.generate_public_key(priv)
    {:ok, address} = Crypto.generate_address(pub)

    signature = Crypto.signature("message", priv)
    assert byte_size(signature) == 65
    assert {:ok, true} == Crypto.verify("message", signature, address)
    assert {:ok, false} == Crypto.verify("message2", signature, address)
  end

end
