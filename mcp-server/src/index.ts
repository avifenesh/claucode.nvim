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

// Get communication directory
function getCommunicationDir(): string {
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
    const requestFile = await writeDiffRequest(hash, diff);
    console.error(`Diff request written to: ${requestFile}`);
    
    // Wait for response
    const approved = await watchForResponse(hash);
    
    // Cleanup
    pendingDiffs.delete(hash);
    
    return approved;
  } catch (error: any) {
    console.error(`Error in showDiffAndWait: ${error.message}`);
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
      
      try {
        // Read current content
        const content = await fs.readFile(file_path, "utf-8");
        
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
        const approved = await showDiffAndWait(file_path, content, modified);
        
        if (approved) {
          await fs.writeFile(file_path, modified, "utf-8");
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
      } catch (error: any) {
        return {
          content: [{
            type: "text",
            text: `Error: ${error.message}`
          }]
        };
      }
    }
    
    case "nvim_write_with_diff": {
      const { file_path, content } = WriteFileSchema.parse(args);
      
      try {
        // Read current content if file exists
        let original = "";
        try {
          original = await fs.readFile(file_path, "utf-8");
        } catch {
          // File doesn't exist
        }
        
        // Show diff and wait for approval
        const approved = await showDiffAndWait(file_path, original, content);
        
        if (approved) {
          await fs.mkdir(path.dirname(file_path), { recursive: true });
          await fs.writeFile(file_path, content, "utf-8");
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
      } catch (error: any) {
        return {
          content: [{
            type: "text",
            text: `Error: ${error.message}`
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
  console.error("Claucode MCP server started");
}

main().catch((error) => {
  console.error("Server error:", error);
  process.exit(1);
});