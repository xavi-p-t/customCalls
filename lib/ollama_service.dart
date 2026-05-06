import 'dart:convert';
import 'package:http/http.dart' as http;

class OllamaService {
  final String baseUrl = "http://localhost:11434/api/chat"; 

  Future<Map<String, dynamic>> sendWithTools(String message) async {
    final tools = [
      //entrar en directorios
      {
        "type": "function",
        "function": {
          "name": "cambiar_directorio",
          "description": "Entra dentro de una carpeta específica o vuelve atrás.",
          "parameters": {
            "type": "object",
            "properties": {
              "carpeta": {
                "type": "string",
                "description": "Nombre de la carpeta a la que entrar. Usa 'atras' para subir un nivel."
              }
            },
            "required": ["carpeta"]
          }
        }
      },
      //crear carpetas
      {
        "type": "function",
        "function": {
          "name": "crear_carpeta",
          "description": "Crea una nueva carpeta en el servidor remoto.",
          "parameters": {
            "type": "object",
            "properties": {
              "nombre": { "type": "string" }
            },
            "required": ["nombre"]
          }
        }
      },
      //eliminar cosas
      {
        "type": "function",
        "function": {
          "name": "eliminar_elemento",
          "description": "Elimina un archivo o carpeta existente en el servidor remoto.",
          "parameters": {
            "type": "object",
            "properties": {
              "nombre": { "type": "string" }
            },
            "required": ["nombre"]
          }
        }
      },
      //info de archivos
      {
        "type": "function",
        "function": {
          "name": "info_archivo",
          "description": "Muestra los detalles, tamaño y permisos de un archivo o carpeta.",
          "parameters": {
            "type": "object",
            "properties": {
              "nombre": { "type": "string" }
            },
            "required": ["nombre"]
          }
        }
      },
      //descargar
      {
        "type": "function",
        "function": {
          "name": "descargar_archivo",
          "description": "Descarga un archivo remoto al dispositivo local.",
          "parameters": {
            "type": "object",
            "properties": {
              "nombre": { "type": "string", "description": "Nombre del archivo a descargar." }
            },
            "required": ["nombre"]
          }
        }
      },
      // añadir, borrar, ejecutar, parar servers
      {
        "type": "function",
        "function": {
          "name": "gestionar_pm2",
          "description": "Gestiona aplicaciones Node.js usando PM2 (añadir, borrar, iniciar, detener).",
          "parameters": {
            "type": "object",
            "properties": {
              "accion": { 
                "type": "string", 
                "enum": ["añadir", "borrar", "iniciar", "detener", "estado"],
                "description": "La acción a realizar." 
              },
              "nombre_app": { 
                "type": "string", 
                "description": "El nombre de la aplicación (ej: servidor_tanques)." 
              },
              "ruta": { 
                "type": "string", 
                "description": "La ruta donde está el archivo. Requerido solo para 'añadir'." 
              },
              "script": { 
                "type": "string", 
                "description": "El archivo a ejecutar (ej: app.js). Por defecto es app.js." 
              }
            },
            "required": ["accion", "nombre_app"]
          }
        }
      },
      //redireccion
      {
        "type": "function",
        "function": {
          "name": "redireccionar_puerto",
          "description": "Redirige el tráfico de un puerto de origen a un puerto de destino en el servidor.",
          "parameters": {
            "type": "object",
            "properties": {
              "puerto_origen": { 
                "type": "integer", 
                "description": "El puerto inicial que se quiere redirigir (ej: 3000)." 
              },
              "puerto_destino": { 
                "type": "integer", 
                "description": "El puerto final al que llegará el tráfico (ej: 80)." 
              }
            },
            "required": ["puerto_origen", "puerto_destino"]
          }
        }
      },
      //cambiar la vista
      {
        "type": "function",
        "function": {
          "name": "mostrar_baobab",
          "description": "Navega a la vista de almacenamiento gráfico (estilo baobab) para ver el peso de las carpetas.",
          "parameters": {
            "type": "object",
            "properties": {},
            "required": []
          }
        }
      }
    ];
    //preparar la IA
    final requestBody = {
      "model": "llama3.1", 
      "messages": [
        {
          "role": "system", 
          "content": "Eres un asistente del gestor BXDrive. Puedes gestionar archivos remotos y configuraciones. Para gestionar servidores usa PM2. Si te piden redireccionar puertos de una app (ej: tanques) hacia el puerto 80 u otro, usa redireccionar_puerto. Si no te especifican cuál es el puerto original de la app, pregúntaselo primero."},
        {"role": "user", "content": message}
      ],
      "tools": tools,
      "stream": false
    };

    try {
      final response = await http.post(
        Uri.parse(baseUrl),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode(requestBody),
      );

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      } else {
        throw Exception("Error HTTP: ${response.statusCode}");
      }
    } catch (e) {
      return {"error": true, "message": "No se pudo conectar con la IA: $e"};
    }
  }
}