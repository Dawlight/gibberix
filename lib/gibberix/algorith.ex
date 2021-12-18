defmodule WordWFC.Algorithm do
  alias WordWFC.Index
  #
  # Observe
  #

  def run_algorithm(length, pattern_index) do
    %Index{patterns: patterns, index_lookup: index_lookup, pattern_lookup: pattern_lookup} =
      pattern_index

    first =
      index_lookup
      |> Map.keys()
      |> Enum.to_list()
      # |> Enum.filter(fn pattern ->
      #   first_letter = pattern |> List.first() |> String.first()
      #   first_letter == String.upcase(first_letter)
      # end)
      |> Enum.random()
      |> IO.inspect(label: "RANDOM BIG STING")

    pattern_lookup |> IO.inspect(label: "PATTERN LOOKUP")
    first = index_lookup[first] |> IO.inspect(label: "WOW")

    pattern_output =
      for {_, i} <- Enum.with_index(0..length), into: %{} do
        case i do
          0 -> {0, MapSet.new([first])}
          _ -> {i, patterns}
        end
      end
      |> IO.inspect(label: "START")

    pattern_output = propagate(pattern_output, 0, pattern_index)

    observe(pattern_output, pattern_index)
    |> IO.inspect(label: "OK?")
    |> stitch_patterns(pattern_index)
    |> Enum.join(" ")
  end

  defp stitch_patterns(pattern_output, pattern_index) do
    %Index{pattern_lookup: pattern_lookup} = pattern_index

    pattern_output =
      pattern_output
      |> Enum.sort_by(fn {i, _} -> i end, :asc)

    {words, _} =
      for {_index, patterns} <- pattern_output,
          reduce: {[], nil} do
        {words, left_pattern} ->
          pattern = patterns |> MapSet.to_list() |> List.first()

          case left_pattern do
            # First pattern
            nil ->
              {pattern_lookup[pattern], pattern}

            _ ->
              actual_pattern = pattern_lookup[pattern]

              overlap_size = Index.get_overlap_size(pattern_index, pattern, left_pattern, :left)

              slice = Enum.slice(actual_pattern, overlap_size..-1)
              {words ++ slice, pattern}
          end
      end

    words
  end

  def observe(pattern_output, pattern_index) do
    case find_lowest_entropy(pattern_output, pattern_index) do
      {output_index, available_patterns} ->
        output_index |> IO.inspect(label: "SELECTED INDEX")
        pattern = choose_random_pattern(available_patterns, pattern_index)

        pattern_output = Map.put(pattern_output, output_index, MapSet.new([pattern]))
        pattern_output = propagate(pattern_output, output_index, pattern_index)

        observe(pattern_output, pattern_index)

      # TODO: SELECTED WEIGHTED RANDOM
      _ ->
        pattern_output
    end
  end

  def propagate(pattern_output, output_index, pattern_index) do
    original_output = pattern_output

    pattern_output
    |> Enum.sort_by(fn {index, _} -> index end, :asc)

    # IO.getn("Continue? ")
    subject_patterns = pattern_output[output_index] |> MapSet.to_list()

    neighbours = get_neighbours(pattern_output, output_index)

    allowed_patterns_by_pos =
      for pos <- [:left, :right], pattern <- subject_patterns, reduce: %{} do
        legal_patterns_by_pos ->
          patterns = Index.get_patterns(pattern_index, pattern, pos)

          Map.update(legal_patterns_by_pos, pos, patterns, fn existing_patterns ->
            MapSet.union(existing_patterns, patterns)
          end)
      end

    pattern_output =
      for {pos, {index, current_neighbour_patterns}} <- neighbours, reduce: pattern_output do
        pattern_output ->
          allowed_neighbour_patterns =
            MapSet.intersection(current_neighbour_patterns, allowed_patterns_by_pos[pos])

          Map.put(pattern_output, index, allowed_neighbour_patterns)
      end

    case original_output == pattern_output do
      true ->
        pattern_output

      false ->
        for {_, {output_index, _}} <- neighbours, reduce: pattern_output do
          pattern_output ->
            propagate(pattern_output, output_index, pattern_index)
        end
    end
  end

  defp get_neighbours(pattern_output, output_index) do
    max_index = Enum.max(Map.keys(pattern_output))

    [{:left, output_index - 1}, {:right, output_index + 1}]
    |> Enum.filter(fn {_, index} -> index >= 0 and index <= max_index end)
    |> Enum.map(fn {position, output_index} ->
      {position, {output_index, pattern_output[output_index]}}
    end)
    |> Enum.filter(fn {_, {_, patterns}} -> MapSet.size(patterns) > 1 end)
  end

  def choose_random_pattern(available_patterns, pattern_index) do
    %Index{frequencies: frequencies} = pattern_index
    available_frequencies = for pattern <- available_patterns, do: {pattern, frequencies[pattern]}
    select_item(available_frequencies)
  end

  def select_item(frequencies) do
    total_weight = Enum.map(frequencies, &elem(&1, 1)) |> Enum.sum()
    acc = :rand.uniform(total_weight)
    select_item(frequencies, acc)
  end

  defp select_item([{item, weight} | _], acc) when acc <= weight, do: item
  defp select_item([{_, weight} | tail], acc), do: select_item(tail, acc - weight)

  def find_lowest_entropy(pattern_output, pattern_index) do
    pattern_output
    |> Enum.filter(fn entry -> get_output_entry_entropy(entry, pattern_index) > 0 end)
    |> Enum.min_by(
      fn entry ->
        get_output_entry_entropy(entry, pattern_index)
      end,
      fn ->
        :finished
      end
    )
  end

  def get_output_entry_entropy({_index, available_patterns}, pattern_index) do
    %Index{frequencies: frequencies} = pattern_index

    case MapSet.size(available_patterns) do
      1 ->
        0

      size when size > 1 ->
        total_weight =
          available_patterns
          |> Enum.map(fn pattern -> frequencies[pattern] end)
          |> Enum.sum()

        weight_log_sum =
          available_patterns
          |> Enum.map(fn pattern ->
            weight = frequencies[pattern]

            weight * :math.log2(weight)
          end)
          |> Enum.sum()

        :math.log2(total_weight) - weight_log_sum / total_weight + (:rand.uniform() - 0.5) / 10
    end
  end
end
