import 'package:flutter/material.dart';
import 'package:bxdrive/ServerControlWidget.dart';
import 'package:bxdrive/conection.dart';
import 'package:file_picker/file_picker.dart';
import 'package:bxdrive/widgetRedirect.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:io';
import 'package:path/path.dart' as p;

class MenuArchivos extends StatefulWidget {
  final ServerConnectionManager connection;

  const MenuArchivos({Key? key, required this.connection}) : super(key: key);

  @override
  State<MenuArchivos> createState() => MenuArchivosState();
}

class MenuArchivosState extends State<MenuArchivos> {
  String currentPath = "//home/super";
  List<Map<String, String>> files = [];
  Map<int, bool> hoverStates = {};
  bool _isServerDetected = false;

  @override
  void initState() {
    super.initState();
    _listFiles();
  }

  void _listFiles() async {
    try {
      List<Map<String, String>> remoteFiles =
          await widget.connection.listFiles(currentPath);
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
    // Normaliza la ruta asegurando que usa '/'
    String normalizedPath = currentPath.replaceAll('\\', '/');

    print("Ruta actual antes de retroceder: $normalizedPath");

    if (normalizedPath != "/") {
      String parentPath = p.posix.dirname(normalizedPath);

      // Asegurar que la raíz sea '/' y no quede vacía
      if (parentPath == "." || parentPath.isEmpty) {
        parentPath = "/";
      }

      print("Retrocediendo a: $parentPath");

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
      body: Column(
        children: [
          // Widget para controlar el servidor si hay uno en la carpeta
          ServerControlWidget(
            serverPath: currentPath,
            connectionManager: widget.connection,
            onServerStateChanged: (serverInfo) async {
              bool isRunning = await isServerRunning();
              
              setState(() {
                _isServerDetected = isRunning;
              });
              print('$_isServerDetected');
            },
          ),
          if (_isServerDetected)
            PortRedirectWidget(connection: widget.connection),
          Expanded(
            // <--- Corrección: "Expanded" con mayúscula
            child: files.isEmpty
                ? const Center(child: CircularProgressIndicator())
                : ListView.builder(
                    itemCount: files.length,
                    itemBuilder: (context, index) {
                      String name = files[index]["name"] ?? "Desconocido";
                      bool isDirectory = files[index]["type"] == "directory";

                      return MouseRegion(
                        onEnter: (_) =>
                            setState(() => hoverStates[index] = true),
                        onExit: (_) =>
                            setState(() => hoverStates[index] = false),
                        child: Container(
                          color: hoverStates[index] ?? false
                              ? Colors.grey.shade200
                              : Colors.transparent,
                          child: ListTile(
                            leading: Icon(
                              isDirectory
                                  ? Icons.folder
                                  : Icons.insert_drive_file,
                              color: isDirectory ? Colors.blue : Colors.grey,
                            ),
                            title: Text(
                              name,
                              style:
                                  const TextStyle(fontWeight: FontWeight.bold),
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
    );
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
                  _listFiles(); // Refrescar la lista
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

}
