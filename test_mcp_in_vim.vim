" Run this in Neovim to test MCP functionality
" :source /home/admin/claucode.nvim/test_mcp_in_vim.vim

echo "Testing MCP functionality..."

" First check if the plugin is loaded
if exists('g:loaded_claucode')
  echo "Claucode plugin is loaded"
else
  echo "WARNING: Claucode plugin is not loaded!"
endif

" Get the config
let config = luaeval('require("claucode").get_config()')
echo "show_diff: " . (has_key(config.bridge, 'show_diff') ? config.bridge.show_diff : 'not set')
echo "mcp.enabled: " . (has_key(config, 'mcp') && has_key(config.mcp, 'enabled') ? config.mcp.enabled : 'not set')

" Check MCP module
lua << EOF
local ok, mcp = pcall(require, "claucode.mcp")
if ok then
  vim.notify("MCP module loaded", vim.log.levels.INFO)
  if mcp.diff_watcher_timer then
    vim.notify("Diff watcher is RUNNING", vim.log.levels.INFO)
  else
    vim.notify("Diff watcher NOT running, starting it...", vim.log.levels.WARN)
    mcp.start_diff_watcher()
  end
else
  vim.notify("Failed to load MCP module: " .. tostring(mcp), vim.log.levels.ERROR)
end
EOF

" Create a test diff request after a short delay
call timer_start(1000, {-> execute("lua require('claucode.mcp').show_diff_window('test123', '/tmp/test.txt', 'Original', 'Modified')")})

echo "Test diff should appear in 1 second..."