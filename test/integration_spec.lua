local helpers = require('test.helpers')

describe('claude-code integrations', function()
  local claude_code
  
  before_each(function()
    -- Reset modules
    package.loaded['claude-code'] = nil
    package.loaded['claude-code.integrations'] = nil
    package.loaded['claude-code.integrations.cmp'] = nil
    
    claude_code = require('claude-code')
  end)
  
  describe('integration loader', function()
    it('should load without errors', function()
      local integrations = require('claude-code.integrations')
      assert.is_not_nil(integrations)
      assert.is_function(integrations.setup)
      assert.is_function(integrations.status)
    end)
    
    it('should report integration status', function()
      local integrations = require('claude-code.integrations')
      local status = integrations.status()
      
      assert.is_table(status)
      -- Should have entries for each integration
      assert.is_not_nil(status.cmp)
      assert.is_not_nil(status.telescope)
      assert.is_not_nil(status.lsp)
    end)
  end)
  
  describe('nvim-cmp integration', function()
    it('should provide cmp source', function()
      local cmp_source = require('claude-code.integrations.cmp')
      
      assert.is_table(cmp_source)
      assert.is_function(cmp_source.complete)
      assert.is_function(cmp_source.is_available)
      assert.is_function(cmp_source.get_trigger_characters)
    end)
    
    it('should return trigger characters', function()
      local cmp_source = require('claude-code.integrations.cmp')
      local triggers = cmp_source:get_trigger_characters()
      
      assert.is_table(triggers)
      assert.is_true(#triggers > 0)
      assert.is_true(vim.tbl_contains(triggers, '.'))
    end)
  end)
  
  describe('diff preview', function()
    it('should load diff preview module', function()
      local diff_preview = require('claude-code.ui.diff_preview')
      
      assert.is_table(diff_preview)
      assert.is_function(diff_preview.show)
      assert.is_function(diff_preview.is_active)
    end)
  end)
  
  describe('progress indicator', function()
    it('should load progress module', function()
      local progress = require('claude-code.ui.progress')
      
      assert.is_table(progress)
      assert.is_function(progress.start)
      assert.is_function(progress.update)
      assert.is_function(progress.stop)
      assert.is_function(progress.is_active)
    end)
    
    it('should start and stop progress', function()
      local progress = require('claude-code.ui.progress')
      
      assert.is_false(progress.is_active())
      
      progress.start("Testing...")
      assert.is_true(progress.is_active())
      
      progress.stop()
      assert.is_false(progress.is_active())
    end)
  end)
  
  describe('smart context', function()
    it('should detect context type', function()
      local context = require('claude-code.context')
      
      assert.equals('refactor', context._determine_context_type('refactor this function'))
      assert.equals('debug', context._determine_context_type('fix this error'))
      assert.equals('test', context._determine_context_type('write tests'))
      assert.equals('document', context._determine_context_type('add docs'))
      assert.equals('general', context._determine_context_type('help me'))
    end)
  end)
  
  describe('templates', function()
    it('should provide default templates', function()
      local templates = require('claude-code.templates')
      local all = templates.get_all()
      
      assert.is_table(all)
      assert.is_true(#all > 0)
      
      -- Check template structure
      local template = all[1]
      assert.is_string(template.name)
      assert.is_string(template.category)
      assert.is_string(template.description)
      assert.is_string(template.content)
    end)
  end)
  
  describe('agents', function()
    it('should provide available agents', function()
      local agents = require('claude-code.agents')
      local available = agents.get_available()
      
      assert.is_table(available)
      assert.is_true(#available > 0)
      
      -- Check agent structure
      local agent = available[1]
      assert.is_string(agent.name)
      assert.is_string(agent.description)
      assert.is_table(agent.capabilities)
    end)
  end)
end)