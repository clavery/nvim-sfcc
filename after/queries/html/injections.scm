; extends
((element
  (start_tag
    (tag_name) @_tag)
  (text) @injection.content)
 (#eq? @_tag "isscript")
 (#set! injection.language "javascript"))
