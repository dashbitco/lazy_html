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

      assert LazyHTML.Tree.to_html(tree, skip_whitespace_nodes: true) == "<p><span> Hello </span><span> world </span></p>"
    end
  end
end
