defmodule HonteD.ABCI.HeaderEncoderTest do
  @moduledoc """
  Tests if Events are processed correctly, by the registered :honted_events app

  THis tests only the integration between ABCI and the Eventer GenServer, i.e. whether the events are emitted
  correctly. No HonteD.API.Events logic tested here
  """
  use ExUnitFixtures
  use ExUnit.Case, async: true

  describe "RLP encoder" do
    test "encodes block header without nonce and mix hash", %{} do
      assert [
        "48a3455ef3d7ec9de0c3c13b3a2c190a097374822d63e0288003ad8c6849ff90",
        "1dcc4de8dec75d7aab85b567b6ccd41ad312451b948a7413f0a142fd40d49347",
        "829bd824b016326a401d083b33d092293333a830",
        "270a116d155bbee24e661995770ae2e38624f3f94ff213650798a5ebeaa9206d",
        "411153e55666773e64b74c9e677c5ce33dcc0466e2c777e059c826ac5e62f415",
        "291443b5954139bef5b2ae6eb109373ff9495866060f481d038dc85d4ac016cd",
        "00000000040000020001000000420000801000000000000880800c00002000680000088000000000081002000400490208102440000000800040001000202100011040400800040100000009004010000020000000080801400100000309000040008020020020040040044000000850020002000024090000000111000800000000000000000008800000000000a1000000000000808084820008500400110002044000000000100000000050a0800400000900008084010002000000100001001000020004000800000000000000002000000500080004a01000000000200100100a2000000200000000400000808040201180000200201028029020000080",
        "575806034c3cd",
        "479c49",
        "68af35",
        "68679d",
        "5a29b4d7",
        "e4b883e5bda9e7a59ee4bb99e9b1bc"
      ]
      |> ExRLP.encode
      |> ExthCrypto.Hash.Keccak.kec ==
            <<13, 153, 241, 180, 244, 61, 211, 250, 181, 99, 104, 155, 128, 250,
              97, 104, 229, 117, 93, 92, 246, 42, 207, 190, 241, 223, 156, 198,
              123, 98, 184, 15>>
    end
  end
end
