#!/usr/bin/env node

import { Server } from "@modelcontextprotocol/sdk/server/index.js";
import { StdioServerTransport } from "@modelcontextprotocol/sdk/server/stdio.js";
import { CallToolRequestSchema, ListToolsRequestSchema } from "@modelcontextprotocol/sdk/types.js";
import { z } from "zod";
import fs from "fs/promises";
import path from "path";
import { createHash } from "crypto";
import net from "net";

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
}

const pendingDiffs = new Map<string, PendingDiff>();

// Create hash for diff identification
function createDiffHash(filepath: string, original: string, modified: string): string {
  return createHash('sha256')
    .update(`${filepath}:${original}:${modified}`)
    .digest('hex')
    .substring(0, 16);
}

// Send command to Neovim
async function sendToNeovim(command: string): Promise<void> {
  const nvimSocket = process.env.NVIM || "/tmp/nvim.sock";
  
  return new Promise((resolve, reject) => {
    const client = net.createConnection(nvimSocket, () => {
      // Neovim expects msgpack-rpc format, but for simple commands we can use ex commands
      const message = JSON.stringify([0, 0, "nvim_command", [command]]);
      client.write(message);
      client.end();
      resolve();
    });
    
    client.on('error', (err) => {
      console.error(`Failed to connect to Neovim: ${err.message}`);
      reject(err);
    });
  });
}

// Show diff in Neovim and wait for response
async function showDiffAndWait(filepath: string, original: string, modified: string): Promise<boolean> {
  const hash = createDiffHash(filepath, original, modified);
  
  // Store the diff
  pendingDiffs.set(hash, {
    filepath,
    original,
    modified,
    hash
  });
  
  // Create a promise that will be resolved when we get a response
  return new Promise(async (resolve) => {
    // Set up a timeout
    const timeout = setTimeout(() => {
      pendingDiffs.delete(hash);
      resolve(false); // Timeout = reject
    }, 60000); // 60 second timeout
    
    // Store the resolver
    (pendingDiffs.get(hash) as any).resolver = (approved: boolean) => {
      clearTimeout(timeout);
      pendingDiffs.delete(hash);
      resolve(approved);
    };
    
    try {
      // Tell Neovim to show the diff
      await sendToNeovim(`lua require('claucode.mcp').show_diff('${hash}', '${filepath.replace(/'/g, "\\'")}')`);
    } catch (error) {
      clearTimeout(timeout);
      pendingDiffs.delete(hash);
      resolve(false);
    }
  });
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
      },
      {
        name: "get_diff",
        description: "Get pending diff content by hash",
        inputSchema: {
          type: "object",
          properties: {
            hash: { type: "string", description: "Diff hash" }
          },
          required: ["hash"]
        }
      },
      {
        name: "respond_to_diff",
        description: "Respond to a diff preview (approve/reject)",
        inputSchema: {
          type: "object",
          properties: {
            hash: { type: "string", description: "Diff hash" },
            approved: { type: "boolean", description: "Whether to approve the diff" }
          },
          required: ["hash", "approved"]
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
    
    case "get_diff": {
      const { hash } = z.object({ hash: z.string() }).parse(args);
      const diff = pendingDiffs.get(hash);
      
      if (diff) {
        return {
          content: [{
            type: "text",
            text: JSON.stringify({
              filepath: diff.filepath,
              original: diff.original,
              modified: diff.modified
            })
          }]
        };
      } else {
        return {
          content: [{
            type: "text",
            text: JSON.stringify({ error: "Diff not found" })
          }]
        };
      }
    }
    
    case "respond_to_diff": {
      const { hash, approved } = z.object({ 
        hash: z.string(), 
        approved: z.boolean() 
      }).parse(args);
      
      const diff = pendingDiffs.get(hash);
      if (diff && (diff as any).resolver) {
        (diff as any).resolver(approved);
        return {
          content: [{
            type: "text",
            text: `Diff ${approved ? "approved" : "rejected"}`
          }]
        };
      } else {
        return {
          content: [{
            type: "text",
            text: "No pending diff found"
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