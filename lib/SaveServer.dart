import 'dart:convert';
import 'dart:io';

class UserData {
  final String name;
  final String server;
  final String port;
  final String key;

  UserData({
    required this.name,
    required this.server,
    required this.port,
    required this.key,
  });

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'server': server,
      'port': port,
      'key': key,
    };
  }

  static UserData fromJson(Map<String, dynamic> json) {
    return UserData(
      name: json['name'],
      server: json['server'],
      port: json['port'],
      key: json['key'],
    );
  }
}

class Storage {
  static Future<String> _getFilePath() async {
    final directory = Directory('./data');
    if (!directory.existsSync()) {
      directory.createSync(recursive: true);
    }
    return '${directory.path}/user_data.json';
  }

  static Future<List<UserData>> loadUserData() async {
    try {
      final filePath = await _getFilePath();
      final file = File(filePath);

      if (!file.existsSync()) {
        return [];
      }

      final content = await file.readAsString();
      final List<dynamic> jsonData = jsonDecode(content);

      return jsonData.map((data) => UserData.fromJson(data)).toList();
    } catch (e) {
      print("Error al cargar los datos: $e");
      return [];
    }
  }

  static Future<void> saveUserData(List<UserData> users) async {
    try {
      final filePath = await _getFilePath();
      final file = File(filePath);

      if (!file.existsSync()) {
        await file.create(recursive: true);
      }

      final List<Map<String, dynamic>> jsonData =
          users.map((user) => user.toJson()).toList();

      await file.writeAsString(jsonEncode(jsonData));
    } catch (e) {
      print("Error al guardar los datos: $e");
    }
  }
}
