local helpers = require('test.helpers')

describe('claude-code.nvim', function()
  local claude_code
  
  before_each(function()
    -- Reset state before each test
    package.loaded['claude-code'] = nil
    package.loaded['claude-code.config'] = nil
    claude_code = require('claude-code')
  end)
  
  describe('setup', function()
    it('should set up with default config', function()
      claude_code.setup()
      local config = require('claude-code.config').get()
      
      assert.equals('claude', config.command)
      assert.equals('sonnet', config.model)
      assert.is_false(config.auto_start)
    end)
    
    it('should merge user config', function()
      claude_code.setup({
        model = 'opus',
        auto_start = true,
      })
      
      local config = require('claude-code.config').get()
      assert.equals('opus', config.model)
      assert.is_true(config.auto_start)
    end)
  end)
  
  describe('commands', function()
    before_each(function()
      claude_code.setup()
    end)
    
    it('should create user commands', function()
      assert.is_not_nil(vim.api.nvim_get_commands({}).ClaudeCode)
      assert.is_not_nil(vim.api.nvim_get_commands({}).ClaudeComplete)
      assert.is_not_nil(vim.api.nvim_get_commands({}).ClaudeEdit)
      assert.is_not_nil(vim.api.nvim_get_commands({}).ClaudeChat)
    end)
  end)
end)