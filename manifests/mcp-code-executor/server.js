#!/usr/bin/env node

/**
 * Code Execution MCP Server
 *
 * Token-efficient MCP server that executes Python code with pre-configured API clients.
 * Focused on Portainer initially, expandable to other services.
 *
 * Token cost: ~200 tokens (vs 10,000+ with specific tools)
 */

const { Server } = require('@modelcontextprotocol/sdk/server/index.js');
const { StdioServerTransport } = require('@modelcontextprotocol/sdk/server/stdio.js');
const { SSEServerTransport } = require('@modelcontextprotocol/sdk/server/sse.js');
const {
  ListToolsRequestSchema,
  CallToolRequestSchema,
} = require('@modelcontextprotocol/sdk/types.js');
const express = require('express');
const { spawn } = require('child_process');
const path = require('path');
const fs = require('fs');

const SERVER_PORT = process.env.PORT || 3020;
const TRANSPORT_MODE = process.env.TRANSPORT_MODE || 'http';

class CodeExecutionMCPServer {
  constructor() {
    this.server = new Server(
      {
        name: 'k3s-code-executor',
        version: '1.0.0',
      },
      {
        capabilities: {
          tools: {},
        },
      }
    );

    this.activityLog = [];
    this.maxLogSize = 1000;
    this.setupHandlers();
  }

  logActivity(activity) {
    this.activityLog.unshift({
      id: Date.now(),
      timestamp: new Date().toISOString(),
      ...activity
    });

    if (this.activityLog.length > this.maxLogSize) {
      this.activityLog.pop();
    }

    console.error(`[Activity] ${activity.tool} - ${activity.status} - ${activity.duration}ms`);
  }

  setupHandlers() {
    // List available tools
    this.server.setRequestHandler(ListToolsRequestSchema, async () => {
      return {
        tools: [
          {
            name: 'execute_python',
            description: `Execute Python code with access to Portainer API client.

Available modules in sandbox:
- portainer_client (as 'pc'): Pre-authenticated Portainer client
  - pc.get_status() - Server status
  - pc.list_endpoints() - List Docker/K8s endpoints
  - pc.list_containers(endpoint_id=1, all=True) - List containers
  - pc.get_container(endpoint_id, container_id) - Get container details
  - pc.list_stacks(endpoint_id=None) - List stacks
  - pc.list_images(endpoint_id=1) - List images
  - pc.list_volumes(endpoint_id=1) - List volumes
  - pc.list_networks(endpoint_id=1) - List networks
  - pc.container_logs(endpoint_id, container_id, tail=100) - Get logs
  - pc.start_container(endpoint_id, container_id) - Start container
  - pc.stop_container(endpoint_id, container_id) - Stop container
  - pc.restart_container(endpoint_id, container_id) - Restart container

Example:
  # List all running nginx containers
  containers = pc.list_containers(endpoint_id=1, all=False)
  nginx_containers = [c for c in containers if 'nginx' in c['Image']]
  return [{'name': c['Names'][0], 'status': c['Status']} for c in nginx_containers]

Returns: Only the final result/summary (not intermediate data)`,
            inputSchema: {
              type: 'object',
              properties: {
                code: {
                  type: 'string',
                  description: 'Python code to execute. Must return or print the final result.',
                },
              },
              required: ['code'],
            },
          },
        ],
      };
    });

    // Handle tool calls
    this.server.setRequestHandler(CallToolRequestSchema, async (request) => {
      const { name, arguments: args } = request.params;
      const startTime = Date.now();

      try {
        if (name === 'execute_python') {
          const result = await this.executePython(args.code);
          const duration = Date.now() - startTime;

          this.logActivity({
            tool: 'execute_python',
            code_length: args.code.length,
            status: 'success',
            duration,
          });

          return {
            content: [
              {
                type: 'text',
                text: result,
              },
            ],
          };
        }

        throw new Error(`Unknown tool: ${name}`);
      } catch (error) {
        const duration = Date.now() - startTime;

        this.logActivity({
          tool: name,
          status: 'error',
          error: error.message,
          duration,
        });

        return {
          content: [
            {
              type: 'text',
              text: `Error executing code: ${error.message}`,
            },
          ],
          isError: true,
        };
      }
    });
  }

  async executePython(code) {
    return new Promise((resolve, reject) => {
      // Create temporary Python script
      const scriptPath = path.join(__dirname, `exec_${Date.now()}.py`);

      // Wrap user code to import portainer_client
      const wrappedCode = `
import sys
import json
import portainer_client as pc

# User code
${code}
`;

      fs.writeFileSync(scriptPath, wrappedCode);

      // Execute Python script
      const python = spawn('python3', [scriptPath], {
        env: {
          ...process.env,
          PYTHONPATH: __dirname,
        },
      });

      let stdout = '';
      let stderr = '';

      python.stdout.on('data', (data) => {
        stdout += data.toString();
      });

      python.stderr.on('data', (data) => {
        stderr += data.toString();
      });

      python.on('close', (code) => {
        // Clean up temp file
        try {
          fs.unlinkSync(scriptPath);
        } catch (e) {
          // Ignore cleanup errors
        }

        if (code !== 0) {
          reject(new Error(stderr || `Python exited with code ${code}`));
        } else {
          resolve(stdout || stderr || 'Code executed successfully (no output)');
        }
      });

      python.on('error', (error) => {
        // Clean up temp file
        try {
          fs.unlinkSync(scriptPath);
        } catch (e) {
          // Ignore cleanup errors
        }
        reject(error);
      });
    });
  }

  async run() {
    if (TRANSPORT_MODE === 'http') {
      // HTTP/SSE transport for remote access
      const app = express();

      app.get('/health', (req, res) => {
        res.json({
          status: 'healthy',
          version: '1.0.0',
          transport: 'sse',
          tools: ['execute_python'],
        });
      });

      // Dashboard API endpoints
      app.get('/api/logs', (req, res) => {
        res.json({
          activities: this.activityLog.slice(0, 100),
          total: this.activityLog.length,
        });
      });

      app.post('/mcp', async (req, res) => {
        const transport = new SSEServerTransport('/mcp', res);
        await this.server.connect(transport);
      });

      app.listen(SERVER_PORT, () => {
        console.error(`Code Execution MCP Server listening on port ${SERVER_PORT}`);
        console.error(`Health check: http://localhost:${SERVER_PORT}/health`);
        console.error(`MCP endpoint: http://localhost:${SERVER_PORT}/mcp`);
        console.error(`Tools: execute_python (with Portainer client)`);
      });
    } else {
      // Stdio transport for local use
      const transport = new StdioServerTransport();
      await this.server.connect(transport);
      console.error('Code Execution MCP Server running in stdio mode');
    }
  }
}

// Start server
const server = new CodeExecutionMCPServer();
server.run().catch((error) => {
  console.error('Failed to start server:', error);
  process.exit(1);
});
