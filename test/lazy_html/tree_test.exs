defmodule LazyHTML.TreeTest do
  use ExUnit.Case

  doctest LazyHTML.Tree

  describe "to_html/1" do
    test "returns html consistent with the native one" do
      lazy_html =
        LazyHTML.from_document("""
        <!-- Top comment -->
        <html><head>
          <meta charset="UTF-8" />
          <meta name="viewport" content="width=device-width, initial-scale=1.0" />
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
            <img src="/assets/image.jpeg" alt="image" />
            <form>
              <input class="input" value="" name="name" />
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
            &amp;
            &nbsp;
            &lt;
            &gt;
            &euro; €
            " '
            <div class="&amp; &nbsp; < > ' &quot;"></div>
            🔥🐈
          </div>
        </body></html>\
        """)

      tree = LazyHTML.to_tree(lazy_html)

      assert LazyHTML.Tree.to_html(tree) == LazyHTML.to_html(lazy_html)
    end
  end
end
