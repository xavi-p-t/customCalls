import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:bxdrive/conection.dart'; 

class PortRedirectWidget extends StatefulWidget {
  final ServerConnectionManager connection;
  final String defaultInternalPort; 

  const PortRedirectWidget({
    Key? key, 
    required this.connection,
    this.defaultInternalPort = "3000",
  }) : super(key: key);

  @override
  _PortRedirectWidgetState createState() => _PortRedirectWidgetState();
}

class _PortRedirectWidgetState extends State<PortRedirectWidget> {
  final TextEditingController _externalPortController = TextEditingController(text: "80");
  late TextEditingController _internalPortController;
  final TextEditingController _passwordController = TextEditingController();
  
  bool _isRedirected = false;

  @override
  void initState() {
    super.initState();
    _internalPortController = TextEditingController(text: widget.defaultInternalPort);
  }

  Future<void> _toggleRedirection() async {
    final extPort = _externalPortController.text.trim();
    final intPort = _internalPortController.text.trim();
    final pwd = _passwordController.text.trim();

    if (extPort.isEmpty || intPort.isEmpty || pwd.isEmpty) {
      _showMessage("Rellena todos los campos (incluyendo la contraseña).", Colors.red);
      return;
    }

    try {
      if (_isRedirected) {
        // --- ELIMINAR REDIRECCIÓN ---
        final bashScript = '''
run_sudo() { echo "$pwd" | sudo -S -p '' "\$@"; }
if run_sudo iptables -t nat -C PREROUTING -p tcp --dport $extPort -j REDIRECT --to-ports $intPort 2>/dev/null; then
  run_sudo iptables -t nat -D PREROUTING -p tcp --dport $extPort -j REDIRECT --to-ports $intPort
  TMP=\$(mktemp)
  run_sudo iptables-save > "\$TMP"
  run_sudo install -m 600 "\$TMP" /etc/iptables/rules.v4
  rm -f "\$TMP"
fi
''';
        final base64Script = base64Encode(utf8.encode(bashScript));
        await widget.connection.executeCommand('echo $base64Script | base64 -d | bash');
        
        _showMessage("Redirección eliminada.", Colors.green);
      } else {
        // --- CONFIGURAR REDIRECCIÓN ---
        final bashScript = '''
set -euo pipefail
run_sudo() { echo "$pwd" | sudo -S -p '' "\$@"; }
if ! run_sudo iptables -t nat -C PREROUTING -p tcp --dport $extPort -j REDIRECT --to-ports $intPort 2>/dev/null; then
  run_sudo iptables -t nat -A PREROUTING -p tcp --dport $extPort -j REDIRECT --to-ports $intPort
  TMP=\$(mktemp)
  run_sudo iptables-save > "\$TMP"
  run_sudo install -m 600 "\$TMP" /etc/iptables/rules.v4
  rm -f "\$TMP"
fi
''';
        final base64Script = base64Encode(utf8.encode(bashScript));
        await widget.connection.executeCommand('echo $base64Script | base64 -d | bash');

        _showMessage("Redirección configurada: Puerto $extPort ➔ $intPort", Colors.green);
      }

      setState(() {
        _isRedirected = !_isRedirected;
      });
    } catch (e) {
      _showMessage("Error: $e", Colors.red);
    }
  }

  void _showMessage(String message, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: color),
    );
  }

  
  Widget _buildTextField(String label, TextEditingController controller, {bool isPassword = false}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 15),
      child: TextField(
        controller: controller,
        obscureText: isPassword,
        keyboardType: isPassword ? TextInputType.text : TextInputType.number,
        style: const TextStyle(color: Colors.white),
        decoration: InputDecoration(
          labelText: label,
          labelStyle: const TextStyle(color: Colors.white70),
          filled: true,
          fillColor: Colors.grey[900],
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: Colors.white24),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: Colors.white24),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: Colors.blueAccent),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      color: Colors.black,
      margin: const EdgeInsets.all(16),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              "Enrutamiento de Puertos",
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 20),
            
            // Fila con los dos puertos para ahorrar espacio
            Row(
              children: [
                Expanded(
                  child: _buildTextField("P. Server (Ej: 3000)", _internalPortController),
                ),
                const SizedBox(width: 10),
                const Icon(Icons.arrow_forward, color: Colors.white54),
                const SizedBox(width: 10),
                Expanded(
                  child: _buildTextField("P. objetivo (Ej: 80)", _externalPortController),
                ),
              ],
            ),
            
            // Campo para la contraseña sudo
            _buildTextField("Contraseña Sudo Remota", _passwordController, isPassword: true),
            
            const SizedBox(height: 10),
            
            SizedBox(
              width: double.infinity, // Hace que el botón ocupe todo el ancho
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: _isRedirected ? Colors.red : Colors.blueAccent,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                onPressed: _toggleRedirection,
                child: Text(
                  _isRedirected ? "Desactivar Redirección" : "Activar Redirección",
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}