defmodule LazyHTMLTest do
  use ExUnit.Case

  doctest LazyHTML

  describe "from_document/1" do
    test "empty" do
      lazy_html = LazyHTML.from_document("")

      assert inspect(lazy_html) == """
             #LazyHTML<
               1 node
               #1
               <html><head></head><body></body></html>
             >\
             """
    end

    test "adds <html>, <head> and <body>, if missing" do
      lazy_html = LazyHTML.from_document("Hello world")

      assert inspect(lazy_html) == """
             #LazyHTML<
               1 node
               #1
               <html><head></head><body>Hello world</body></html>
             >\
             """

      lazy_html = LazyHTML.from_document("<body>Hello world</body>")

      assert inspect(lazy_html) == """
             #LazyHTML<
               1 node
               #1
               <html><head></head><body>Hello world</body></html>
             >\
             """
    end

    test "comments at the root" do
      lazy_html =
        LazyHTML.from_document("""
        <!-- Hello -->
        <html><head>
          <title>Page</title>
        </head>
        <body>
          <div id="root">
            Hello world
          </div>
        </body></html><!-- world -->\
        """)

      assert inspect(lazy_html) == """
             #LazyHTML<
               3 nodes
               #1
               <!-- Hello -->
               #2
               <html><head>
                 <title>Page</title>
               </head>
               <body>
                 <div id="root">
                   Hello world
                 </div>
               </body></html>
               #3
               <!-- world -->
             >\
             """
    end
  end

  describe "from_fragment/1" do
    test "empty" do
      lazy_html = LazyHTML.from_fragment("")

      assert inspect(lazy_html) == """
             #LazyHTML<
               0 nodes
             >\
             """
    end

    test "multiple root nodes" do
      lazy_html = LazyHTML.from_fragment("<span>Hello</span> <span>world</span>")

      assert inspect(lazy_html) == """
             #LazyHTML<
               3 nodes
               #1
               <span>Hello</span>
               #2
               [whitespace]
               #3
               <span>world</span>
             >\
             """
    end
  end

  describe "to_html/1" do
    test "serializes lazy html as a valid html representation" do
      html = """
      <!-- Top comment --><html><head>
        <meta charset="UTF-8"/>
        <meta name="viewport" content="width=device-width, initial-scale=1.0"/>
        <title>Page</title>
      </head>
      <body>
        <div id="root" class="layout">
          Hello world
          <!-- Inner comment -->
          <p>
            <span data-id="1">Hello</span>
            <span data-id="2">world</span>
          </p>
          <img src="/assets/image.jpeg" alt="image"/>
          <form>
            <input class="input" value="" name="name"/>
          </form>
          <script>
            console.log(1 && 2);
          </script>
          <style>
            .parent > .child {
              &:hover {
                display: none;
              }
            }
          </style>
          &amp; &lt; &gt; &quot; &#39; € 🔥 🐈
          <div class="&amp; &lt; &gt; &quot; &#39; € 🔥 🐈"></div>
        </div>
      </body></html>\
      """

      lazy_html = LazyHTML.from_document(html)

      assert LazyHTML.to_html(lazy_html) == html
    end

    test "with :skip_whitespace_nodes" do
      lazy_html =
        LazyHTML.from_fragment("""
          <p>
          <span>  Hello  </span>
          <span>  world  </span>
        </p>
        """)

      assert LazyHTML.to_html(lazy_html, skip_whitespace_nodes: true) ==
               "<p><span>  Hello  </span><span>  world  </span></p>"
    end

    test "includes template children" do
      lazy_html =
        LazyHTML.from_fragment("<template><div>First</div><div>Second</div></template>")

      assert LazyHTML.to_html(lazy_html) ==
               "<template><div>First</div><div>Second</div></template>"
    end
  end

  describe "to_tree/2" do
    test "keeps original attribute order by default" do
      lazy_html =
        LazyHTML.from_fragment(~S|<div id="root" data-b="b" data-a="a">Hello world</div>|)

      assert LazyHTML.to_tree(lazy_html) == [
               {"div", [{"id", "root"}, {"data-b", "b"}, {"data-a", "a"}], ["Hello world"]}
             ]
    end

    test "sorts attributes when :sort_attributes is specified" do
      lazy_html =
        LazyHTML.from_fragment(~S|<div id="root" data-b="b" data-a="a">Hello world</div>|)

      assert LazyHTML.to_tree(lazy_html, sort_attributes: true) == [
               {"div", [{"data-a", "a"}, {"data-b", "b"}, {"id", "root"}], ["Hello world"]}
             ]
    end

    test "includes template children" do
      lazy_html =
        LazyHTML.from_fragment("<template><div>First</div><div>Second</div></template>")

      assert LazyHTML.to_tree(lazy_html) == [
               {"template", [], [{"div", [], ["First"]}, {"div", [], ["Second"]}]}
             ]
    end

    test "skip_whitespace_nodes: true" do
      lazy_html =
        LazyHTML.from_fragment("""
          <p>
          <span>  Hello  </span>
          <span>  world  </span>
        </p>
        """)

      assert LazyHTML.to_tree(lazy_html, skip_whitespace_nodes: true) ==
               [{"p", [], [{"span", [], ["  Hello  "]}, {"span", [], ["  world  "]}]}]
    end
  end

  describe "from_tree/2" do
    test "includes template children" do
      lazy_html =
        LazyHTML.from_tree([
          {"template", [], [{"div", [], ["First"]}, {"div", [], ["Second"]}]}
        ])

      assert inspect(lazy_html) == """
             #LazyHTML<
               1 node
               #1
               <template><div>First</div><div>Second</div></template>
             >\
             """
    end

    test "respects attribute name casing within svg" do
      lazy_html =
        LazyHTML.from_tree([
          {"svg", [{"viewBox", "0 0 100 100"}],
           [
             {"defs", [], [{"marker", [{"markerWidth", "10"}, {"markerHeight", "7"}], []}]}
           ]}
        ])

      assert inspect(lazy_html) == """
             #LazyHTML<
               1 node
               #1
               <svg viewBox="0 0 100 100"><defs><marker markerWidth="10" markerHeight="7"></marker></defs></svg>
             >\
             """
    end
  end

  describe "query/2" do
    test "raises when an invalid selector is given" do
      assert_raise ArgumentError, ~r/got invalid css selector: hover:/, fn ->
        lazy_html = LazyHTML.from_fragment("<div></div>")
        LazyHTML.query(lazy_html, "hover:")
      end
    end
  end

  describe "parent_node/1" do
    test "from selector of nodes on different levels" do
      lazy_html =
        LazyHTML.from_fragment("""
        <div id="a">
          <div id="b">
            <span>Hello</span>
          </div>
          <span>world</span>
        </div>
        """)

      spans = LazyHTML.query(lazy_html, "span")
      parents = LazyHTML.parent_node(spans)
      parent_ids = parents |> Enum.flat_map(&LazyHTML.attribute(&1, "id")) |> Enum.sort()
      assert parent_ids == ["a", "b"]

      # parent of div#id="a" is <html>
      grandparents = LazyHTML.parent_node(parents)
      assert LazyHTML.tag(grandparents) |> Enum.sort() == ["div", "html"]

      # parent of <html> is null, so it's filtered out
      great_grandparents = LazyHTML.parent_node(grandparents)
      assert great_grandparents |> Enum.count() == 1

      # again, parent of <html> is filtered out
      assert LazyHTML.parent_node(great_grandparents) |> Enum.count() == 0
    end

    test "from selector of nodes on same level" do
      lazy_html =
        LazyHTML.from_fragment("""
        <div id="a">
          <div id="b">
            <span>Hello</span>
          </div>
          <div id="c">
            <span>world</span>
          </div>
        </div>
        """)

      spans = LazyHTML.query(lazy_html, "span")
      parents = LazyHTML.parent_node(spans)
      parent_ids = parents |> Enum.flat_map(&LazyHTML.attribute(&1, "id")) |> Enum.sort()
      assert parent_ids == ["b", "c"]

      # since they share the same parent, we now only have one node left
      grandparent = LazyHTML.parent_node(parents)
      assert LazyHTML.attribute(grandparent, "id") == ["a"]
    end

    defp get_css_path(node, acc) do
      1 = Enum.count(node)
      parent = LazyHTML.parent_node(node)

      if Enum.count(parent) > 0 do
        [tag] = LazyHTML.tag(node)
        [i] = LazyHTML.nth_child(node)
        get_css_path(parent, [{tag, i} | acc])
      else
        acc |> Enum.map_join(" > ", fn {tag, i} -> "#{tag}:nth-child(#{i})" end)
      end
    end

    test "construct nth-child selector by traversing parents" do
      lazy_html =
        LazyHTML.from_fragment("""
        <div>
          <div class="wibble">
            <span>wibble</span>
          </div>
          <div class="wobble">
            <span>wobble</span>
          </div>
        </div>
        """)

      span = LazyHTML.query(lazy_html, ".wobble span")
      path = get_css_path(span, [])
      assert path == "div:nth-child(1) > div:nth-child(2) > span:nth-child(1)"

      span2 = LazyHTML.query(lazy_html, path)
      assert LazyHTML.equals?(span, span2)
    end
  end

  describe "nth_child/1" do
    test "nth_child gives position" do
      lazy_html =
        LazyHTML.from_fragment("""
        <div>
          Text isn't counted.
          <span>1</span>
          <!-- neither are comments -->
          <span>2</span>
        </div>
        """)

      assert LazyHTML.nth_child(lazy_html) == [1]
      assert lazy_html["div"] |> LazyHTML.nth_child() == [1]
      assert lazy_html["span"] |> LazyHTML.nth_child() == [1, 2]

      # Verify numbering matches css selector
      assert lazy_html["span:nth-child(1)"] |> LazyHTML.text() == "1"
      assert lazy_html["span:nth-child(2)"] |> LazyHTML.text() == "2"
    end
  end

  describe "query_by_id/2" do
    test "raises when an empty id is given" do
      assert_raise ArgumentError, ~r/id cannot be empty/, fn ->
        lazy_html = LazyHTML.from_fragment("<div></div>")
        LazyHTML.query_by_id(lazy_html, "")
      end
    end

    test "handles ids with characters that require escaping in css selectors" do
      lazy_html =
        LazyHTML.from_fragment(
          ~S|<div><span id="&quot;hello&quot;">Hello</span> <span>world</span></div>|
        )

      result = LazyHTML.query_by_id(lazy_html, ~S|"hello"|)

      assert Enum.count(result) == 1
    end

    test "returns multiple elements if all have the given id" do
      lazy_html =
        LazyHTML.from_fragment(~S|<div id="root"></div><div><span id="root"></span></div>|)

      result = LazyHTML.query_by_id(lazy_html, "root")
      assert Enum.count(result) == 2
    end

    test "only finds exact match" do
      lazy_html =
        LazyHTML.from_fragment(~S|<div id="root"></div><div id="root-1"></div>|)

      result = LazyHTML.query_by_id(lazy_html, "root")
      assert Enum.count(result) == 1
    end
  end

  describe "text/1" do
    test "ignores root comment nodes" do
      lazy_html = LazyHTML.from_fragment(~S|<!-- Comment -->Hello <span>world</span>|)

      assert LazyHTML.text(lazy_html) == "Hello world"
    end
  end

  describe "Inspect protocol" do
    test "single root node" do
      lazy_html =
        LazyHTML.from_fragment("""
        <div>
          <a href="https://elixir-lang.org">Elixir</a>
        </div>\
        """)

      assert inspect(lazy_html) == """
             #LazyHTML<
               1 node
               #1
               <div>
                 <a href="https://elixir-lang.org">Elixir</a>
               </div>
             >\
             """
    end

    test "multiple root nodes" do
      lazy_html =
        LazyHTML.from_fragment("""
        <a href="https://elixir-lang.org">Elixir</a>
        <a href="https://www.erlang.org">Erlang</a>\
        """)

      assert inspect(lazy_html) == """
             #LazyHTML<
               3 nodes
               #1
               <a href="https://elixir-lang.org">Elixir</a>
               #2
               [whitespace]
               #3
               <a href="https://www.erlang.org">Erlang</a>
             >\
             """
    end

    test "comment and text nodes" do
      lazy_html =
        LazyHTML.from_fragment("""
        <a href="https://elixir-lang.org">Elixir</a>
        <!-- Text -->
        Hello world
        <a href="https://www.erlang.org">Erlang</a>\
        """)

      assert inspect(lazy_html) == """
             #LazyHTML<
               5 nodes
               #1
               <a href="https://elixir-lang.org">Elixir</a>
               #2
               [whitespace]
               #3
               <!-- Text -->
               #4
               [whitespace]Hello world[whitespace]
               #5
               <a href="https://www.erlang.org">Erlang</a>
             >\
             """
    end

    test "nodes from query" do
      lazy_html =
        LazyHTML.from_fragment("""
        <div>
          <a href="https://elixir-lang.org">Elixir</a>
          <a href="https://www.erlang.org">Erlang</a>
        </div>\
        """)

      links = LazyHTML.query(lazy_html, "a")

      assert inspect(links) == """
             #LazyHTML<
               2 nodes (from selector)
               #1
               <a href="https://elixir-lang.org">Elixir</a>
               #2
               <a href="https://www.erlang.org">Erlang</a>
             >\
             """
    end

    test "printable limit" do
      lazy_html =
        LazyHTML.from_fragment("""
        <span>Hello</span><span>world</span>\
        """)

      assert inspect(lazy_html, printable_limit: 8) == """
             #LazyHTML<
               2 nodes
               #1
               <span>He[...]
               #2
               <span>wo[...]
             >\
             """
    end

    test "limit" do
      lazy_html =
        LazyHTML.from_fragment("""
        <span>Hello</span><span>world</span>\
        """)

      assert inspect(lazy_html, limit: 1) == """
             #LazyHTML<
               2 nodes
               #1
               <span>Hello</span>
               [1 more]
             >\
             """

      assert inspect(lazy_html, limit: 2) == """
             #LazyHTML<
               2 nodes
               #1
               <span>Hello</span>
               #2
               <span>world</span>
             >\
             """
    end
  end

  describe "Enumerable protocol" do
    test "Enum.count/1" do
      lazy_html =
        LazyHTML.from_fragment("""
        <span>Hello</span><span>world</span>\
        """)

      assert Enum.count(lazy_html) == 2
    end

    test "Enum.to_list/1" do
      lazy_html =
        LazyHTML.from_fragment("""
        <span>Hello</span><span>world</span>\
        """)

      assert [span1, span2] = Enum.to_list(lazy_html)

      assert LazyHTML.to_html(span1) == ~S|<span>Hello</span>|
      assert LazyHTML.to_html(span2) == ~S|<span>world</span>|
    end

    test "Enum.slice/3" do
      lazy_html =
        LazyHTML.from_fragment("""
        <span>Hello</span><span>world</span>\
        """)

      assert [span2] = Enum.slice(lazy_html, 1, 1)

      assert LazyHTML.to_html(span2) == ~S|<span>world</span>|
    end
  end

  describe "Access behaviour" do
    test "fetch/2" do
      lazy_html =
        LazyHTML.from_fragment("""
        <div><span>Hello</span><span>world</span></div>\
        """)

      assert inspect(lazy_html["span"]) == """
             #LazyHTML<
               2 nodes (from selector)
               #1
               <span>Hello</span>
               #2
               <span>world</span>
             >\
             """
    end
  end
end
