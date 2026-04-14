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


  //-------------iniciar apagar servidores----------------

  /// INICIAR EL SERVIDOR
  Future<void> startServer(String remotePath, String type) async {
    String command = '';
    
    if (type == 'node') {
      // Si es Node, asumimos que se lanza con npm start o node server.js
      command = 'cd $remotePath && nohup npm start > server_log.txt 2>&1 &';
    } else if (type == 'java') {
      // Si es Java, buscamos el archivo .jar y lo ejecutamos
      command = 'cd $remotePath && nohup java -jar server-package.jar > server_log.txt 2>&1 &';
    }

    if (command.isNotEmpty) {
      print('Ejecutando inicio: $command');
      await _sshClient!.execute(command); 
    }
  }

  /// DETENER EL SERVIDOR
  Future<void> stopServer(int port) async {
    // El comando fuser busca qué proceso está usando el puerto y lo mata (-k).
    final command = 'fuser -k $port/tcp';
    
    print('Ejecutando apagado en puerto $port: $command');
    await _sshClient!.execute(command);
  }

  /// REINICIAR EL SERVIDOR
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

  /// Ejecutar un comando en el servidor SSH.
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

  /// Método para listar archivos y directorios remotos
  Future<List<Map<String, String>>> listFiles(String remotePath) async {
    try {
      // Ejecuta el comando 'ls -l' en el servidor SSH
      final result = await executeCommand('ls -l $remotePath');

      final files = <Map<String, String>>[];

      // Procesa cada línea de la salida
      for (var line in result.split('\n')) {
        if (line.isNotEmpty) {
          final parts = line.split(RegExp(r'\s+'));
          final isDirectory = parts[0].startsWith('d'); // 'd' indica directorio
          final name = parts.last;

          // Añade el archivo o directorio a la lista
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
      // Usamos el comando 'mv' para renombrar el archivo o carpeta
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
      // Usamos el comando 'rm' para eliminar el archivo o 'rm -r' para eliminar un directorio
      final command = remotePath.endsWith('/')
          ? 'rm -r $remotePath' // Si es un directorio
          : 'rm $remotePath'; // Si es un archivo
      await executeCommand(command);
      print("Archivo o carpeta eliminada: $remotePath");
    } catch (e) {
      print("Error eliminando archivo o carpeta: $e");
      throw Exception("Error eliminando archivo o carpeta: $e");
    }
  }

  Future<void> downloadFile(String remotePath, String localPath) async {
    try {
      // Conexión SFTP
      final sftp = await _sshClient!.sftp();

      // Abrir archivo remoto para lectura
      final remoteFile =
          await sftp.open(remotePath, mode: SftpFileOpenMode.read);

      // Crear archivo local para escritura
      final localFile = File(localPath);

      // Abrir un Stream de escritura en el archivo local
      final fileSink = localFile.openWrite();

      // Leer el archivo remoto y escribir en el archivo local
      await for (final chunk in remoteFile.read(
        onProgress: (bytesRead) {
          print('Progreso: $bytesRead bytes leídos');
        },
      )) {
        fileSink.add(chunk);
      }

      // Cerrar el Sink y el archivo remoto
      await fileSink.close();
      await remoteFile.close();

      print('Archivo descargado correctamente: $localPath');
    } catch (e) {
      print('Error durante la descarga del archivo: $e');
    }
  }

  Future<String> showFileInfo(String remotePath) async {
    try {
      // Usamos el comando 'ls -l' para obtener detalles del archivo o carpeta
      final result = await executeCommand('ls -l $remotePath');
      print("Información del archivo o carpeta: $result");
      return result;
    } catch (e) {
      print("Error mostrando información del archivo o carpeta: $e");
      throw Exception("Error mostrando información del archivo o carpeta: $e");
    }
  }

  // Future<String> startServer(String serverPath, String serverType) async {
  //   try {
  //     final command = '''
  //   cd $serverPath

  //   # Instalar dependencias para Node.js si es necesario
  //   if [ "$serverType" = "node" ]; then
  //     npm install
  //   fi

  //   # Iniciar el servidor
  //   if [ "$serverType" = "node" ]; then
  //     nohup node server.js > output.log 2>&1 &
  //   elif [ "$serverType" = "java" ]; then
  //     nohup java -jar server.jar > output.log 2>&1 &
  //   fi

  //   # Obtener el PID del proceso
  //   PID=\$(ps aux | grep "$serverType" | grep -v "grep" | awk '{print \$2}')
  //   echo "Servidor $serverType iniciado con PID \$PID"
  //   ''';

  //     final result = await executeCommand(command);
  //     return "Servidor iniciado: $result";
  //   } catch (e) {
  //     return "Error iniciando el servidor: $e";
  //   }
  // }

  // Future<String> stopServer(int port) async {
  //   try {
  //     final command = '''
  //   # Buscar y detener el proceso en el puerto dado
  //   PID=\$(lsof -t -i :$port)
  //   if [ -n "\$PID" ]; then
  //     kill -9 \$PID
  //     echo "Servidor en el puerto $port detenido."
  //   else
  //     echo "No se encontró un servidor en el puerto $port."
  //   fi
  //   ''';

  //     final result = await executeCommand(command);
  //     return result;
  //   } catch (e) {
  //     return "Error deteniendo el servidor: $e";
  //   }
  // }

  // Future<String> restartServer(
  //     String serverPath, String serverType, int port) async {
  //   try {
  //     // Detener el servidor
  //     final stopResult = await stopServer(port);

  //     // Iniciar el servidor
  //     final startResult = await startServer(serverPath, serverType);

  //     return "Reinicio completado:\n$stopResult\n$startResult";
  //   } catch (e) {
  //     return "Error reiniciando el servidor: $e";
  //   }
  // }

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

  /// Cerrar la conexión SSH.
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
