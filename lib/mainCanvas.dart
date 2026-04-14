import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';

class CustomTextFieldWidget extends StatelessWidget {
  final String labelText;
  final TextEditingController controller;
  final FocusNode focusNode;
  final bool isHovered;
  final bool isFocused;

  const CustomTextFieldWidget({
    super.key,
    required this.labelText,
    required this.controller,
    required this.focusNode,
    this.isHovered = false,
    this.isFocused = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8.0),
      child: CustomPaint(
        painter: _TextFieldPainter(
          isHovered: isHovered,
          isFocused: focusNode.hasFocus,
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // Texto en la izquierda
            Padding(
              padding: const EdgeInsets.only(left: 10.0),
              child: Text(
                labelText,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: TextField(
                controller: controller,
                focusNode: focusNode,
                decoration: const InputDecoration(
                  border: InputBorder.none,
                  hintText: "Escriu aqui...",
                ),
                style: const TextStyle(fontSize: 16),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class FilePickerFieldWidget extends StatefulWidget {
  final String labelText;
  final Function(String path)
      onFileSelected; // Define correctamente el callback

  const FilePickerFieldWidget({
    super.key,
    required this.labelText,
    required this.onFileSelected, // Marca como requerido
  });

  @override
  _FilePickerFieldWidgetState createState() => _FilePickerFieldWidgetState();
}

class _FilePickerFieldWidgetState extends State<FilePickerFieldWidget> {
  final TextEditingController _controller = TextEditingController();
  final FocusNode _focusNode = FocusNode();

  Future<void> _pickFile() async {
    try {
      // Utilizar file_picker para seleccionar un archivo
      FilePickerResult? result = await FilePicker.platform.pickFiles();
      if (result != null) {
        String? filePath = result.files.single.path;
        setState(() {
          _controller.text = filePath ?? "";
        });
        // Llamar a la función proporcionada para notificar el archivo seleccionado
        if (filePath != null) {
          widget.onFileSelected(filePath);
        }
      }
    } catch (e) {
      print("Error al seleccionar archivo: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8.0),
      child: CustomPaint(
        painter: _TextFieldPainter(
          isHovered: false,
          isFocused: _focusNode.hasFocus,
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // Texto en la izquierda
            Padding(
              padding: const EdgeInsets.only(left: 10.0),
              child: Text(
                widget.labelText,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: TextField(
                controller: _controller,
                focusNode: _focusNode,
                readOnly: true, // El campo es solo lectura
                decoration: const InputDecoration(
                  border: InputBorder.none,
                  hintText: "Selecciona un archivo...",
                ),
                style: const TextStyle(fontSize: 16),
              ),
            ),
            IconButton(
              icon: const Icon(Icons.upload_file,
                  color: Color.fromARGB(255, 0, 0, 0)),
              onPressed: _pickFile,
            ),
          ],
        ),
      ),
    );
  }
}

class _TextFieldPainter extends CustomPainter {
  final bool isHovered;
  final bool isFocused;

  _TextFieldPainter({required this.isHovered, required this.isFocused});

  final Paint _borderPaint = Paint()
    ..color = Colors.black
    ..style = PaintingStyle.stroke
    ..strokeWidth = 2.0;

  final Paint _focusBorderPaint = Paint()
    ..color = Colors.blue
    ..style = PaintingStyle.stroke
    ..strokeWidth = 2.0;

  @override
  void paint(Canvas canvas, Size size) {
    // Definir un radio para las esquinas redondeadas
    const double borderRadius = 10.0;

    // Crear un RRect para el borde con esquinas redondeadas
    final RRect rRect = RRect.fromRectAndRadius(
      Rect.fromLTWH(0, 0, size.width, size.height),
      const Radius.circular(borderRadius),
    );

    // Dibujar el borde dependiendo del estado de hover o focus
    canvas.drawRRect(
        rRect, isHovered || isFocused ? _focusBorderPaint : _borderPaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) {
    return true;
  }
}

class CustomButton extends StatelessWidget {
  final String label;
  final VoidCallback onPressed;

  const CustomButton({
    super.key,
    required this.label,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return ElevatedButton(
      style: ElevatedButton.styleFrom(
        foregroundColor: Colors.black, backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12), // Esquinas redondeadas
          side: const BorderSide(color: Colors.black), // Borde negro
        ),
        minimumSize: const Size(150, 50), // Tamaño mínimo
      ),
      onPressed: onPressed,
      child: Text(
        label,
        style: const TextStyle(color: Colors.black),
      ),
    );
  }
}
