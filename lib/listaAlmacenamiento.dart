import 'package:flutter/material.dart';
import 'package:bxdrive/almacenamientoView.dart'; // para usar FolderUsage

class ListaAlmacenamiento extends StatelessWidget {
  final List<FolderUsage> data;

  const ListaAlmacenamiento({super.key, required this.data});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      child: ListView(
        children: data.map((folder) {
          return ListTile(
            leading: CircleAvatar(backgroundColor: folder.color),
            title: Text(folder.name),
            subtitle: Text("${folder.percent.toStringAsFixed(1)}% del espacio"),
          );
        }).toList(),
      ),
    );
  }
}
