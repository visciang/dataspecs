defmodule Test.DataSpecs.Cast.Extra do
  use ExUnit.Case, async: true

  @types_module Test.DataSpecs.SampleType

  describe "extra cast" do
    test "isodatetime" do
      datetime = ~U[2021-07-14 20:22:49.653077Z]
      iso_datetime_string = DateTime.to_iso8601(datetime)

      assert {:ok, datetime} == DataSpecs.cast(iso_datetime_string, {@types_module, :t_datetime})
    end

    test "isodatetime error" do
      value = "not a datetime"

      assert {:error, ["can't convert \"#{value}\" to a DateTime.t/0 (:invalid_format)"]} ==
               DataSpecs.cast(value, {@types_module, :t_datetime})

      value = 123

      assert {:error, ["can't convert #{value} to a DateTime.t/0"]} ==
               DataSpecs.cast(value, {@types_module, :t_datetime})
    end

    test "isodate" do
      date = ~D[2021-07-14]
      iso_date_string = Date.to_iso8601(date)

      assert {:ok, date} == DataSpecs.cast(iso_date_string, {@types_module, :t_date})
    end

    test "isodate error" do
      value = "not a date"

      assert {:error, ["can't convert \"#{value}\" to a Date.t/0 (:invalid_format)"]} ==
               DataSpecs.cast(value, {@types_module, :t_date})

      value = 123

      assert {:error, ["can't convert #{value} to a Date.t/0"]} ==
               DataSpecs.cast(value, {@types_module, :t_date})
    end

    test "mapset" do
      assert {:ok, MapSet.new(1..3)} == DataSpecs.cast(1..3, {@types_module, :t_mapset})

      assert {:ok, MapSet.new(["1", :a, 1])} ==
               DataSpecs.cast(["1", :a, 1], {@types_module, :t_mapset_1})
    end

    test "mapset error" do
      value = 123

      assert {:error, ["can't convert #{value} to a MapSet.t/1, value not enumerable"]} ==
               DataSpecs.cast(value, {@types_module, :t_mapset})

      value = [%{}]

      assert {:error,
              [
                "can't convert #{inspect(value)} to a MapSet.t/1",
                ["can't convert #{inspect(value)} to a list, bad item at index=0", ["can't convert %{} to an integer"]]
              ]} ==
               DataSpecs.cast(value, {@types_module, :t_mapset})
    end
  end
end
