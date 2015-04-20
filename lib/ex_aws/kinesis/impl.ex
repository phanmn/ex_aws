defmodule ExAws.Kinesis.Impl do
  use ExAws.Actions
  import ExAws.Kinesis.Request
  require Logger

  @namespace "Kinesis_20131202"
  @actions [
    add_tags_to_stream:      :post,
    create_stream:           :post,
    delete_stream:           :post,
    describe_stream:         :post,
    get_records:             :post,
    get_shard_iterator:      :post,
    list_streams:            :post,
    list_tags_for_stream:    :post,
    merge_shards:            :post,
    put_record:              :post,
    put_records:             :post,
    remove_tags_from_stream: :post,
    split_shard:             :post]

  @moduledoc "See ExAws.Kinesis.Client for documentation"

  ## Streams
  ######################

  def list_streams(client) do
    client.request(%{}, :list_streams)
  end

  def describe_stream(client, name, opts) do
    %{StreamName: name}
    |> Map.merge(opts)
    |> client.request(:describe_stream)
  end

  def create_stream(client, name, shard_count) do
    %{
      ShardCount: shard_count,
      StreamName: name
    }
    |> client.request(:create_stream)
  end

  def delete_stream(client, name) do
    %{StreamName: name}
    |> client.request(:delete_stream)
  end

  ## Records
  ######################

  def get_records(client, shard_iterator, opts) do
    %{ShardIterator: shard_iterator}
    |> Map.merge(opts)
    |> client.request(:get_records)
    |> do_get_records
  end

  defp do_get_records({:ok, %{"Records" => records} = results}) do
    {:ok, Map.put(results, "Records", decode_records(records))}
  end
  defp do_get_records(result), do: result

  defp decode_records(records) do
    records
    |> Enum.reduce([], fn(%{"Data" => data} = record, acc) ->
      case data |> Base.decode64 do
        {:ok, decoded} -> [%{record | "Data" => decoded} | acc]
        :error ->
          Logger.error("Could not decode data from: #{inspect record}")
          acc
      end
    end)
    |> Enum.reverse
  end

  def put_record(client, stream_name, partition_key, data, opts) when is_list(data) do
    put_record(client, stream_name, partition_key, IO.iodata_to_binary(data), opts)
  end

  def put_record(client, stream_name, partition_key, data, opts) when is_binary(data) do
    %{
      Data: data |> Base.encode64,
      PartitionKey: partition_key,
      StreamName: stream_name
    }
    |> Map.merge(opts)
    |> client.request(:put_record)
  end

  def put_records(client, stream_name, records) when is_list(records) do
    %{
      Records: records |> Enum.map(&format_record/1),
      StreamName: stream_name
    }
    |> client.request(:put_records)
  end

  defp format_record(%{data: data, partition_key: partition_key} = record) do
    formatted = %{Data: data |> Base.encode64, PartitionKey: partition_key}
    case record do
      %{explicit_hash_key: hash_key} -> formatted |> Map.put(:ExplicitHashKey, hash_key)
      _ -> formatted
    end
  end

  ## Shards
  ######################

  def get_shard_iterator(client, name, shard_id, shard_iterator_type, opts) do
    %{
      StreamName: name,
      ShardId: shard_id,
      ShardIteratorType: shard_iterator_type
    } |> Map.merge(opts)
    |> client.request(:get_shard_iterator)
  end

  def merge_shards(client, name, adjacent_shard, shard) do
    %{
      StreamName: name,
      AdjacentShardToMerge: adjacent_shard,
      ShardToMerge: shard
    }
    |> client.request(:merge_shards)
  end

  def split_shard(client, name, shard, new_starting_hash_key) do
    %{
      StreamName: name,
      ShardToSplit: shard,
      NewStartingHashKey: new_starting_hash_key
    }
    |> client.request(:split_shard)
  end

  ## Tags
  ######################

  def add_tags_to_stream(client, name, tags) do
    %{StreamName: name, Tags: tags}
    |> client.request(:add_tags_to_stream)
  end

  def list_tags_for_stream(client, name, opts) do
    %{StreamName: name}
    |> Map.merge(opts)
    |> client.request(:list_tags_for_stream)
  end

  def remove_tags_from_stream(client, name, tag_keys) when is_list(tag_keys) do
    %{StreamName: name, TagKeys: tag_keys}
    |> client.request(:remove_tags_from_stream)
  end
end
