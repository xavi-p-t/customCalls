import 'dart:convert';
import 'package:http/http.dart' as http;

class OllamaService {
  final String baseUrl = "http://localhost:11434/api/generate";
  final String model = "llama3"; // O el modelo que tengas descargado (mistral, gemma, etc.)

  Future<String> askIA(String prompt) async {
    try {
      final response = await http.post(
        Uri.parse(baseUrl),
        body: jsonEncode({
          "model": model,
          "prompt": prompt,
          "stream": false, // Para recibir la respuesta completa de una vez
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data['response'];
      } else {
        return "Error de Ollama: ${response.statusCode}";
      }
    } catch (e) {
      return "No se pudo conectar con Ollama. ¿Está el servidor corriendo?";
    }
  }
}