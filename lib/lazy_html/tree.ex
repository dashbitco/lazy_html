defmodule LazyHTML.Tree do
  @moduledoc """
  This module deals with HTML documents represented as an Elixir tree
  data structure.
  """

  @type t :: list(html_node())
  @type html_node :: html_tag() | html_text() | html_comment()
  @type html_tag :: {String.t(), list(html_attribute()), list(html_node())}
  @type html_attribute :: {String.t(), String.t()}
  @type html_text :: String.t()
  @type html_comment :: {:comment, String.t()}

  @doc """
  Serializes Elixir tree data structure as an HTML string.

  ## Examples

      iex> tree = [
      ...>   {"html", [], [{"head", [], [{"title", [], ["Page"]}]}, {"body", [], ["Hello world"]}]}
      ...> ]
      iex> LazyHTML.Tree.to_html(tree)
      "<html><head><title>Page</title></head><body>Hello world</body></html>"

      iex> tree = [
      ...>   {"div", [], []},
      ...>   {:comment, " Link "},
      ...>   {"a", [{"href", "https://elixir-lang.org"}], ["Elixir"]}
      ...> ]
      iex> LazyHTML.Tree.to_html(tree)
      ~S|<div></div><!-- Link --><a href="https://elixir-lang.org">Elixir</a>|

  """
  @spec to_html(t()) :: String.t()
  def to_html(tree) when is_list(tree) do
    # We build the html by continuously appending to a result binary.
    # Appending to a binary is optimised by the runtime, so this
    # approach is memory efficient.
    #
    # For HTML specifics, refer to the standard [1].
    #
    # [1]: https://html.spec.whatwg.org/multipage/parsing.html#serialising-html-fragments

    to_html(tree, true, <<>>)
  end

  @void_tags ~w(
    area base br col embed hr img input link meta source track wbr
    basefont bgsound frame keygen param
  )

  @no_escape_tags ~w(style script xmp iframe noembed noframes plaintext)

  defp to_html([], _escape, html), do: html

  defp to_html([{tag, attrs, children} | tree], escape, html) do
    html = <<html::binary, "<", tag::binary>>
    html = append_attrs(attrs, html)
    html = <<html::binary, ">">>

    if tag in @void_tags do
      to_html(tree, escape, html)
    else
      escape_children = tag not in @no_escape_tags
      html = to_html(children, escape_children, html)
      html = <<html::binary, "</", tag::binary, ">">>
      to_html(tree, escape, html)
    end
  end

  defp to_html([text | tree], escape, html) when is_binary(text) do
    html =
      if escape do
        append_escaped(text, :content, html)
      else
        <<html::binary, text::binary>>
      end

    to_html(tree, escape, html)
  end

  defp to_html([{:comment, content} | tree], escape, html) do
    to_html(tree, escape, <<html::binary, "<!--", content::binary, "-->">>)
  end

  defp append_attrs([], html), do: html

  defp append_attrs([{name, value} | attrs], html) do
    html = <<html::binary, " ", name::binary, ~S/="/>>
    html = append_escaped(value, :attribute, html)
    html = <<html::binary, ~S/"/>>
    append_attrs(attrs, html)
  end

  # We scan the characters until we run into one that needs escaping.
  # Once we do, we take the whole text chunk up until that point and
  # we append it to the result. This is more efficient than appending
  # each untransformed character individually.

  defp append_escaped(text, mode, html) when mode in [:content, :attribute] do
    append_escaped(text, text, 0, 0, mode, html)
  end

  defp append_escaped(<<>>, text, 0 = _offset, _size, _mode, html) do
    # We scanned the whole text and there were no characters to escape,
    # so we append the whole text.
    <<html::binary, text::binary>>
  end

  defp append_escaped(<<>>, text, offset, size, _mode, html) do
    chunk = binary_part(text, offset, size)
    <<html::binary, chunk::binary>>
  end

  defp append_escaped(<<?&, rest::binary>>, text, offset, size, mode, html) do
    chunk = binary_part(text, offset, size)
    html = <<html::binary, chunk::binary, "&amp;">>
    append_escaped(rest, text, offset + size + 1, 0, mode, html)
  end

  defp append_escaped(<<194, rest::binary>>, text, offset, size, mode, html) do
    # We match the second byte separately, so that all main clauses
    # match only a single byte, which is faster.
    case rest do
      <<160, rest::binary>> ->
        chunk = binary_part(text, offset, size)
        html = <<html::binary, chunk::binary, "&nbsp;">>
        append_escaped(rest, text, offset + size + 2, 0, mode, html)

      _other ->
        append_escaped(rest, text, offset, size + 1, mode, html)
    end
  end

  defp append_escaped(<<?<, rest::binary>>, text, offset, size, :content, html) do
    chunk = binary_part(text, offset, size)
    html = <<html::binary, chunk::binary, "&lt;">>
    append_escaped(rest, text, offset + size + 1, 0, :content, html)
  end

  defp append_escaped(<<?>, rest::binary>>, text, offset, size, :content, html) do
    chunk = binary_part(text, offset, size)
    html = <<html::binary, chunk::binary, "&gt;">>
    append_escaped(rest, text, offset + size + 1, 0, :content, html)
  end

  defp append_escaped(<<?", rest::binary>>, text, offset, size, :attribute, html) do
    chunk = binary_part(text, offset, size)
    html = <<html::binary, chunk::binary, "&quot;">>
    append_escaped(rest, text, offset + size + 1, 0, :attribute, html)
  end

  defp append_escaped(<<_char, rest::binary>>, text, offset, size, mode, html) do
    append_escaped(rest, text, offset, size + 1, mode, html)
  end
end
