defmodule DriftMQTest do
  use ExUnit.Case
  doctest DriftMQ

  test "greets the world" do
    assert DriftMQ.hello() == :world
  end
end
