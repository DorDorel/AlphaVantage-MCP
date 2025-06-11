import 'dart:convert';
import 'package:http/http.dart' as http;

const String baseUrl = 'https://www.alphavantage.co/query?';

class AlphaVantageService {
  final String apiKey;
  final http.Client client;

  AlphaVantageService(this.apiKey, [http.Client? client])
    : client = client ?? http.Client();

  Future<Map<String, dynamic>> getIntraday(String symbol) async {
    final uri = Uri.parse(
      '${baseUrl}function=TIME_SERIES_INTRADAY&symbol=$symbol&interval=5min&apikey=$apiKey',
    );

    final response = await client.get(uri);

    if (response.statusCode == 200) {
      final data = json.decode(response.body) as Map<String, dynamic>;
      
      if (data.containsKey('Error Message')) {
        throw Exception('Alpha Vantage API Error: ${data['Error Message']}');
      }
      
      if (data.containsKey('Note')) {
        throw Exception('Alpha Vantage API Note: ${data['Note']}');
      }
      
      return data;
    } else {
      throw Exception('Failed to fetch intraday data: ${response.statusCode}');
    }
  }

  void dispose() {
    client.close();
  }
}