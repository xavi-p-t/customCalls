import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:bxdrive/menuArchivos.dart';
import 'package:bxdrive/conection.dart';
import 'package:bxdrive/almacenamientoView.dart';

enum MenuSection {
  almacenamiento,
  archivos,
}

class MenuConectado extends StatefulWidget {
  final ServerConnectionManager connection;

  const MenuConectado({super.key, required this.connection});

  @override
  State<MenuConectado> createState() => _MenuConectadoState();
}

class _MenuConectadoState extends State<MenuConectado> {
  final GlobalKey<MenuArchivosState> _menuArchivosKey = GlobalKey();
  MenuSection selectedSection = MenuSection.almacenamiento;

  void _reloadPage() {
    if (selectedSection == MenuSection.archivos) {
      _menuArchivosKey.currentState?.listFiles();
    }
  }

  @override
  Widget build(BuildContext context) {
    final double large = MediaQuery.of(context).size.width / 4;

    return CupertinoPageScaffold(
      navigationBar: CupertinoNavigationBar(
        leading: const Text('BXDrive'),
        border: null,
        backgroundColor: Colors.white,
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            CupertinoButton(
              padding: EdgeInsets.zero,
              onPressed: () {
                Navigator.of(context).popUntil((route) => route.isFirst);
              },
              child: const Icon(CupertinoIcons.power, color: Colors.black),
            ),
            CupertinoButton(
              padding: EdgeInsets.zero,
              onPressed: _reloadPage,
              child: const Icon(CupertinoIcons.arrow_clockwise, color: Colors.black),
            ),
          ],
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: large,
            child: Column(
              children: [
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Material(
                      child: Row(
                        children: [
                          Expanded(
                            child: MyList(
                              selected: selectedSection,
                              onSelect: (section) {
                                setState(() {
                                  selectedSection = section;
                                });
                              },
                            ),
                          ),
                          Container(
                            width: 2,
                            color: Colors.black,
                            margin: const EdgeInsets.symmetric(horizontal: 8),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: _buildContent(),
          ),
        ],
      ),
    );
  }

 Widget _buildContent() {
    switch (selectedSection) {
      case MenuSection.almacenamiento:
        return AlmacenamientoView(connection: widget.connection);

      case MenuSection.archivos:
        return MenuArchivos(
          key: _menuArchivosKey,
          connection: widget.connection,
          onNavigateToAlmacenamiento: () {
            setState(() {
              selectedSection = MenuSection.almacenamiento;
            });
          },
        );
    }
  }
}

class MyList extends StatelessWidget {
  final MenuSection selected;
  final Function(MenuSection) onSelect;

  const MyList({
    super.key,
    required this.selected,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    final elementos = {
      MenuSection.almacenamiento: "Almacenamiento",
      MenuSection.archivos: "Archivos",
    };

    return ListView(
      children: elementos.entries.map((entry) {
        final section = entry.key;
        final label = entry.value;

        return ListTile(
          title: Text(label),
          selected: selected == section,
          selectedTileColor: const Color.fromARGB(255, 235, 215, 238),
          hoverColor: const Color.fromARGB(255, 235, 215, 238),
          onTap: () => onSelect(section),
        );
      }).toList(),
    );
  }
}