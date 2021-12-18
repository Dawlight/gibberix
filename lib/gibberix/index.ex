defmodule WordWFC.Index do
  defstruct patterns: nil, index: nil, frequencies: nil, pattern_lookup: nil, index_lookup: nil

  def new(overlap \\ nil, pattern_size \\ 2) do
    overlap =
      case overlap do
        nil -> 1..pattern_size
        _ -> overlap
      end

    words = parse_text()
    patterns = generate_patterns(words, pattern_size)

    frequencies = Enum.frequencies(patterns)

    pattern_lookup =
      for {{pattern, _}, index} <- Enum.with_index(frequencies), into: %{} do
        {index, pattern}
      end

    index_lookup =
      for {index, pattern} <- pattern_lookup, into: %{} do
        {pattern, index}
      end

    frequencies =
      frequencies
      |> Enum.map(fn {pattern, frequency} -> {index_lookup[pattern], frequency} end)
      |> Map.new()

    index =
      Task.async_stream(pattern_lookup, fn entry ->
        generate_index_entry(entry, pattern_lookup, overlap)
      end)
      |> Enum.reduce([], fn {:ok, result}, list -> [result | list] end)
      |> Map.new()

    %__MODULE__{
      patterns: MapSet.new(Map.keys(frequencies)),
      index: index,
      frequencies: frequencies,
      pattern_lookup: pattern_lookup |> Enum.sort_by(fn {i, _} -> i end),
      index_lookup: index_lookup
    }
  end

  def get_patterns(%__MODULE__{index: pattern_index}, index, position) do
    thing = (pattern_index[index] || %{})[position] || %{}

    for {_overlap_size, patterns} <- thing, reduce: MapSet.new() do
      all_patterns -> MapSet.union(all_patterns, patterns)
    end
  end

  def get_overlap_size(%__MODULE__{index: pattern_index}, index_a, index_b, position) do
    thing = (pattern_index[index_a] || %{})[position] || %{}

    entry =
      Enum.find(thing, fn {_overlap_size, patterns} -> MapSet.member?(patterns, index_b) end)

    case entry do
      nil -> :this_should_never_happen
      {overlap_size, _} -> overlap_size
    end
  end

  # @spec generate_index_entry({any, any}, any, any) :: {any, any}
  # defp generate_index_entry({pattern_index, pattern}, pattern_lookup, min_overlap) do
  #   entry =
  #     for {op_index, other_pattern} <- pattern_lookup, reduce: %{} do
  #       index_entry ->
  #         overlaps = get_overlaps(pattern, other_pattern, min_overlap)

  #         for {direction, size} <- overlaps, reduce: index_entry do
  #           index_entry ->
  #             overlap = {size, op_index}

  #             index_entry
  #             |> Map.update(direction, MapSet.new([overlap]), fn thing ->
  #               MapSet.put(thing, overlap)
  #             end)
  #         end
  #     end

  #   {pattern_index, entry}
  # end

  @spec generate_index_entry({any, any}, any, any) :: {any, any}
  defp generate_index_entry({pattern_index, pattern}, pattern_lookup, overlap) do
    entry =
      for {op_index, other_pattern} <- pattern_lookup, reduce: %{} do
        index_entry ->
          overlaps = get_overlaps(pattern, other_pattern, overlap)

          for {direction, size} <- overlaps, reduce: index_entry do
            index_entry ->
              index_entry
              |> Map.update(direction, %{size => MapSet.new([op_index])}, fn size_map ->
                Map.update(size_map, size, MapSet.new([op_index]), fn patterns ->
                  MapSet.put(patterns, op_index)
                end)
              end)
          end
      end

    {pattern_index, entry}
  end

  defp get_overlaps(pattern_1, pattern_2, overlap) do
    overlap_range = overlap
    overlap_types = [{:right, [pattern_1, pattern_2]}, {:left, [pattern_2, pattern_1]}]

    for {direction, patterns} <- overlap_types, overlap_size <- overlap_range do
      [pattern_a, pattern_b] = patterns
      overlap_a = Enum.slice(pattern_a, -overlap_size, overlap_size)
      overlap_b = Enum.slice(pattern_b, 0, overlap_size)

      case overlap_a == overlap_b do
        true -> {direction, overlap_size}
        false -> nil
      end
    end
    |> List.flatten()
    |> Enum.filter(&(!is_nil(&1)))
  end

  defp parse_text() do
    File.read!("lib/input")
    |> String.split(["\n", " "], trim: true)
  end

  defp generate_patterns(words, pattern_size) do
    text_beginning = Enum.slice(words, 0..0)
    text_end = Enum.slice(words, -1..-1)

    words = words ++ text_beginning
    words = text_end ++ words

    Enum.chunk_every(words, pattern_size, 1, :discard)
  end
end
