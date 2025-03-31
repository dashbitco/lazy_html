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

    if tag in @void_tags do
      html = <<html::binary, "/>">>
      to_html(tree, escape, html)
    else
      html = <<html::binary, ">">>
      escape_children = tag not in @no_escape_tags
      html = to_html(children, escape_children, html)
      html = <<html::binary, "</", tag::binary, ">">>
      to_html(tree, escape, html)
    end
  end

  defp to_html([text | tree], escape, html) when is_binary(text) do
    html =
      if escape do
        append_escaped(text, html)
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
    html = append_escaped(value, html)
    html = <<html::binary, ~S/"/>>
    append_attrs(attrs, html)
  end

  # We scan the characters until we run into one that needs escaping.
  # Once we do, we take the whole text chunk up until that point and
  # we append it to the result. This is more efficient than appending
  # each untransformed character individually.
  #
  # Note that we apply the same escaping inside attribute values and
  # tag contents. We could escape less by making it contextual, but
  # we want to match the behaviour of Phoenix.HTML [1].
  #
  # [1]: https://github.com/phoenixframework/phoenix_html/blob/v4.2.1/lib/phoenix_html/engine.ex#L29-L35

  defp append_escaped(text, html) do
    append_escaped(text, text, 0, 0, html)
  end

  defp append_escaped(<<>>, text, 0 = _offset, _size, html) do
    # We scanned the whole text and there were no characters to escape,
    # so we append the whole text.
    <<html::binary, text::binary>>
  end

  defp append_escaped(<<>>, text, offset, size, html) do
    chunk = binary_part(text, offset, size)
    <<html::binary, chunk::binary>>
  end

  escapes = [
    {?&, "&amp;"},
    {?<, "&lt;"},
    {?>, "&gt;"},
    {?", "&quot;"},
    {?', "&#39;"}
  ]

  for {char, escaped} <- escapes do
    defp append_escaped(<<unquote(char), rest::binary>>, text, offset, size, html) do
      chunk = binary_part(text, offset, size)
      html = <<html::binary, chunk::binary, unquote(escaped)>>
      append_escaped(rest, text, offset + size + 1, 0, html)
    end
  end

  defp append_escaped(<<_char, rest::binary>>, text, offset, size, html) do
    append_escaped(rest, text, offset, size + 1, html)
  end
end
