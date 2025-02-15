; extend
[
  ((element
    (start_tag
      (tag_name) @_tag)) @indent
   (#eq? @_tag "isif"))

  ((element
    (start_tag
      (tag_name) @_tag)) @alignment
   (#match? @_tag "^is(elseif|else)$"))
]
