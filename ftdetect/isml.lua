vim.api.nvim_create_autocmd({ "BufRead", "BufNewFile" }, {
    pattern = "*.isml",
    callback = function()
        vim.bo.filetype = "html.isml"
    end,
})
