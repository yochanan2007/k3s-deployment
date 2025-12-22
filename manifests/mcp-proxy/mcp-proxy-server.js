#!/usr/bin/env node

/**
 * K3s MCP Proxy Server
 *
 * This server implements the Model Context Protocol (MCP) to provide
 * programmatic access to all services running in the k3s cluster.
 *
 * It exposes tools for:
 * - AdGuard Home (DNS filtering)
 * - Authentik (SSO/Identity)
 * - PostgreSQL (Database)
 * - RustDesk (Remote desktop)
 * - Rancher (Cluster management)
 * - Kubernetes API (Cluster operations)
 *
 * Configuration is fetched from GitHub using GitOps pattern.
 */

const { Server } = require('@modelcontextprotocol/sdk/server/index.js');
const { StdioServerTransport } = require('@modelcontextprotocol/sdk/server/stdio.js');
const { SSEServerTransport } = require('@modelcontextprotocol/sdk/server/sse.js');
const {
  ListToolsRequestSchema,
  CallToolRequestSchema,
  ListResourcesRequestSchema,
  ReadResourceRequestSchema
} = require('@modelcontextprotocol/sdk/types.js');
const express = require('express');
const axios = require('axios');
const { exec } = require('child_process');
const { promisify } = require('util');

const execAsync = promisify(exec);

// Environment configuration
const CONFIG_REPO_URL = process.env.CONFIG_REPO_URL || 'https://raw.githubusercontent.com/yourusername/k3s-deployment/main/mcp-proxy-config.json';
const SERVER_PORT = process.env.PORT || 3010;
const TRANSPORT_MODE = process.env.TRANSPORT_MODE || 'http'; // 'stdio' or 'http'

// Service endpoints (internal cluster DNS)
const SERVICES = {
  adguard: {
    url: 'http://adguard.adguard.svc.cluster.local',
    port: 80
  },
  authentik: {
    url: 'http://authentik.authentik.svc.cluster.local',
    port: 80
  },
  postgresql: {
    url: 'postgresql://postgresql.authentik.svc.cluster.local:5432',
    port: 5432
  },
  rancher: {
    url: 'http://rancher.cattle-system.svc.cluster.local',
    port: 80
  },
  kubernetes: {
    url: 'https://kubernetes.default.svc.cluster.local',
    port: 443
  }
};

class K3sMCPProxyServer {
  constructor() {
    this.server = new Server(
      {
        name: 'k3s-mcp-proxy',
        version: '1.0.0',
      },
      {
        capabilities: {
          tools: {},
          resources: {},
        },
      }
    );

    this.config = null;
    this.setupHandlers();
  }

  async loadConfig() {
    try {
      const response = await axios.get(CONFIG_REPO_URL);
      this.config = response.data;
      console.error('Configuration loaded from:', CONFIG_REPO_URL);
    } catch (error) {
      console.error('Failed to load config from GitHub, using defaults:', error.message);
      this.config = this.getDefaultConfig();
    }
  }

  getDefaultConfig() {
    return {
      services: SERVICES,
      tools: {
        adguard_enabled: true,
        authentik_enabled: true,
        postgres_enabled: true,
        kubernetes_enabled: true,
        rancher_enabled: true
      }
    };
  }

  setupHandlers() {
    // List available tools
    this.server.setRequestHandler(ListToolsRequestSchema, async () => {
      const tools = [];

      // Kubernetes tools
      if (this.config?.tools?.kubernetes_enabled !== false) {
        tools.push(
          {
            name: 'k8s_get_pods',
            description: 'List all pods in a namespace or across all namespaces',
            inputSchema: {
              type: 'object',
              properties: {
                namespace: {
                  type: 'string',
                  description: 'Namespace to query (omit for all namespaces)',
                },
              },
            },
          },
          {
            name: 'k8s_get_services',
            description: 'List all services in a namespace or across all namespaces',
            inputSchema: {
              type: 'object',
              properties: {
                namespace: {
                  type: 'string',
                  description: 'Namespace to query (omit for all namespaces)',
                },
              },
            },
          },
          {
            name: 'k8s_get_deployments',
            description: 'List all deployments in a namespace or across all namespaces',
            inputSchema: {
              type: 'object',
              properties: {
                namespace: {
                  type: 'string',
                  description: 'Namespace to query (omit for all namespaces)',
                },
              },
            },
          },
          {
            name: 'k8s_describe_resource',
            description: 'Get detailed information about a specific Kubernetes resource',
            inputSchema: {
              type: 'object',
              properties: {
                resource_type: {
                  type: 'string',
                  description: 'Type of resource (pod, service, deployment, etc.)',
                },
                name: {
                  type: 'string',
                  description: 'Name of the resource',
                },
                namespace: {
                  type: 'string',
                  description: 'Namespace of the resource',
                },
              },
              required: ['resource_type', 'name', 'namespace'],
            },
          }
        );
      }

      // AdGuard Home tools
      if (this.config?.tools?.adguard_enabled !== false) {
        tools.push(
          {
            name: 'adguard_get_status',
            description: 'Get AdGuard Home server status and statistics',
            inputSchema: {
              type: 'object',
              properties: {},
            },
          },
          {
            name: 'adguard_query_log',
            description: 'Query AdGuard Home DNS query log',
            inputSchema: {
              type: 'object',
              properties: {
                limit: {
                  type: 'number',
                  description: 'Number of entries to retrieve (default: 100)',
                },
              },
            },
          }
        );
      }

      // PostgreSQL tools
      if (this.config?.tools?.postgres_enabled !== false) {
        tools.push(
          {
            name: 'postgres_query',
            description: 'Execute a SELECT query on PostgreSQL database',
            inputSchema: {
              type: 'object',
              properties: {
                database: {
                  type: 'string',
                  description: 'Database name (default: authentik)',
                },
                query: {
                  type: 'string',
                  description: 'SQL SELECT query to execute',
                },
              },
              required: ['query'],
            },
          },
          {
            name: 'postgres_list_tables',
            description: 'List all tables in a PostgreSQL database',
            inputSchema: {
              type: 'object',
              properties: {
                database: {
                  type: 'string',
                  description: 'Database name (default: authentik)',
                },
              },
            },
          }
        );
      }

      // Authentik tools
      if (this.config?.tools?.authentik_enabled !== false) {
        tools.push(
          {
            name: 'authentik_get_users',
            description: 'List users in Authentik SSO system',
            inputSchema: {
              type: 'object',
              properties: {
                search: {
                  type: 'string',
                  description: 'Search term to filter users',
                },
              },
            },
          },
          {
            name: 'authentik_get_applications',
            description: 'List applications configured in Authentik',
            inputSchema: {
              type: 'object',
              properties: {},
            },
          }
        );
      }

      // Rancher tools
      if (this.config?.tools?.rancher_enabled !== false) {
        tools.push(
          {
            name: 'rancher_get_clusters',
            description: 'List all clusters managed by Rancher',
            inputSchema: {
              type: 'object',
              properties: {},
            },
          }
        );
      }

      return { tools };
    });

    // Handle tool calls
    this.server.setRequestHandler(CallToolRequestSchema, async (request) => {
      const { name, arguments: args } = request.params;

      try {
        switch (name) {
          // Kubernetes tools
          case 'k8s_get_pods':
            return await this.k8sGetPods(args);
          case 'k8s_get_services':
            return await this.k8sGetServices(args);
          case 'k8s_get_deployments':
            return await this.k8sGetDeployments(args);
          case 'k8s_describe_resource':
            return await this.k8sDescribeResource(args);

          // AdGuard tools
          case 'adguard_get_status':
            return await this.adguardGetStatus(args);
          case 'adguard_query_log':
            return await this.adguardQueryLog(args);

          // PostgreSQL tools
          case 'postgres_query':
            return await this.postgresQuery(args);
          case 'postgres_list_tables':
            return await this.postgresListTables(args);

          // Authentik tools
          case 'authentik_get_users':
            return await this.authentikGetUsers(args);
          case 'authentik_get_applications':
            return await this.authentikGetApplications(args);

          // Rancher tools
          case 'rancher_get_clusters':
            return await this.rancherGetClusters(args);

          default:
            throw new Error(`Unknown tool: ${name}`);
        }
      } catch (error) {
        return {
          content: [
            {
              type: 'text',
              text: `Error executing ${name}: ${error.message}`,
            },
          ],
          isError: true,
        };
      }
    });

    // List available resources
    this.server.setRequestHandler(ListResourcesRequestSchema, async () => {
      return {
        resources: [
          {
            uri: 'k3s://cluster/status',
            name: 'Cluster Status',
            description: 'Overall k3s cluster health and status',
            mimeType: 'application/json',
          },
          {
            uri: 'k3s://services/all',
            name: 'All Services',
            description: 'Complete list of all services across all namespaces',
            mimeType: 'application/json',
          },
        ],
      };
    });

    // Read resources
    this.server.setRequestHandler(ReadResourceRequestSchema, async (request) => {
      const { uri } = request.params;

      if (uri === 'k3s://cluster/status') {
        const status = await this.getClusterStatus();
        return {
          contents: [
            {
              uri,
              mimeType: 'application/json',
              text: JSON.stringify(status, null, 2),
            },
          ],
        };
      }

      if (uri === 'k3s://services/all') {
        const services = await this.k8sGetServices({ namespace: '' });
        return {
          contents: [
            {
              uri,
              mimeType: 'application/json',
              text: services.content[0].text,
            },
          ],
        };
      }

      throw new Error(`Unknown resource: ${uri}`);
    });
  }

  // Kubernetes tool implementations
  async k8sGetPods(args) {
    const namespace = args.namespace ? `-n ${args.namespace}` : '-A';
    const { stdout } = await execAsync(`kubectl get pods ${namespace} -o json`);
    const pods = JSON.parse(stdout);

    return {
      content: [
        {
          type: 'text',
          text: JSON.stringify(pods, null, 2),
        },
      ],
    };
  }

  async k8sGetServices(args) {
    const namespace = args.namespace ? `-n ${args.namespace}` : '-A';
    const { stdout } = await execAsync(`kubectl get services ${namespace} -o json`);
    const services = JSON.parse(stdout);

    return {
      content: [
        {
          type: 'text',
          text: JSON.stringify(services, null, 2),
        },
      ],
    };
  }

  async k8sGetDeployments(args) {
    const namespace = args.namespace ? `-n ${args.namespace}` : '-A';
    const { stdout } = await execAsync(`kubectl get deployments ${namespace} -o json`);
    const deployments = JSON.parse(stdout);

    return {
      content: [
        {
          type: 'text',
          text: JSON.stringify(deployments, null, 2),
        },
      ],
    };
  }

  async k8sDescribeResource(args) {
    const { resource_type, name, namespace } = args;
    const { stdout } = await execAsync(`kubectl describe ${resource_type} ${name} -n ${namespace}`);

    return {
      content: [
        {
          type: 'text',
          text: stdout,
        },
      ],
    };
  }

  // AdGuard tool implementations
  async adguardGetStatus(args) {
    try {
      const response = await axios.get(`${SERVICES.adguard.url}/control/status`);
      return {
        content: [
          {
            type: 'text',
            text: JSON.stringify(response.data, null, 2),
          },
        ],
      };
    } catch (error) {
      return {
        content: [
          {
            type: 'text',
            text: `AdGuard API not accessible: ${error.message}`,
          },
        ],
        isError: true,
      };
    }
  }

  async adguardQueryLog(args) {
    const limit = args.limit || 100;
    try {
      const response = await axios.get(`${SERVICES.adguard.url}/control/querylog`, {
        params: { limit },
      });
      return {
        content: [
          {
            type: 'text',
            text: JSON.stringify(response.data, null, 2),
          },
        ],
      };
    } catch (error) {
      return {
        content: [
          {
            type: 'text',
            text: `AdGuard API not accessible: ${error.message}`,
          },
        ],
        isError: true,
      };
    }
  }

  // PostgreSQL tool implementations
  async postgresQuery(args) {
    const database = args.database || 'authentik';
    const query = args.query;

    // Note: In production, use proper PostgreSQL client library
    // This is a simplified example
    const { stdout } = await execAsync(
      `kubectl exec -n authentik postgresql-0 -- psql -U authentik -d ${database} -c "${query}" -t`
    );

    return {
      content: [
        {
          type: 'text',
          text: stdout,
        },
      ],
    };
  }

  async postgresListTables(args) {
    const database = args.database || 'authentik';

    const { stdout } = await execAsync(
      `kubectl exec -n authentik postgresql-0 -- psql -U authentik -d ${database} -c "\\dt" -t`
    );

    return {
      content: [
        {
          type: 'text',
          text: stdout,
        },
      ],
    };
  }

  // Authentik tool implementations
  async authentikGetUsers(args) {
    // Note: Requires API token configuration
    const search = args.search || '';
    try {
      const response = await axios.get(`${SERVICES.authentik.url}/api/v3/core/users/`, {
        params: { search },
        headers: {
          Authorization: `Bearer ${process.env.AUTHENTIK_API_TOKEN || ''}`,
        },
      });
      return {
        content: [
          {
            type: 'text',
            text: JSON.stringify(response.data, null, 2),
          },
        ],
      };
    } catch (error) {
      return {
        content: [
          {
            type: 'text',
            text: `Authentik API not accessible: ${error.message}. Ensure AUTHENTIK_API_TOKEN is set.`,
          },
        ],
        isError: true,
      };
    }
  }

  async authentikGetApplications(args) {
    try {
      const response = await axios.get(`${SERVICES.authentik.url}/api/v3/core/applications/`, {
        headers: {
          Authorization: `Bearer ${process.env.AUTHENTIK_API_TOKEN || ''}`,
        },
      });
      return {
        content: [
          {
            type: 'text',
            text: JSON.stringify(response.data, null, 2),
          },
        ],
      };
    } catch (error) {
      return {
        content: [
          {
            type: 'text',
            text: `Authentik API not accessible: ${error.message}. Ensure AUTHENTIK_API_TOKEN is set.`,
          },
        ],
        isError: true,
      };
    }
  }

  // Rancher tool implementations
  async rancherGetClusters(args) {
    try {
      const response = await axios.get(`${SERVICES.rancher.url}/v3/clusters`, {
        headers: {
          Authorization: `Bearer ${process.env.RANCHER_API_TOKEN || ''}`,
        },
      });
      return {
        content: [
          {
            type: 'text',
            text: JSON.stringify(response.data, null, 2),
          },
        ],
      };
    } catch (error) {
      return {
        content: [
          {
            type: 'text',
            text: `Rancher API not accessible: ${error.message}. Ensure RANCHER_API_TOKEN is set.`,
          },
        ],
        isError: true,
      };
    }
  }

  // Helper methods
  async getClusterStatus() {
    try {
      const { stdout: nodesOutput } = await execAsync('kubectl get nodes -o json');
      const nodes = JSON.parse(nodesOutput);

      const { stdout: podsOutput } = await execAsync('kubectl get pods -A -o json');
      const pods = JSON.parse(podsOutput);

      return {
        nodes: nodes.items.length,
        total_pods: pods.items.length,
        running_pods: pods.items.filter(p => p.status.phase === 'Running').length,
        services: Object.keys(SERVICES),
        timestamp: new Date().toISOString(),
      };
    } catch (error) {
      return {
        error: error.message,
        timestamp: new Date().toISOString(),
      };
    }
  }

  async run() {
    await this.loadConfig();

    if (TRANSPORT_MODE === 'http') {
      // HTTP/SSE transport for remote access
      const app = express();

      app.get('/health', (req, res) => {
        res.json({ status: 'healthy', version: '1.0.0' });
      });

      app.post('/mcp', async (req, res) => {
        const transport = new SSEServerTransport('/mcp', res);
        await this.server.connect(transport);
      });

      app.listen(SERVER_PORT, () => {
        console.error(`MCP Proxy Server listening on port ${SERVER_PORT}`);
        console.error(`Health check: http://localhost:${SERVER_PORT}/health`);
        console.error(`MCP endpoint: http://localhost:${SERVER_PORT}/mcp`);
      });
    } else {
      // Stdio transport for local use
      const transport = new StdioServerTransport();
      await this.server.connect(transport);
      console.error('MCP Proxy Server running in stdio mode');
    }
  }
}

// Start server
const server = new K3sMCPProxyServer();
server.run().catch((error) => {
  console.error('Failed to start server:', error);
  process.exit(1);
});
