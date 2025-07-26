-- Template management for claude-code.nvim
local M = {}
local config = require('claude-code.config')

-- Default templates
M.default_templates = {
  -- Testing templates
  {
    name = "test_function",
    category = "testing",
    description = "Generate comprehensive tests for a function",
    content = [[
Write comprehensive tests for this function including:
- Happy path tests with typical inputs
- Edge cases (empty, null, boundary values)
- Error conditions and exception handling
- Performance considerations if applicable
- Use {test_framework} framework
- Follow existing test patterns in this codebase
    ]],
  },
  
  {
    name = "test_class",
    category = "testing",
    description = "Generate tests for a class",
    content = [[
Create a complete test suite for this class:
- Test each public method
- Test constructor with various inputs
- Test state changes and side effects
- Test error conditions
- Mock external dependencies
- Use {test_framework} framework
    ]],
  },
  
  -- Refactoring templates
  {
    name = "extract_function",
    category = "refactoring",
    description = "Extract code into a well-named function",
    content = [[
Extract the selected code into a function with:
- Descriptive name that explains what it does
- Appropriate parameters
- Clear return value
- Error handling if needed
- Documentation comment
- Maintain the same behavior
    ]],
  },
  
  {
    name = "simplify_complex",
    category = "refactoring",
    description = "Simplify complex code",
    content = [[
Simplify this code while maintaining functionality:
- Break down complex expressions
- Extract intermediate variables with descriptive names
- Reduce nesting levels
- Improve readability
- Add clarifying comments where needed
    ]],
  },
  
  -- Documentation templates
  {
    name = "add_docs",
    category = "documentation",
    description = "Add comprehensive documentation",
    content = [[
Add documentation including:
- Purpose and overview
- Parameters with types and descriptions
- Return value description
- Example usage
- Potential errors or exceptions
- Any side effects or important notes
    ]],
  },
  
  {
    name = "api_docs",
    category = "documentation",
    description = "Generate API documentation",
    content = [[
Generate API documentation in {format} format:
- Endpoint description
- Request/response formats
- Authentication requirements
- Error codes and messages
- Example requests and responses
- Rate limiting information
    ]],
  },
  
  -- Code generation templates
  {
    name = "implement_interface",
    category = "generation",
    description = "Implement an interface or abstract class",
    content = [[
Implement all required methods for this interface:
- Follow the interface contract exactly
- Add appropriate error handling
- Include documentation for each method
- Follow project coding standards
- Add TODO comments for complex implementations
    ]],
  },
  
  {
    name = "crud_operations",
    category = "generation",
    description = "Generate CRUD operations",
    content = [[
Generate CRUD operations for this entity:
- Create with validation
- Read with filtering and pagination
- Update with partial updates support
- Delete with cascade handling
- Include error handling and logging
- Follow RESTful conventions
    ]],
  },
  
  -- Optimization templates
  {
    name = "optimize_performance",
    category = "optimization",
    description = "Optimize code for performance",
    content = [[
Optimize this code for better performance:
- Identify bottlenecks
- Reduce time complexity
- Minimize memory allocations
- Use efficient data structures
- Add caching where appropriate
- Maintain readability
    ]],
  },
  
  {
    name = "optimize_memory",
    category = "optimization",
    description = "Reduce memory usage",
    content = [[
Optimize memory usage:
- Identify memory leaks
- Use more efficient data structures
- Implement object pooling if applicable
- Clear references when no longer needed
- Consider lazy loading
- Add memory usage comments
    ]],
  },
  
  -- Security templates
  {
    name = "security_review",
    category = "security",
    description = "Review code for security issues",
    content = [[
Review this code for security vulnerabilities:
- SQL injection risks
- XSS vulnerabilities
- Authentication/authorization issues
- Input validation problems
- Sensitive data exposure
- Suggest fixes for any issues found
    ]],
  },
  
  {
    name = "add_validation",
    category = "security",
    description = "Add input validation",
    content = [[
Add comprehensive input validation:
- Validate all user inputs
- Check data types and ranges
- Sanitize strings for security
- Add appropriate error messages
- Follow validation best practices
- Consider edge cases
    ]],
  },
}

-- Get all templates
function M.get_all()
  local templates = vim.deepcopy(M.default_templates)
  
  -- Load custom templates from config
  local custom = config.get().templates or {}
  for name, content in pairs(custom) do
    table.insert(templates, {
      name = name,
      category = "custom",
      description = "Custom template",
      content = content,
    })
  end
  
  return templates
end

-- Get template by name
function M.get(name)
  local templates = M.get_all()
  for _, template in ipairs(templates) do
    if template.name == name then
      return template
    end
  end
  return nil
end

-- Use a template
function M.use(name)
  local template = M.get(name)
  if not template then
    vim.notify("Template not found: " .. name, vim.log.levels.ERROR)
    return
  end
  
  -- Get current context
  local ctx = require('claude-code.context').gather_context()
  
  -- Replace template variables
  local content = template.content
  content = content:gsub("{test_framework}", M._detect_test_framework())
  content = content:gsub("{format}", M._detect_doc_format())
  
  -- Check if we have a selection
  if ctx.selection then
    -- Use template with selection
    require('claude-code.actions').edit_selection(content)
  else
    -- Open chat with template
    require('claude-code.ui.chat').open(content)
  end
end

-- Detect test framework
function M._detect_test_framework()
  -- Check for common test frameworks
  if vim.fn.filereadable("jest.config.js") == 1 then
    return "Jest"
  elseif vim.fn.filereadable("pytest.ini") == 1 then
    return "pytest"
  elseif vim.fn.filereadable("go.mod") == 1 then
    return "Go testing"
  elseif vim.fn.filereadable("Cargo.toml") == 1 then
    return "Rust test"
  else
    return "the appropriate test framework"
  end
end

-- Detect documentation format
function M._detect_doc_format()
  local ft = vim.bo.filetype
  if ft == "javascript" or ft == "typescript" then
    return "JSDoc"
  elseif ft == "python" then
    return "docstring"
  elseif ft == "java" then
    return "Javadoc"
  elseif ft == "rust" then
    return "rustdoc"
  else
    return "appropriate documentation"
  end
end

return M