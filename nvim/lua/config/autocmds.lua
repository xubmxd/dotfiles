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

vim.diagnostic.config({
    virtual_text = true,
    underline = true,
    signs = true,
    update_in_insert = false,
})

vim.api.nvim_create_autocmd("CursorHold", {
    callback = function()
        -- Don't show another popup if one is already open
        for _, winid in ipairs(vim.api.nvim_tabpage_list_wins(0)) do
            local config = vim.api.nvim_win_get_config(winid)
            if config.relative ~= "" then
                return
            end
        end

        vim.diagnostic.open_float(nil, {
            focusable = false,
            close_events = {
                "BufLeave",
                "CursorMoved",
                "InsertEnter",
                "FocusLost",
            },
            border = "rounded",
            source = "always",
            prefix = "",
            scope = "cursor",
        })
    end,
})
