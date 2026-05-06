import 'package:flutter/material.dart';
import 'package:bxdrive/ServerControlWidget.dart';
import 'package:bxdrive/conection.dart';
import 'package:file_picker/file_picker.dart';
import 'package:bxdrive/widgetRedirect.dart';
import 'package:path_provider/path_provider.dart';
import 'package:bxdrive/ollama_service.dart';
import 'package:bxdrive/SaveServer.dart';
import 'package:bxdrive/almacenamientoView.dart';
import 'dart:io';
import 'package:path/path.dart' as p;

class ChatMessage {
  final String text;
  final bool isUser;
  ChatMessage({required this.text, required this.isUser});
}

class MenuArchivos extends StatefulWidget {
  final ServerConnectionManager connection;
  final VoidCallback onNavigateToAlmacenamiento; 

  const MenuArchivos({
    Key? key, 
    required this.connection,
    required this.onNavigateToAlmacenamiento, 
  }) : super(key: key);

  @override
  State<MenuArchivos> createState() => MenuArchivosState();
}

class MenuArchivosState extends State<MenuArchivos> {
  String currentPath = "//home/super";
  List<Map<String, String>> files = [];
  Map<int, bool> hoverStates = {};
  bool _isServerDetected = false;
  final OllamaService _ollamaService = OllamaService();
  
  List<ChatMessage> chatMessages = []; 
  bool _isIaTyping = false;
  final TextEditingController _iaController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _listFiles();
  }

  void _listFiles() async {
    try {
      List<Map<String, String>> remoteFiles = await widget.connection.listFiles(currentPath);
      setState(() {
        files = remoteFiles;
        hoverStates = {for (int i = 0; i < files.length; i++) i: false};
      });
    } catch (e) {
      print("Error al obtener archivos: $e");
    }
  }

  void _changeDirectory(String newPath) {
    if (newPath != "/") {
      setState(() {
        currentPath = newPath;
        _listFiles();
      });
    }
  }

  void listFiles() {
    _listFiles();
  }

  void _goBack() {
    String normalizedPath = currentPath.replaceAll('\\', '/');
    if (normalizedPath != "/") {
      String parentPath = p.posix.dirname(normalizedPath);
      if (parentPath == "." || parentPath.isEmpty) {
        parentPath = "/";
      }
      setState(() {
        currentPath = parentPath;
        _listFiles();
      });
    }
  }

  Future<void> _deleteFile(String fileName) async {
    try {
      await widget.connection.deleteFile("$currentPath/$fileName");
      _listFiles();
    } catch (e) {
      print("Error al eliminar archivo: $e");
    }
  }

  Future<void> _downloadFile(String fileName) async {
    try {
      final directory = await getApplicationDocumentsDirectory();
      String localPath = "${directory.path}/$fileName";
      await widget.connection.downloadFile("$currentPath/$fileName", localPath);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Archivo $fileName descargado en $localPath')),
      );
    } catch (e) {
      print("Error durante la descarga del archivo: $e");
    }
  }

  Future<void> _uploadFile() async {
    FilePickerResult? result = await FilePicker.platform.pickFiles();
    if (result != null) {
      String filePath = result.files.single.path!;
      String fileName = result.files.single.name;
      try {
        await widget.connection.uploadFile(filePath, "$currentPath/$fileName");
        _listFiles();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Archivo $fileName subido')),
        );
      } catch (e) {
        print("Error al subir archivo: $e");
      }
    }
  }

  Future<bool> isServerRunning() async {
    try {
      final result = await widget.connection
          .executeCommand("ps aux | grep 'node\\|java' | grep -v grep");
      return result.isNotEmpty;
    } catch (e) {
      print("Error verificando el servidor: $e");
      return false;
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  //gestionamos los mensajes ollama
  Future<void> _handleSendMessage() async {
    String text = _iaController.text.trim();
    if (text.isEmpty) return;

    setState(() {
      chatMessages.add(ChatMessage(text: text, isUser: true));
      _isIaTyping = true;
    });
    _iaController.clear();
    _scrollToBottom();

    try {
      final response = await _ollamaService.sendWithTools(text);

      if (response.containsKey("error")) {
        setState(() {
          chatMessages.add(ChatMessage(text: response["message"], isUser: false));
        });
        _scrollToBottom();
      } else {
        final messageData = response['message'];
        
        if (messageData != null && messageData['tool_calls'] != null && messageData['tool_calls'].isNotEmpty) {
          final toolCall = messageData['tool_calls'][0]['function'];
          final functionName = toolCall['name'];
          final Map<String, dynamic> arguments = toolCall['arguments'] ?? {};
          
          String resultText = "";
          
          try {
            switch (functionName) {
              
              case "listar_archivos":
                _listFiles();
                resultText = "He actualizado la lista de archivos para ti.";
                break;

              case "cambiar_directorio":
                String carpeta = arguments['carpeta'] ?? "";
                if (carpeta.toLowerCase() == "atras" || carpeta == "..") {
                  _goBack();
                  resultText = "He vuelto a la carpeta anterior.";
                } else {
                  _changeDirectory("$currentPath/$carpeta");
                  resultText = "He entrado en la carpeta '$carpeta'.";
                }
                break;

              case "agregar_servidor":
                final newUser = UserData(
                  name: arguments['name'],
                  server: arguments['server'],
                  port: arguments['port'].toString(),
                  key: arguments['key'],
                );
                List<UserData> users = await Storage.loadUserData();
                users.add(newUser);
                await Storage.saveUserData(users);
                resultText = "He guardado el servidor '${newUser.name}' en la configuración JSON.";
                break;

              case "borrar_servidor":
                String nameToDelete = arguments['name'];
                List<UserData> users = await Storage.loadUserData();
                int initialCount = users.length;
                users.removeWhere((u) => u.name.toLowerCase() == nameToDelete.toLowerCase());
                if (users.length < initialCount) {
                  await Storage.saveUserData(users);
                  resultText = "He eliminado '$nameToDelete' de tus servidores conocidos.";
                } else {
                  resultText = "No encontré ningún servidor llamado '$nameToDelete' en el JSON.";
                }
                break;

              case "crear_carpeta":
                String folderName = arguments['nombre'];
                await widget.connection.executeCommand('mkdir "$currentPath/$folderName"');
                _listFiles();
                resultText = "Se ha creado la carpeta '$folderName'.";
                break;

              case "eliminar_elemento":
                String itemName = arguments['nombre'];
                await _deleteFile(itemName);
                resultText = "Se ha eliminado '$itemName'.";
                break;

              case "info_archivo":
                String itemNameInfo = arguments['nombre'];
                String info = await widget.connection.showFileInfo("$currentPath/$itemNameInfo");
                resultText = "Aquí tienes la información de '$itemNameInfo':\n$info";
                break;

              case "descargar_archivo":
                String fileToDownload = arguments['nombre'];
                await _downloadFile(fileToDownload);
                resultText = "He iniciado la descarga de '$fileToDownload'. Revisa tu carpeta de descargas local.";
                break;

              case "gestionar_pm2":
                String accion = arguments['accion'] ?? "";
                String nombreApp = arguments['nombre_app'] ?? "mi_app";
                String ruta = arguments['ruta'] ?? currentPath;
                String script = arguments['script'] ?? "app.js";

                resultText = await widget.connection.managePm2App(
                  accion, 
                  nombreApp, 
                  path: ruta, 
                  script: script
                );
                break;

              case "redireccionar_puerto":
               
                int puertoOrigen = int.tryParse(arguments['puerto_origen'].toString()) ?? 3000;
                int puertoDestino = int.tryParse(arguments['puerto_destino'].toString()) ?? 80;
                
                String cmd = "sudo iptables -t nat -A PREROUTING -p tcp --dport $puertoOrigen -j REDIRECT --to-port $puertoDestino";
                await widget.connection.executeCommand(cmd);
                
                resultText = "🔄 He activado la redirección: el tráfico del puerto $puertoOrigen va hacia el puerto $puertoDestino.";
                break;

              case "mostrar_baobab":
                widget.onNavigateToAlmacenamiento();
                resultText = "Cambiando a la vista de almacenamiento (Baobab)...";
                break;

              default:
                resultText = "La IA intentó ejecutar '$functionName', pero no lo reconozco.";
            }
          } catch (e) {
            resultText = "Hubo un error al ejecutar la acción: $e";
          }

          setState(() {
            chatMessages.add(ChatMessage(text: "⚙️ $resultText", isUser: false));
          });
          _scrollToBottom();
          
        } else {
          setState(() {
            chatMessages.add(ChatMessage(text: messageData['content'] ?? "", isUser: false));
          });
          _scrollToBottom();
        }
      }
    } catch (e) {
      setState(() {
        chatMessages.add(ChatMessage(text: "Excepción: $e", isUser: false));
      });
      _scrollToBottom();
    } finally {
      setState(() {
        _isIaTyping = false;
      });
      _scrollToBottom();
    }
  }

  Future<void> _renameFile(String oldName) async {
    TextEditingController _controller = TextEditingController(text: oldName);
    await showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text("Cambiar nombre"),
          content: TextField(
            controller: _controller,
            decoration: const InputDecoration(labelText: "Nuevo nombre"),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text("Cancelar"),
            ),
            TextButton(
              onPressed: () async {
                String newName = _controller.text.trim();
                if (newName.isNotEmpty && newName != oldName) {
                  try {
                    await widget.connection.renameFile(
                        "$currentPath/$oldName", "$currentPath/$newName");
                    _listFiles();
                  } catch (e) {
                    print("Error al renombrar: $e");
                  }
                }
                Navigator.of(context).pop();
              },
              child: const Text("Aceptar"),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        title: Row(
          children: [
            IconButton(
              icon: const Icon(Icons.arrow_back),
              onPressed: _goBack,
            ),
            Text("Archivos en $currentPath"),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.upload_file),
            onPressed: _uploadFile,
          ),
        ],
      ),
      body: Row( 
        children: [
          Expanded(
            flex: 3,
            child: Column(
              children: [
                ServerControlWidget(
                  serverPath: currentPath,
                  connectionManager: widget.connection,
                  onServerStateChanged: (serverInfo) async {
                    bool isRunning = await isServerRunning();
                    setState(() {
                      _isServerDetected = isRunning;
                    });
                  },
                ),
                if (_isServerDetected)
                  PortRedirectWidget(connection: widget.connection),
                Expanded(
                  child: files.isEmpty
                      ? const Center(child: CircularProgressIndicator())
                      : ListView.builder(
                          itemCount: files.length,
                          itemBuilder: (context, index) {
                            String name = files[index]["name"] ?? "Desconocido";
                            bool isDirectory = files[index]["type"] == "directory";

                            return MouseRegion(
                              onEnter: (_) => setState(() => hoverStates[index] = true),
                              onExit: (_) => setState(() => hoverStates[index] = false),
                              child: Container(
                                color: hoverStates[index] ?? false
                                    ? Colors.grey.shade200
                                    : Colors.transparent,
                                child: ListTile(
                                  leading: Icon(
                                    isDirectory ? Icons.folder : Icons.insert_drive_file,
                                    color: isDirectory ? Colors.blue : Colors.grey,
                                  ),
                                  title: Text(
                                    name,
                                    style: const TextStyle(fontWeight: FontWeight.bold),
                                  ),
                                  onTap: isDirectory
                                      ? () => _changeDirectory("$currentPath/$name")
                                      : null,
                                  trailing: hoverStates[index] ?? false
                                      ? Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            if (!isDirectory) ...[
                                              IconButton(
                                                icon: const Icon(Icons.download),
                                                onPressed: () => _downloadFile(name),
                                              ),
                                              IconButton(
                                                icon: const Icon(Icons.edit),
                                                onPressed: () => _renameFile(name),
                                              ),
                                              IconButton(
                                                icon: const Icon(Icons.delete),
                                                onPressed: () => _deleteFile(name),
                                              ),
                                            ],
                                          ],
                                        )
                                      : null,
                                ),
                              ),
                            );
                          },
                        ),
                ),
              ],
            ),
          ),
          
          const VerticalDivider(width: 1, thickness: 1),
          Container(
            width: 350, 
            color: Colors.grey.shade50,
            child: Column(
              children: [
                const Padding(
                  padding: EdgeInsets.all(16.0),
                  child: Text(
                    "Asistente IA",
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                ),
                
                Expanded(
                  child: chatMessages.isEmpty
                      ? const Center(
                          child: Text(
                            "Escribe un mensaje para empezar.",
                            style: TextStyle(color: Colors.grey),
                          ),
                        )
                      : ListView.builder(
                          controller: _scrollController,
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                          itemCount: chatMessages.length,
                          itemBuilder: (context, index) {
                            final msg = chatMessages[index];
                            return Align(
                              alignment: msg.isUser ? Alignment.centerRight : Alignment.centerLeft,
                              child: Container(
                                margin: const EdgeInsets.only(bottom: 10),
                                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                                decoration: BoxDecoration(
                                  color: msg.isUser ? Colors.blue[100] : Colors.white,
                                  border: Border.all(color: Colors.grey.shade300),
                                  borderRadius: BorderRadius.only(
                                    topLeft: const Radius.circular(12),
                                    topRight: const Radius.circular(12),
                                    bottomLeft: msg.isUser ? const Radius.circular(12) : const Radius.circular(0),
                                    bottomRight: msg.isUser ? const Radius.circular(0) : const Radius.circular(12),
                                  ),
                                ),
                                child: Text(msg.text),
                              ),
                            );
                          },
                        ),
                ),
                
                if (_isIaTyping)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 8.0),
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),

                Padding(
                  padding: const EdgeInsets.all(12.0),
                  child: Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _iaController,
                          onSubmitted: (_) => _handleSendMessage(),
                          decoration: InputDecoration(
                            hintText: "Pregunta algo...",
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(20)
                            ),
                            contentPadding: const EdgeInsets.symmetric(horizontal: 15, vertical: 10),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      CircleAvatar(
                        backgroundColor: Colors.blue,
                        child: IconButton(
                          icon: const Icon(Icons.send, color: Colors.white, size: 20),
                          onPressed: _handleSendMessage,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}