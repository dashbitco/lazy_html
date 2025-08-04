defmodule LazyHTML.TreeTest do
  use ExUnit.Case

  doctest LazyHTML.Tree

  describe "to_html/1" do
    test "serializes tree as a valid html representation" do
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

      tree = html |> LazyHTML.from_document() |> LazyHTML.to_tree()

      assert LazyHTML.Tree.to_html(tree) == html
    end

    test "with :skip_whitespace_nodes" do
      tree =
        """
        <p>
          <span> Hello </span>
          <span> world </span>
        </p>
        """
        |> LazyHTML.from_fragment()
        |> LazyHTML.to_tree()

      assert LazyHTML.Tree.to_html(tree, skip_whitespace_nodes: true) ==
               "<p><span> Hello </span><span> world </span></p>"
    end
  end

  describe "traverse/3" do
    test "does post-order traversal of the nodes and accumulates results" do
      tree = [
        {:comment, "Hello world"},
        {"div", [{"class", "root"}],
         [
           {"span", [], ["Hello"]},
           {:comment, "intersection"},
           {"span", [], ["world"]}
         ]}
      ]

      nodes = LazyHTML.Tree.traverse(tree, [], fn node, acc -> [node | acc] end)

      assert nodes == [
               {"div", [{"class", "root"}],
                [{"span", [], ["Hello"]}, {:comment, "intersection"}, {"span", [], ["world"]}]},
               {"span", [], ["world"]},
               "world",
               {:comment, "intersection"},
               {"span", [], ["Hello"]},
               "Hello",
               {:comment, "Hello world"}
             ]
    end
  end

  describe "postwalk/3" do
    test "does post-order traversal of the nodes and accumulates results" do
      tree = [
        {:comment, "Hello world"},
        {"div", [{"class", "root"}],
         [
           {"span", [], ["Hello"]},
           {:comment, "intersection"},
           {"span", [], ["world"]}
         ]}
      ]

      {^tree, nodes} = LazyHTML.Tree.postwalk(tree, [], fn node, acc -> {node, [node | acc]} end)

      assert nodes == [
               {"div", [{"class", "root"}],
                [{"span", [], ["Hello"]}, {:comment, "intersection"}, {"span", [], ["world"]}]},
               {"span", [], ["world"]},
               "world",
               {:comment, "intersection"},
               {"span", [], ["Hello"]},
               "Hello",
               {:comment, "Hello world"}
             ]
    end

    test "returns tree with nodes updated by the mapper function" do
      tree = [
        {:comment, "Hello world"},
        {"div", [{"class", "root"}],
         [
           {"span", [], ["Hello"]},
           {:comment, "intersection"},
           {"span", [], ["world"]}
         ]}
      ]

      {updated_tree, []} =
        LazyHTML.Tree.postwalk(tree, [], fn
          {tag, attrs, children}, acc ->
            {{tag, [{"data-new", "true"} | attrs], ["new" | children]}, acc}

          {:comment, content}, acc ->
            {{:comment, content <> " [new]"}, acc}

          text, acc when is_binary(text) ->
            {text <> " [new]", acc}
        end)

      assert updated_tree == [
               {:comment, "Hello world [new]"},
               {"div", [{"data-new", "true"}, {"class", "root"}],
                [
                  "new",
                  {"span", [{"data-new", "true"}], ["new", "Hello [new]"]},
                  {:comment, "intersection [new]"},
                  {"span", [{"data-new", "true"}], ["new", "world [new]"]}
                ]}
             ]
    end

    test "replaces nodes when mapper returns a list" do
      tree = [
        {"div", [], [{"span", [{"id", "1"}], ["Hello"]}]},
        {"div", [], [{"span", [{"id", "2"}], ["World"]}]}
      ]

      {updated_tree, []} =
        LazyHTML.Tree.postwalk(tree, [], fn
          {"span", [{"id", "1"}], _children}, acc ->
            # Remove the node.
            {[], acc}

          {"span", [{"id", "2"}], _children}, acc ->
            # Replace the node with two other nodes.
            {[{"p", [], []}, {"p", [], []}], acc}

          other, acc ->
            {other, acc}
        end)

      assert updated_tree == [
               {"div", [], []},
               {"div", [], [{"p", [], []}, {"p", [], []}]}
             ]
    end
  end

  describe "postwalk/2" do
    test "returns tree with nodes updated by the mapper function" do
      tree = [
        {:comment, "Hello world"},
        {"div", [{"class", "root"}],
         [
           {"span", [], ["Hello"]},
           {:comment, "intersection"},
           {"span", [], ["world"]}
         ]}
      ]

      updated_tree =
        LazyHTML.Tree.postwalk(tree, fn
          {tag, attrs, children} ->
            {tag, [{"data-new", "true"} | attrs], ["new" | children]}

          {:comment, content} ->
            {:comment, content <> " [new]"}

          text when is_binary(text) ->
            text <> " [new]"
        end)

      assert updated_tree == [
               {:comment, "Hello world [new]"},
               {"div", [{"data-new", "true"}, {"class", "root"}],
                [
                  "new",
                  {"span", [{"data-new", "true"}], ["new", "Hello [new]"]},
                  {:comment, "intersection [new]"},
                  {"span", [{"data-new", "true"}], ["new", "world [new]"]}
                ]}
             ]
    end
  end
end
