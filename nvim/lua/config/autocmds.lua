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

vim.o.updatetime = 300

vim.api.nvim_create_autocmd({ "CursorHold", "CursorHoldI" }, {
    callback = function()
        vim.diagnostic.open_float(nil, {
            focusable = false,
            border = "rounded",
            source = "always",
        })
    end,
})
