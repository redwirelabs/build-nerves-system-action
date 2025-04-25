IO.puts """
\u001b[33mFormatter disabled.\u001b[0m
This repository uses a style guide.

See:
  https://github.com/amclain/styleguides/blob/master/elixir/STYLEGUIDE.md
"""

Kernel.exit(:normal)

[
  inputs: ["{mix,.formatter}.exs", "{config,lib,test}/**/*.{ex,exs}"]
]
