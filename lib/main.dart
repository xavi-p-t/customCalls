import 'package:flutter/material.dart';
import 'package:bxdrive/mainCanvas.dart';
import 'conection.dart';
import 'package:bxdrive/SaveServer.dart';
import 'package:bxdrive/menuConectado.dart';


void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Conexión SSH',
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
      home: const ConnectionScreen(),
    );
  }
}

class ConnectionScreen extends StatefulWidget {
  const ConnectionScreen({super.key});

  @override
  _ConnectionScreenState createState() => _ConnectionScreenState();
}

class _ConnectionScreenState extends State<ConnectionScreen> {
  final TextEditingController _usernameController = TextEditingController();
  final TextEditingController _serverController = TextEditingController();
  final TextEditingController _portController = TextEditingController();
  final TextEditingController _privateKeyController = TextEditingController();

  String _statusMessage = '';
  List<UserData> userDataList = [];

  final FocusNode _usernameFocusNode = FocusNode();
  final FocusNode _serverFocusNode = FocusNode();
  final FocusNode _portFocusNode = FocusNode();
  final FocusNode _keyFocusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  void _loadUserData() async {
    userDataList = await Storage.loadUserData();
    setState(() {});
  }

  @override
  void dispose() {
    _usernameController.dispose();
    _serverController.dispose();
    _portController.dispose();
    _privateKeyController.dispose();
    super.dispose();
  }

  void _connectToServer() async {
  final username = _usernameController.text.trim();
  final server = _serverController.text.trim();
  final port = int.tryParse(_portController.text) ?? 22;
  final privateKeyPath = _privateKeyController.text.trim();

  if (username.isEmpty || server.isEmpty || privateKeyPath.isEmpty) {
    setState(() {
      _statusMessage = 'Por favor ingrese todos los campos.';
    });
    return;
  }

  try {
    final connection = ServerConnectionManager();
    connection.setConnection(username, server, port, privateKeyPath);
    await connection.connect();


    setState(() {
      _statusMessage = 'Conexión exitosa a $server en el puerto $port';
    });

    // Navegar a menuConectado después de conectarse
    Navigator.push(
  context,
  MaterialPageRoute(builder: (context) => MenuConectado(connection: connection)),
);


  } catch (e) {
    setState(() {
      _statusMessage = 'Error al conectar: $e';
    });
  }
}


  void addUserToFavorites() {
    String name = _usernameController.text.trim();
    String server = _serverController.text.trim();
    String port = _portController.text.trim();
    String key = _privateKeyController.text.trim();

    if (name.isEmpty || server.isEmpty || port.isEmpty) {
      setState(() {
        _statusMessage =
            "Faltan datos, por favor rellena todos los campos obligatorios.";
      });
      return;
    }

    final newUser = UserData(name: name, server: server, port: port, key: key);

    if (userDataList.any(
        (user) => user.name == newUser.name && user.server == newUser.server)) {
      setState(() {
        _statusMessage = "Este servidor ya está en favoritos.";
      });
      return;
    }

    userDataList.add(newUser);
    Storage.saveUserData(userDataList);
    _loadUserData();
    setState(() {
      _statusMessage = "Servidor agregado a favoritos.";
    });
  }

  void removeUserFromFavorites(int index) {
    userDataList.removeAt(index);
    Storage.saveUserData(userDataList);
    _loadUserData();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Row(
          children: [
            // SERVIDORES FAVORITOS
            Expanded(
              flex: 1,
              child: Container(
                color: const Color(0xFFF9F2FA),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    const Padding(
                      padding: EdgeInsets.only(top: 10),
                      child: Text(
                        "SERVIDORES FAVORITOS",
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    Expanded(
                      child: ListView.builder(
                        itemCount: userDataList.length,
                        itemBuilder: (context, index) {
                          final user = userDataList[index];
                          return ListTile(
                            title: Text(user.name),
                            subtitle: Text('${user.server}:${user.port}'),
                            trailing: IconButton(
                              icon: const Icon(Icons.delete),
                              onPressed: () => removeUserFromFavorites(index),
                            ),
                            onTap: () {
                              setState(() {
                                _usernameController.text = user.name;
                                _serverController.text = user.server;
                                _portController.text = user.port;
                                _privateKeyController.text = user.key;
                              });
                            },
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
            ),
            Container(
              width: 3,
              color: Colors.black,
            ),
            // CONFIGURACIÓN SSH
            Expanded(
              flex: 3,
              child: Container(
                color: Colors.white,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Padding(
                      padding: EdgeInsets.only(top: 10, left: 40),
                      child: Text(
                        "CONFIGURACIÓN SSH",
                        style: TextStyle(
                          fontSize: 30,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    const SizedBox(height: 80),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 160.0),
                      child: Column(
                        children: [
                          CustomTextFieldWidget(
                            labelText: "Nom:",
                            controller: _usernameController,
                            focusNode: _usernameFocusNode,
                          ),
                          const SizedBox(height: 30),
                          CustomTextFieldWidget(
                            labelText: "Servidor:",
                            controller: _serverController,
                            focusNode: _serverFocusNode,
                          ),
                          const SizedBox(height: 30),
                          CustomTextFieldWidget(
                            labelText: "Port:",
                            controller: _portController,
                            focusNode: _portFocusNode,
                          ),
                          const SizedBox(height: 30),
                          FilePickerFieldWidget(
                            labelText: "Clau:",
                            onFileSelected: (path) {
                              setState(() {
                                _privateKeyController.text = path;
                              });
                              print(
                                  '(main) Ruta de la clave seleccionada: $path');
                            },
                          ),
                          const SizedBox(height: 50),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              CustomButton(
                                label: "Afegir a favorits",
                                onPressed: addUserToFavorites,
                              ),
                              const SizedBox(width: 20),
                              CustomButton(
                                label: "Conectar",
                                onPressed: _connectToServer,
                              ),
                            ],
                          ),
                          const SizedBox(height: 20),
                          // Mensaje de estado
                          if (_statusMessage.isNotEmpty)
                            Padding(
                              padding: const EdgeInsets.only(top: 20),
                              child: Text(
                                _statusMessage,
                                style: TextStyle(
                                  color: _statusMessage.startsWith('Error')
                                      ? Colors.red
                                      : Colors.green,
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
