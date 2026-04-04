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

    test "does not include duplicated elements in the result set" do
      fragment =
        LazyHTML.from_fragment(~S"""
        <div>
          <div>1</div>
          <div>2</div>
        </div>
        """)

      result = fragment |> LazyHTML.query("div") |> LazyHTML.query("div")

      # If nodes were not deduplicated, the second query would inflate
      # the result to 5 nodes. We expect only 3 unique nodes.

      assert inspect(result) == """
             #LazyHTML<
               3 nodes (from selector)
               #1
               <div>
                 <div>1</div>
                 <div>2</div>
               </div>
               #2
               <div>1</div>
               #3
               <div>2</div>
             >\
             """
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
      parent_ids = parents |> LazyHTML.attribute("id") |> Enum.sort()
      assert parent_ids == ["a", "b"]

      # parent of div#id="a" is null
      grandparents = LazyHTML.parent_node(parents)
      assert LazyHTML.tag(grandparents) == ["div"]

      great_grandparents = LazyHTML.parent_node(grandparents)
      assert great_grandparents |> Enum.count() == 0
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
      parent_ids = parents |> LazyHTML.attribute("id") |> Enum.sort()
      assert parent_ids == ["b", "c"]

      # since they share the same parent, we now only have one node left
      grandparent = LazyHTML.parent_node(parents)
      assert LazyHTML.attribute(grandparent, "id") == ["a"]
    end

    defp ancestor_chain(node) do
      parent = LazyHTML.parent_node(node)

      if Enum.count(node) == 0 do
        []
      else
        ancestor_chain(parent) ++ LazyHTML.tag(parent)
      end
    end

    test "last parent node is <html> if instantiated via from_document and similar" do
      lazy_html = LazyHTML.from_document("<html><body><div>root</div></body></html>")
      assert lazy_html |> LazyHTML.query("div") |> ancestor_chain() == ["html", "body"]

      lazy_html = LazyHTML.from_fragment("<div>root</div>")
      assert lazy_html |> LazyHTML.query("div") |> ancestor_chain() == []

      lazy_html = LazyHTML.from_tree([{"div", [], []}])
      assert lazy_html |> LazyHTML.query("div") |> ancestor_chain() == []

      lazy_html = LazyHTML.from_tree([{"html", [], [{"body", [], [{"div", [], []}]}]}])
      assert lazy_html |> LazyHTML.query("div") |> ancestor_chain() == ["html", "body"]
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

  describe "replace/3" do
    test "replaces a single element with new content" do
      lazy_html = LazyHTML.from_fragment(~S|<div id="main"><span>Old content</span></div>|)
      new_content = LazyHTML.from_fragment(~S|<p>New content</p>|)
      
      result = LazyHTML.replace(lazy_html, "#main span", new_content)
      
      assert LazyHTML.to_html(result) == ~S|<div id="main"><p>New content</p></div>|
    end

    test "replaces element in a list" do
      lazy_html = LazyHTML.from_fragment(~S|<ul><li>Item 1</li><li id="target">Item 2</li><li>Item 3</li></ul>|)
      new_content = LazyHTML.from_fragment(~S|<li class="replaced">Replaced item</li>|)
      
      result = LazyHTML.replace(lazy_html, "#target", new_content)
      
      assert LazyHTML.to_html(result) == ~S|<ul><li>Item 1</li><li class="replaced">Replaced item</li><li>Item 3</li></ul>|
    end

    test "replaces with multiple nodes" do
      lazy_html = LazyHTML.from_fragment(~S|<div><p id="old">Old paragraph</p></div>|)
      new_content = LazyHTML.from_fragment(~S|<h1>Title</h1><p>New paragraph</p>|)
      
      result = LazyHTML.replace(lazy_html, "#old", new_content)
      
      assert LazyHTML.to_html(result) == ~S|<div><h1>Title</h1><p>New paragraph</p></div>|
    end

    test "raises when no elements match" do
      lazy_html = LazyHTML.from_fragment(~S|<div><span>Content</span></div>|)
      new_content = LazyHTML.from_fragment(~S|<p>New content</p>|)
      
      assert_raise ArgumentError, "no elements found matching selector", fn ->
        LazyHTML.replace(lazy_html, "#nonexistent", new_content)
      end
    end

    test "raises when multiple elements match" do
      lazy_html = LazyHTML.from_fragment(~S|<div><span>First</span><span>Second</span></div>|)
      new_content = LazyHTML.from_fragment(~S|<p>New content</p>|)
      
      assert_raise ArgumentError, ~r/expected exactly 1 element matching selector.*but found 2/, fn ->
        LazyHTML.replace(lazy_html, "span", new_content)
      end
    end

    test "works with complex selectors" do
      lazy_html = LazyHTML.from_fragment(~S|<div class="container"><div class="item active">Active item</div><div class="item">Inactive item</div></div>|)
      new_content = LazyHTML.from_fragment(~S|<div class="item updated">Updated item</div>|)
      
      result = LazyHTML.replace(lazy_html, ".item.active", new_content)
      
      assert LazyHTML.to_html(result) == ~S|<div class="container"><div class="item updated">Updated item</div><div class="item">Inactive item</div></div>|
    end

    test "preserves document structure when replacing nested elements" do
      lazy_html = LazyHTML.from_fragment(~S|<article><header><h1 id="title">Old Title</h1></header><main>Content</main></article>|)
      new_content = LazyHTML.from_fragment(~S|<h1 id="title" class="new">New Title</h1>|)
      
      result = LazyHTML.replace(lazy_html, "#title", new_content)
      
      assert LazyHTML.to_html(result) == ~S|<article><header><h1 id="title" class="new">New Title</h1></header><main>Content</main></article>|
    end
  end

  describe "appendChild/3" do
    test "appends a single child to container" do
      lazy_html = LazyHTML.from_fragment(~S|<div id="container"><p>Existing content</p></div>|)
      child_content = LazyHTML.from_fragment(~S|<span>New child</span>|)
      
      result = LazyHTML.appendChild(lazy_html, "#container", child_content)
      
      assert LazyHTML.to_html(result) == ~S|<div id="container"><p>Existing content</p><span>New child</span></div>|
    end

    test "appends multiple children to list" do
      lazy_html = LazyHTML.from_fragment(~S|<ul id="list"><li>Item 1</li></ul>|)
      child_content = LazyHTML.from_fragment(~S|<li>Item 2</li><li>Item 3</li>|)
      
      result = LazyHTML.appendChild(lazy_html, "#list", child_content)
      
      assert LazyHTML.to_html(result) == ~S|<ul id="list"><li>Item 1</li><li>Item 2</li><li>Item 3</li></ul>|
    end

    test "appends to empty element" do
      lazy_html = LazyHTML.from_fragment(~S|<div id="empty"></div>|)
      child_content = LazyHTML.from_fragment(~S|<p>First content</p>|)
      
      result = LazyHTML.appendChild(lazy_html, "#empty", child_content)
      
      assert LazyHTML.to_html(result) == ~S|<div id="empty"><p>First content</p></div>|
    end

    test "appends mixed content types" do
      lazy_html = LazyHTML.from_fragment(~S|<section id="content"><h1>Title</h1></section>|)
      child_content = LazyHTML.from_fragment(~S|<p>Paragraph</p><ul><li>List item</li></ul>|)
      
      result = LazyHTML.appendChild(lazy_html, "#content", child_content)
      
      assert LazyHTML.to_html(result) == ~S|<section id="content"><h1>Title</h1><p>Paragraph</p><ul><li>List item</li></ul></section>|
    end

    test "preserves existing children order" do
      lazy_html = LazyHTML.from_fragment(~S|<div class="parent"><span>First</span><span>Second</span></div>|)
      child_content = LazyHTML.from_fragment(~S|<span>Third</span>|)
      
      result = LazyHTML.appendChild(lazy_html, ".parent", child_content)
      
      assert LazyHTML.to_html(result) == ~S|<div class="parent"><span>First</span><span>Second</span><span>Third</span></div>|
    end

    test "raises when no elements match" do
      lazy_html = LazyHTML.from_fragment(~S|<div><span>Content</span></div>|)
      child_content = LazyHTML.from_fragment(~S|<p>Child content</p>|)
      
      assert_raise ArgumentError, "no elements found matching selector", fn ->
        LazyHTML.appendChild(lazy_html, "#nonexistent", child_content)
      end
    end

    test "raises when multiple elements match" do
      lazy_html = LazyHTML.from_fragment(~S|<div><div class="target">First</div><div class="target">Second</div></div>|)
      child_content = LazyHTML.from_fragment(~S|<p>Child content</p>|)
      
      assert_raise ArgumentError, ~r/expected exactly 1 element matching selector.*but found 2/, fn ->
        LazyHTML.appendChild(lazy_html, ".target", child_content)
      end
    end

    test "works with complex selectors" do
      lazy_html = LazyHTML.from_fragment(~S|<article><div class="content main"><p>Existing</p></div><div class="content">Other</div></article>|)
      child_content = LazyHTML.from_fragment(~S|<p>Appended to main</p>|)
      
      result = LazyHTML.appendChild(lazy_html, ".content.main", child_content)
      
      assert LazyHTML.to_html(result) == ~S|<article><div class="content main"><p>Existing</p><p>Appended to main</p></div><div class="content">Other</div></article>|
    end

    test "works with nested elements" do
      lazy_html = LazyHTML.from_fragment(~S|<div><article><section id="target"><h2>Section</h2></section></article></div>|)
      child_content = LazyHTML.from_fragment(~S|<p>New paragraph</p>|)
      
      result = LazyHTML.appendChild(lazy_html, "#target", child_content)
      
      assert LazyHTML.to_html(result) == ~S|<div><article><section id="target"><h2>Section</h2><p>New paragraph</p></section></article></div>|
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

    test "does not include duplicated elements in the result set" do
      # A proper HTML document should not have duplicated ids, but it
      # can be the case.
      fragment =
        LazyHTML.from_fragment(~S"""
        <div id="1">
          <div id="1">1</div>
          <div>2</div>
        </div>
        """)

      result = fragment |> LazyHTML.query_by_id("1") |> LazyHTML.query_by_id("1")

      # If nodes were not deduplicated, the second query would inflate
      # the result to 3 nodes. We expect only 2 unique nodes.

      assert inspect(result) == """
             #LazyHTML<
               2 nodes (from selector)
               #1
               <div id=\"1\">
                 <div id=\"1\">1</div>
                 <div>2</div>
               </div>
               #2
               <div id=\"1\">1</div>
             >\
             """
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
