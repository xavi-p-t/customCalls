import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:dartssh2/dartssh2.dart';
import 'package:archive/archive.dart';

class ServerConnectionManager {
  static final ServerConnectionManager _instance =
      ServerConnectionManager._internal();

  ServerConnectionManager._internal();

  factory ServerConnectionManager() => _instance;

  String? _currentUsername;
  String? _currentServer;
  int? _currentPort;
  String? _currentPrivateKeyPath;

  SSHClient? _sshClient;

  // --- GESTIÓN DE SERVIDORES CON PM2 ---
  Future<String> managePm2App(String action, String appName, {String? path, String script = "app.js"}) async {
    try {
      // 1. Obtener el estado actual de PM2 en formato JSON
      final rawOutput = await executeCommand('pm2 jlist');

      // Extraemos solo el array JSON (por si la consola imprime otros textos/warnings antes)
      final startIndex = rawOutput.indexOf('[');
      final endIndex = rawOutput.lastIndexOf(']') + 1;

      if (startIndex == -1 || endIndex == 0) {
        return "No se pudo leer la lista de PM2. Comprueba que PM2 esté instalado.";
      }

      final jsonString = rawOutput.substring(startIndex, endIndex);
      final List<dynamic> apps = jsonDecode(jsonString);

      // 2. Buscar si la app ya está en la lista de PM2
      dynamic existingApp;
      for (var app in apps) {
        if (app['name'] == appName) {
          existingApp = app;
          break;
        }
      }

      String status = existingApp != null ? existingApp['pm2_env']['status'] : 'no_existe';

      // 3. Ejecutar la lógica según la acción
      switch (action) {
        case 'añadir':
          if (existingApp != null) {
            return "El servidor '$appName' ya existe en PM2 y está $status.";
          }
          if (path == null) return "Necesito la ruta para añadir el servidor.";
          await executeCommand('cd "$path" && pm2 start $script --name "$appName"');
          return "El servidor '$appName' se ha añadido a PM2 y se está ejecutando.";

        case 'borrar':
          if (existingApp == null) return "El servidor '$appName' no existe en la lista de PM2.";
          await executeCommand('pm2 delete "$appName"');
          return "El servidor '$appName' ha sido borrado de PM2.";

        case 'iniciar':
          if (existingApp == null) {
            return "⚠️ El servidor '$appName' NO está en la lista de PM2. Debes añadirlo primero.";
          }
          if (status == 'online') {
            return "✅ El servidor '$appName' ya estaba encendido y funcionando.";
          }
          await executeCommand('pm2 start "$appName"');
          return "🚀 El servidor '$appName' se ha iniciado correctamente.";

        case 'detener':
          if (existingApp == null) return "El servidor '$appName' no existe en PM2.";
          if (status != 'online') return "El servidor '$appName' ya estaba detenido.";
          await executeCommand('pm2 stop "$appName"');
          return "🛑 El servidor '$appName' se ha detenido.";

        case 'estado':
          if (existingApp == null) return "El servidor '$appName' no existe en PM2.";
          return "ℹ️ El servidor '$appName' está actualmente: $status.";

        default:
          return "Acción no reconocida.";
      }
    } catch (e) {
      return "Error ejecutando PM2: $e";
    }
  }

  //-------------iniciar apagar servidores (MÉTODOS ANTIGUOS)----------------
  Future<void> startServer(String remotePath, String type) async {
    String command = '';
    
    if (type == 'node') {
      command = 'cd $remotePath && nohup npm start > server_log.txt 2>&1 &';
    } else if (type == 'java') {
      command = 'cd $remotePath && nohup java -jar server-package.jar > server_log.txt 2>&1 &';
    }

    if (command.isNotEmpty) {
      print('Ejecutando inicio: $command');
      await _sshClient!.execute(command); 
    }
  }

  Future<void> stopServer(int port) async {
    final command = 'fuser -k $port/tcp';
    print('Ejecutando apagado en puerto $port: $command');
    await _sshClient!.execute(command);
  }

  Future<void> restartServer(String remotePath, String type, int port) async {
    await stopServer(port);
    await Future.delayed(const Duration(seconds: 2)); 
    await startServer(remotePath, type);
  }
  //--iniciar apagar servidores FIN

  void setConnection(
      String username, String server, int port, String privateKeyPath) {
    _currentUsername = username;
    _currentServer = server;
    _currentPort = port;
    _currentPrivateKeyPath = privateKeyPath;

    print("Connection details set:");
  }

  Future<void> connect() async {
    if (_currentServer == null ||
        _currentPort == null ||
        _currentUsername == null ||
        _currentPrivateKeyPath == null) {
      throw Exception("Connection details are not set.");
    }

    try {
      final socket = await SSHSocket.connect(_currentServer!, _currentPort!);

      final privateKeyPem = await File(_currentPrivateKeyPath!).readAsString();

      _sshClient = SSHClient(
        socket,
        username: _currentUsername!,
        identities: [
          ...SSHKeyPair.fromPem(privateKeyPem),
        ],
      );

      print(
          "Te has conectado correctamente al servidor $_currentServer:$_currentPort.");
    } catch (e) {
      print("Error while connecting: $e");
      throw Exception("Failed to connect to the SSH server: $e");
    }
  }

  Future<String> executeCommand(String command) async {
    if (_sshClient == null) {
      throw Exception("SSH Client is not initialized. Call connect() first.");
    }

    try {
      final result = await _sshClient!.run(command);
      final output = utf8.decode(result);
      return output;
    } catch (e) {
      print("Error while executing command: $e");
      throw Exception("Failed to execute command: $e");
    }
  }

  Future<List<Map<String, String>>> listFiles(String remotePath) async {
    try {
      final result = await executeCommand('ls -l $remotePath');
      final files = <Map<String, String>>[];

      for (var line in result.split('\n')) {
        if (line.isNotEmpty) {
          final parts = line.split(RegExp(r'\s+'));
          final isDirectory = parts[0].startsWith('d'); 
          final name = parts.last;

          files.add({
            'name': name,
            'type': isDirectory ? 'directory' : 'file',
          });
        }
      }

      return files;
    } catch (e) {
      print("Error while listing files: $e");
      throw Exception("Error listing files: $e");
    }
  }

  Future<void> renameFile(String remotePath, String newName) async {
    try {
      final command = 'mv $remotePath $newName';
      await executeCommand(command);
      print("Archivo o carpeta renombrado a: $newName");
    } catch (e) {
      print("Error renombrando archivo o carpeta: $e");
      throw Exception("Error renombrando archivo o carpeta: $e");
    }
  }

  Future<void> deleteFile(String remotePath) async {
    try {
      final command = remotePath.endsWith('/')
          ? 'rm -r $remotePath' 
          : 'rm $remotePath'; 
      await executeCommand(command);
      print("Archivo o carpeta eliminada: $remotePath");
    } catch (e) {
      print("Error eliminando archivo o carpeta: $e");
      throw Exception("Error eliminando archivo o carpeta: $e");
    }
  }

  Future<void> downloadFile(String remotePath, String localPath) async {
    try {
      final sftp = await _sshClient!.sftp();
      final remoteFile = await sftp.open(remotePath, mode: SftpFileOpenMode.read);
      final localFile = File(localPath);
      final fileSink = localFile.openWrite();

      await for (final chunk in remoteFile.read(
        onProgress: (bytesRead) {
          print('Progreso: $bytesRead bytes leídos');
        },
      )) {
        fileSink.add(chunk);
      }

      await fileSink.close();
      await remoteFile.close();

      print('Archivo descargado correctamente: $localPath');
    } catch (e) {
      print('Error durante la descarga del archivo: $e');
    }
  }

  Future<String> showFileInfo(String remotePath) async {
    try {
      final result = await executeCommand('ls -l $remotePath');
      print("Información del archivo o carpeta: $result");
      return result;
    } catch (e) {
      print("Error mostrando información del archivo o carpeta: $e");
      throw Exception("Error mostrando información del archivo o carpeta: $e");
    }
  }

  Future<void> uploadFile(String localPath, String remotePath) async {
    if (_sshClient == null) {
      throw Exception("SSH Client is not initialized. Call connect() first.");
    }

    try {
      final sftp = await _sshClient!.sftp();
      final file = File(localPath);

      if (!file.existsSync()) {
        throw Exception("No existeix l'arxiu local: $localPath");
      }

      if (localPath.endsWith('.zip')) {
        print("Descomprimint arxius...");
        final bytes = file.readAsBytesSync();
        final archive = ZipDecoder().decodeBytes(bytes);

        final extractionDir = Directory(
            '${file.parent.path}/${file.uri.pathSegments.last.replaceAll(".zip", "")}');
        if (!extractionDir.existsSync()) {
          extractionDir.createSync(recursive: true);
        }

        for (final archiveFile in archive) {
          if (archiveFile.isFile) {
            final data = archiveFile.content as List<int>;
            final extractedFilePath =
                '${extractionDir.path}/${archiveFile.name}';
            final extractedFile = File(extractedFilePath);
            extractedFile.createSync(recursive: true);
            extractedFile.writeAsBytesSync(data);
          }
        }

        await uploadFolder(
            extractionDir.path, remotePath.replaceAll('.zip', ''));
      } else {
        final sanitizedRemotePath = remotePath.replaceAll(' ', '_');
        final fileStream =
            file.openRead().map((chunk) => Uint8List.fromList(chunk));

        final remoteFile = await sftp.open(
          sanitizedRemotePath,
          mode: SftpFileOpenMode.create | SftpFileOpenMode.write,
        );

        await remoteFile.write(fileStream);
        await remoteFile.close();
      }

      sftp.close();
      print("Proceso completat.");
    } catch (e) {
      print("Error al pujar el arxiu: $e");
      throw Exception("Error al pujar el arxiu: $e");
    }
  }

  Future<void> uploadFolder(
      String localFolderPath, String remoteFolderPath) async {
    final localDirectory = Directory(localFolderPath);
    if (!localDirectory.existsSync()) {
      throw Exception("La carpeta local no existeix: $localFolderPath");
    }

    await executeCommand('mkdir -p $remoteFolderPath');

    for (final entity in localDirectory.listSync(recursive: true)) {
      final relativePath = entity.path.replaceFirst(localFolderPath, '');
      final sanitizedRemotePath =
          '$remoteFolderPath/$relativePath'.replaceAll(' ', '_');

      if (entity is File) {
        final fileStream =
            entity.openRead().map((chunk) => Uint8List.fromList(chunk));

        final sftp = await _sshClient!.sftp();
        final remoteFile = await sftp.open(
          sanitizedRemotePath,
          mode: SftpFileOpenMode.create | SftpFileOpenMode.write,
        );

        await remoteFile.write(fileStream);
        await remoteFile.close();
        sftp.close();
      } else if (entity is Directory) {
        await executeCommand('mkdir -p $sanitizedRemotePath');
      }
    }
  }

  Future<void> disconnect() async {
    if (_sshClient != null) {
      _sshClient!.close();
      await _sshClient!.done;
      _sshClient = null;
      print("Disconnected from the SSH server.");
    } else {
      print("No SSH client to disconnect.");
    }
  }
}