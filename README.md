# Alpha Vantage MCP Server Configuration

This project uses **MCP (Model Context Protocol)** to modularize logic for interacting with external services such as [Alpha Vantage](https://www.alphavantage.co/).

Each MCP server is responsible for handling a specific context — such as market data — and exposes a well-defined protocol for communicating with it.

## 🔧 Configuration

To enable the Alpha Vantage MCP server, define it under the `mcpServers` section in your configuration file:

```json
{
  "mcpServers": {
    "alpha-vantage": {
      "command": "/path/to/dart/sdk/bin/dart",
      "args": ["run", "av_mcp_server"],
      "cwd": "/path/to/your/av_mcp_server"
    }
  }
}

```

[Get Dart SDK](https://dart.dev/get-dart)

From inside the MCP server directory, you can test it manually with:
```code
dart pub get
dart run av_mcp_server
```
