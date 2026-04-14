import 'package:flutter/material.dart';
import '../conection.dart';

class ServerControlWidget extends StatefulWidget {
  final String serverPath;
  final void Function(Map<String, dynamic> serverInfo) onServerStateChanged;
  final ServerConnectionManager connectionManager;

  const ServerControlWidget({
    required this.serverPath,
    required this.onServerStateChanged,
    required this.connectionManager,
    Key? key,
  }) : super(key: key);

  @override
  _ServerControlWidgetState createState() => _ServerControlWidgetState();
}

class _ServerControlWidgetState extends State<ServerControlWidget> {
  bool _isServerRunning = false;
  String _serverStatus = "stopped";

  Color _getStatusColor() {
    switch (_serverStatus) {
      case "running":
        return Colors.green;
      case "stopped":
        return Colors.red;
      case "restarting":
        return Colors.orange;
      case "error":
        return Colors.purple;
      default:
        return Colors.grey;
    }
  }

  Future<String> _detectServerType() async {
    final remotePath = widget.serverPath;
    try {
      final files = await widget.connectionManager.listFiles(remotePath);
      //print("Archivos encontrados en la ruta: $files");
      if (files.any((file) => file['name'] == 'package.json')) return 'Node';
      if (files.any((file) => file['name'].toString().endsWith('.jar'))) {
        return 'Java';
      }
      return 'Unknown';
    } catch (e) {
      print('Error detecting server type: $e');
      return 'Unknown';
    }
  }

  void _notifyParent() async {
    final serverType = await _detectServerType();
    widget.onServerStateChanged({
      'isServer': serverType != 'Unknown',
      'type': serverType,
      'active': _isServerRunning,
    });
  }

Future<void> handleServerAction(String action, String serverPath) async {
    final port = 3000;
    final serverType = await _detectServerType();

    try {
      switch (action) {
        case 'start':
          setState(() {
            _serverStatus = "restarting"; 
          });
          
          await widget.connectionManager.startServer(serverPath, serverType.toLowerCase());
          
          setState(() {
            _isServerRunning = true;
            _serverStatus = "running";
          });
          _notifyParent();
          break;

        case 'restart':
          setState(() {
            _serverStatus = "restarting";
          });
          
          await widget.connectionManager.restartServer(serverPath, serverType.toLowerCase(), port);
          
          setState(() {
            _isServerRunning = true;
            _serverStatus = "running";
          });
          _notifyParent();
          break;

        case 'stop':
          setState(() {
            _serverStatus = "restarting"; 
          });
          
          await widget.connectionManager.stopServer(port);
          
          setState(() {
            _isServerRunning = false;
            _serverStatus = "stopped";
          });
          _notifyParent();
          break;
      }
    } catch (e) {
      print("Error al ejecutar acción: $e");
      setState(() {
        _isServerRunning = false;
        _serverStatus = "error";
      });
      _notifyParent();
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<String>(
      future: _detectServerType(),
      builder: (context, snapshot) {
        final serverType = snapshot.data ?? 'Detectando...';

        if (serverType == 'Unknown') {
          return const SizedBox(); 
        }

        return Align(
          alignment: Alignment.bottomCenter,
          child: Container(
            color: Colors.black, 
            height: 60,
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.start,
                  children: [
                    StatusIndicator(status: _serverStatus),
                    const SizedBox(width: 10),
                    if (_serverStatus == "running")
                      Text(
                        "$_serverStatus | Servidor funcionant al port 3000",
                        style:
                            const TextStyle(color: Colors.white, fontSize: 16),
                      )
                    else
                      Text(
                        "$_serverStatus",
                        style:
                            const TextStyle(color: Colors.white, fontSize: 16),
                      ),
                  ],
                ),

                // Botones de acción
                Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.play_arrow, color: Colors.white),
                      onPressed: () =>
                          handleServerAction('start', widget.serverPath),
                    ),
                    IconButton(
                      icon: const Icon(Icons.stop, color: Colors.white),
                      onPressed: () =>
                          handleServerAction('stop', widget.serverPath),
                    ),
                    IconButton(
                      icon: const Icon(Icons.refresh, color: Colors.white),
                      onPressed: () =>
                          handleServerAction('restart', widget.serverPath),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class StatusIndicator extends StatelessWidget {
  final String status;

  const StatusIndicator({required this.status, Key? key}) : super(key: key);

  Color _getStatusColor() {
    switch (status) {
      case "running":
        return Colors.green;
      case "stopped":
        return Colors.red;
      case "restarting":
        return Colors.orange;
      case "error":
        return Colors.purple;
      default:
        return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: const Size(12, 12),
      painter: StatusPainter(_getStatusColor()),
    );
  }
}

class StatusPainter extends CustomPainter {
  final Color color;

  StatusPainter(this.color);

  @override
  void paint(Canvas canvas, Size size) {
    final Paint paint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;

    canvas.drawCircle(size.center(Offset.zero), size.width, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) {
    return false;
  }
}
