#!/usr/bin/env node

import { Server } from "@modelcontextprotocol/sdk/server/index.js";
import { StdioServerTransport } from "@modelcontextprotocol/sdk/server/stdio.js";
import { CallToolRequestSchema, ListToolsRequestSchema } from "@modelcontextprotocol/sdk/types.js";
import { z } from "zod";
import fs from "fs/promises";
import path from "path";
import { createHash } from "crypto";
import os from "os";

// Tool schemas
const EditFileSchema = z.object({
  file_path: z.string().describe("Path to the file to edit"),
  old_string: z.string().describe("The exact string to replace"),
  new_string: z.string().describe("The new string to replace with")
});

const WriteFileSchema = z.object({
  file_path: z.string().describe("Path to the file to write"),
  content: z.string().describe("Content to write to the file")
});

// Pending diffs storage
interface PendingDiff {
  filepath: string;
  original: string;
  modified: string;
  hash: string;
  tempFile?: string;
  resolver?: (approved: boolean) => void;
}

const pendingDiffs = new Map<string, PendingDiff>();

// Get the working directory (project root)
// This is set by Neovim when spawning the MCP server
function getWorkingDirectory(): string {
  return process.cwd();
}

// Validate that a file path is within the project directory
// Prevents path traversal attacks (e.g., ../../../etc/passwd)
function validateFilePath(filePath: string): { valid: boolean; resolved: string; error?: string } {
  const workDir = getWorkingDirectory();
  
  // Resolve the path to absolute, normalizing any .. or . components
  const resolved = path.resolve(workDir, filePath);
  
  // Ensure the resolved path starts with the working directory
  // This prevents escaping via ../ sequences
  if (!resolved.startsWith(workDir + path.sep) && resolved !== workDir) {
    return {
      valid: false,
      resolved,
      error: `Path traversal rejected: ${filePath} resolves outside project directory`
    };
  }
  
  return { valid: true, resolved };
}

// Get communication directory
// Supports session-specific directory via CLAUCODE_COMM_DIR environment variable
// Falls back to legacy global directory for backwards compatibility
function getCommunicationDir(): string {
  if (process.env.CLAUCODE_COMM_DIR) {
    return process.env.CLAUCODE_COMM_DIR;
  }
  // Legacy fallback for backwards compatibility
  const dataDir = process.env.XDG_DATA_HOME || path.join(os.homedir(), '.local', 'share');
  return path.join(dataDir, 'claucode', 'diffs');
}

// Ensure communication directory exists
async function ensureCommunicationDir(): Promise<string> {
  const dir = getCommunicationDir();
  await fs.mkdir(dir, { recursive: true });
  return dir;
}

// Create hash for diff identification
function createDiffHash(filepath: string, original: string, modified: string): string {
  return createHash('sha256')
    .update(`${filepath}:${original}:${modified}`)
    .digest('hex')
    .substring(0, 16);
}

// Write diff request to file
async function writeDiffRequest(hash: string, diff: PendingDiff): Promise<string> {
  const dir = await ensureCommunicationDir();
  const requestFile = path.join(dir, `${hash}.request.json`);
  
  await fs.writeFile(requestFile, JSON.stringify({
    hash,
    filepath: diff.filepath,
    original: diff.original,
    modified: diff.modified,
    timestamp: Date.now()
  }), 'utf-8');
  
  return requestFile;
}

// Watch for response file
async function watchForResponse(hash: string): Promise<boolean> {
  const dir = await ensureCommunicationDir();
  const responseFile = path.join(dir, `${hash}.response.json`);

  return new Promise(async (resolve) => {
    const timeout = setTimeout(async () => {
      // Cleanup files on timeout
      try {
        await fs.unlink(path.join(dir, `${hash}.request.json`));
      } catch {}
      resolve(false);
    }, 60000); // 60 second timeout

    // Poll for response file
    const checkInterval = setInterval(async () => {
      try {
        const content = await fs.readFile(responseFile, 'utf-8');
        const response = JSON.parse(content);

        clearInterval(checkInterval);
        clearTimeout(timeout);

        // Cleanup files
        try {
          await fs.unlink(responseFile);
          await fs.unlink(path.join(dir, `${hash}.request.json`));
        } catch {}

        resolve(response.approved === true);
      } catch {
        // File doesn't exist yet, keep polling
      }
    }, 100); // Check every 100ms
  });
}

// Show diff in Neovim and wait for response
async function showDiffAndWait(filepath: string, original: string, modified: string): Promise<boolean> {
  const hash = createDiffHash(filepath, original, modified);
  
  // Store the diff
  const diff: PendingDiff = {
    filepath,
    original,
    modified,
    hash
  };
  pendingDiffs.set(hash, diff);
  
  try {
    // Write diff request to file
    await writeDiffRequest(hash, diff);
    
    // Wait for response
    const approved = await watchForResponse(hash);
    
    // Cleanup
    pendingDiffs.delete(hash);
    
    return approved;
  } catch {
    pendingDiffs.delete(hash);
    return false;
  }
}

// Create server
const server = new Server(
  {
    name: "claucode-mcp",
    version: "0.1.0"
  },
  {
    capabilities: {
      tools: {}
    }
  }
);

// Handle list tools request
server.setRequestHandler(ListToolsRequestSchema, async () => {
  return {
    tools: [
      {
        name: "nvim_edit_with_diff",
        description: "Edit a file with diff preview in Neovim - shows changes before applying",
        inputSchema: {
          type: "object",
          properties: {
            file_path: { type: "string", description: "Path to the file to edit" },
            old_string: { type: "string", description: "The exact string to replace" },
            new_string: { type: "string", description: "The new string to replace with" }
          },
          required: ["file_path", "old_string", "new_string"]
        }
      },
      {
        name: "nvim_write_with_diff", 
        description: "Write or create a file with diff preview in Neovim - shows changes before applying",
        inputSchema: {
          type: "object",
          properties: {
            file_path: { type: "string", description: "Path to the file to write" },
            content: { type: "string", description: "Content to write to the file" }
          },
          required: ["file_path", "content"]
        }
      }
    ]
  };
});

// Handle tool calls
server.setRequestHandler(CallToolRequestSchema, async (request) => {
  const { name, arguments: args } = request.params;

  switch (name) {
    case "nvim_edit_with_diff": {
      const { file_path, old_string, new_string } = EditFileSchema.parse(args);
      
      // Validate path to prevent traversal attacks
      const pathValidation = validateFilePath(file_path);
      if (!pathValidation.valid) {
        return {
          content: [{
            type: "text",
            text: `Error: ${pathValidation.error}`
          }]
        };
      }
      const safePath = pathValidation.resolved;
      
      try {
        // Read current content using validated path
        const content = await fs.readFile(safePath, "utf-8");
        
        // Check if old_string exists
        if (!content.includes(old_string)) {
          return {
            content: [{
              type: "text",
              text: `Error: Could not find the text to replace in ${file_path}`
            }]
          };
        }
        
        // Create modified content
        const modified = content.replace(old_string, new_string);
        
        // Show diff and wait for approval
        const approved = await showDiffAndWait(safePath, content, modified);

        if (approved) {
          await fs.writeFile(safePath, modified, "utf-8");
          return {
            content: [{
              type: "text",
              text: `Successfully edited ${file_path}`
            }]
          };
        } else {
          return {
            content: [{
              type: "text",
              text: `Edit rejected for ${file_path}`
            }]
          };
        }
      } catch (error) {
        const message = error instanceof Error ? error.message : "Unknown error";
        return {
          content: [{
            type: "text",
            text: `Error: ${message}`
          }]
        };
      }
    }
    
    case "nvim_write_with_diff": {
      const { file_path, content } = WriteFileSchema.parse(args);
      
      // Validate path to prevent traversal attacks
      const pathValidation = validateFilePath(file_path);
      if (!pathValidation.valid) {
        return {
          content: [{
            type: "text",
            text: `Error: ${pathValidation.error}`
          }]
        };
      }
      const safePath = pathValidation.resolved;
      
      try {
        // Read current content if file exists
        let original = "";
        try {
          original = await fs.readFile(safePath, "utf-8");
        } catch (error) {
          // File doesn't exist is fine, but rethrow other errors
          if (!(error instanceof Error && (error as NodeJS.ErrnoException).code === 'ENOENT')) {
            throw error;
          }
        }
        
        // Show diff and wait for approval
        const approved = await showDiffAndWait(safePath, original, content);
        
        if (approved) {
          // Ensure parent directory exists (validated path is safe)
          await fs.mkdir(path.dirname(safePath), { recursive: true });
          await fs.writeFile(safePath, content, "utf-8");
          return {
            content: [{
              type: "text",
              text: `Successfully wrote ${file_path}`
            }]
          };
        } else {
          return {
            content: [{
              type: "text",
              text: `Write rejected for ${file_path}`
            }]
          };
        }
      } catch (error) {
        const message = error instanceof Error ? error.message : "Unknown error";
        return {
          content: [{
            type: "text",
            text: `Error: ${message}`
          }]
        };
      }
    }
    
    default:
      return {
        content: [{
          type: "text",
          text: `Unknown tool: ${name}`
        }]
      };
  }
});

// Start server
async function main() {
  const transport = new StdioServerTransport();
  await server.connect(transport);
}

main().catch((error) => {
  console.error("Server error:", error);
  process.exit(1);
});