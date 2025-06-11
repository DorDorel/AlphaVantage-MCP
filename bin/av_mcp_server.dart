import 'dart:convert';
import 'dart:io';
import 'package:av_mcp_server/av_mcp_server.dart';
import 'package:dotenv/dotenv.dart';

class MCPServer {
  final AlphaVantageService _avService;
  
  MCPServer(this._avService);

  void start() {
    stdin.transform(utf8.decoder).transform(LineSplitter()).listen((line) {
      if (line.isNotEmpty) {
        _handleRequest(line);
      }
    });
  }

  void _handleRequest(String jsonLine) async {
    try {
      final request = jsonDecode(jsonLine) as Map<String, dynamic>;
      final response = await _processRequest(request);
      
      // Send response to stdout
      stdout.writeln(jsonEncode(response));
    } catch (e) {
      // Send error response
      final errorResponse = {
        'jsonrpc': '2.0',
        'id': null,
        'error': {
          'code': -32700,
          'message': 'Parse error',
          'data': e.toString(),
        }
      };
      stdout.writeln(jsonEncode(errorResponse));
    }
  }

  Future<Map<String, dynamic>> _processRequest(Map<String, dynamic> request) async {
    final id = request['id'];
    final method = request['method'] as String?;
    final params = request['params'] as Map<String, dynamic>? ?? {};

    try {
      switch (method) {
        case 'initialize':
          return _handleInitialize(id);
        
        case 'tools/list':
          return _handleToolsList(id);
        
        case 'tools/call':
          return await _handleToolCall(id, params);
        
        default:
          return {
            'jsonrpc': '2.0',
            'id': id,
            'error': {
              'code': -32601,
              'message': 'Method not found',
            }
          };
      }
    } catch (e) {
      return {
        'jsonrpc': '2.0',
        'id': id,
        'error': {
          'code': -32603,
          'message': 'Internal error',
          'data': e.toString(),
        }
      };
    }
  }

  Map<String, dynamic> _handleInitialize(dynamic id) {
    return {
      'jsonrpc': '2.0',
      'id': id,
      'result': {
        'protocolVersion': '2024-11-05',
        'capabilities': {
          'tools': {}
        },
        'serverInfo': {
          'name': 'alpha-vantage-mcp-server',
          'version': '1.0.0'
        }
      }
    };
  }

  Map<String, dynamic> _handleToolsList(dynamic id) {
    return {
      'jsonrpc': '2.0',
      'id': id,
      'result': {
        'tools': [
          {
            'name': 'get_stock_intraday',
            'description': 'Get intraday stock price data from Alpha Vantage',
            'inputSchema': {
              'type': 'object',
              'properties': {
                'symbol': {
                  'type': 'string',
                  'description': 'Stock symbol (e.g., AAPL, GOOGL)'
                }
              },
              'required': ['symbol']
            }
          }
        ]
      }
    };
  }

  Future<Map<String, dynamic>> _handleToolCall(dynamic id, Map<String, dynamic> params) async {
    final name = params['name'] as String?;
    final arguments = params['arguments'] as Map<String, dynamic>? ?? {};

    switch (name) {
      case 'get_stock_intraday':
        final symbol = arguments['symbol'] as String?;
        if (symbol == null) {
          return {
            'jsonrpc': '2.0',
            'id': id,
            'error': {
              'code': -32602,
              'message': 'Invalid params: symbol is required',
            }
          };
        }

        try {
          final data = await _avService.getIntraday(symbol);
          
          final timeSeries = data['Time Series (5min)'] as Map<String, dynamic>?;
          final metaData = data['Meta Data'] as Map<String, dynamic>?;
          
          if (timeSeries == null || timeSeries.isEmpty) {
            return {
              'jsonrpc': '2.0',
              'id': id,
              'result': {
                'content': [
                  {
                    'type': 'text',
                    'text': 'No intraday data found for symbol: $symbol'
                  }
                ]
              }
            };
          }

          final latestTime = timeSeries.keys.first;
          final latestData = timeSeries[latestTime] as Map<String, dynamic>;
          
          final result = {
            'symbol': symbol,
            'lastRefreshed': metaData?['3. Last Refreshed'] ?? latestTime,
            'latestPrice': {
              'time': latestTime,
              'open': latestData['1. open'],
              'high': latestData['2. high'],
              'low': latestData['3. low'],
              'close': latestData['4. close'],
              'volume': latestData['5. volume']
            },
            'recentData': timeSeries.entries.take(5).map((entry) => {
              'time': entry.key,
              'data': entry.value
            }).toList()
          };

          return {
            'jsonrpc': '2.0',
            'id': id,
            'result': {
              'content': [
                {
                  'type': 'text',
                  'text': 'Stock data for $symbol:\n${jsonEncode(result)}'
                }
              ]
            }
          };
        } catch (e) {
          return {
            'jsonrpc': '2.0',
            'id': id,
            'error': {
              'code': -32603,
              'message': 'Failed to fetch stock data',
              'data': e.toString(),
            }
          };
        }

      default:
        return {
          'jsonrpc': '2.0',
          'id': id,
          'error': {
            'code': -32601,
            'message': 'Tool not found: $name',
          }
        };
    }
  }
}

void main() async {
  final env = DotEnv()..load();
  final apiKey = env['ALPHA_VANTAGE_API_KEY'];
  
  if (apiKey == null) {
    stderr.writeln('ALPHA_VANTAGE_API_KEY not found in environment');
    exit(1);
  }

  final avService = AlphaVantageService(apiKey);
  final server = MCPServer(avService);
  
  server.start();
}