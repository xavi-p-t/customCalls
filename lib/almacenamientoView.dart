import 'package:bxdrive/conection.dart';
import 'package:flutter/material.dart';
import 'package:bxdrive/grafico.dart';
import 'package:bxdrive/menuArchivos.dart';
import 'package:bxdrive/listaAlmacenamiento.dart';

class FolderUsage {
  final String name;
  final double percent;
  final Color color;

  FolderUsage(this.name, this.percent, this.color);
}

class AlmacenamientoView extends StatefulWidget {
  final ServerConnectionManager connection;

  const AlmacenamientoView({super.key, required this.connection});

  @override
  State<AlmacenamientoView> createState() => _AlmacenamientoViewState();
}
class _AlmacenamientoViewState extends State<AlmacenamientoView> {
  List<FolderUsage> carpetas = [];
  bool loading = true;

  @override
  void initState() {
    super.initState();
    _loadServerFolders();
  }

  @override
Widget build(BuildContext context) {
  if (loading) {
    return const Center(child: CircularProgressIndicator());
  }

  return Row(
    children: [
      Expanded(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: ListaAlmacenamiento(data: carpetas),
        ),
      ),
      Expanded(
        child: Center(
          child: GraficoCircularAlmacenamiento(data: carpetas),
        ),
      ),
    ],
  );
}


  Future<void> _loadServerFolders() async {
    try {
      // 1. Listar archivos del servidor
      final files = await widget.connection.listFiles("/home/super");

      // 2. Filtrar solo carpetas
      final directories = files.where((f) => f["type"] == "directory");

      // 3. Obtener tamaño de cada carpeta
      List<FolderUsage> result = [];

      for (var dir in directories) {
        final name = dir["name"]!;
        final sizeStr = await widget.connection.executeCommand(
          "du -sb /home/super/$name | cut -f1"
        );

        final size = double.tryParse(sizeStr.trim()) ?? 0;

        result.add(
          FolderUsage(
            name,
            size, // tamaño real en bytes
            _randomColor(name),
          ),
        );
      }

      // 4. Calcular porcentajes
      final total = result.fold<double>(0, (sum, f) => sum + f.percent);

      final normalized = result.map((f) {
        return FolderUsage(
          f.name,
          (f.percent / total) * 100,
          f.color,
        );
      }).toList();

      setState(() {
        carpetas = normalized;
        loading = false;
      });
    } catch (e) {
      print("Error cargando carpetas: $e");
    }
  }

  Color _randomColor(String seed) {
    final hash = seed.hashCode;
    return Color((hash & 0xFFFFFF) | 0xFF000000);
  }
}