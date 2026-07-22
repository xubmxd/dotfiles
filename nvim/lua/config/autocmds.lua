local function transparent_bg()
    local highlights = {
        "Normal",
        "NormalFloat",
        "LineNr",
        "Folded",
        "NonText",
        "SpecialKey",
        "VertSplit",
        "SignColumn",
        "EndOfBuffer",
    }

    for _, hl in ipairs(highlights) do
        vim.api.nvim_set_hl(0, hl, {
            bg = "none",
            ctermbg = "none",
        })
    end
end

transparent_bg()

vim.api.nvim_create_autocmd("ColorScheme", {
    callback = transparent_bg,
})
