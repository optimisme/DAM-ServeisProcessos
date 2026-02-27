import 'dart:convert';
import 'dart:async';
import 'dart:ui' as ui;
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'camera.dart';
import 'utils_gamestool.dart';

class AppData extends ChangeNotifier {
  // Atributs per gestionar el joc local (sense WebSocket)
  bool isConnected = true;
  Timer? _simulationTimer;
  bool _jumpRequested = false;
  static const double _playerSpeedPerTick = 2.5;
  static const Duration _simulationStep = Duration(milliseconds: 16);

  // Atributs per gestionar el joc
  Map<String, dynamic> gameData = {}; // Dades de 'game_data.json'
  Map<String, ui.Image> imagesCache = {}; // Imatges
  Map<String, dynamic> gameState = {}; // Estat local del joc
  dynamic playerData; // Apuntador al jugador local (a gameState)
  Camera camera = Camera();
  final GamesToolApi gamesTool = const GamesToolApi(projectFolder: "example_0");
  static const String _localPlayerId = "local_player";

  AppData() {
    _init();
  }

  Future<void> _init() async {
    await _loadGameData();
    _initLocalState();
    _startSimulation();
    notifyListeners();
  }

  void _initLocalState() {
    final List<dynamic> levels =
        (gameData["levels"] as List<dynamic>?) ?? const <dynamic>[];
    final Map<String, dynamic>? firstLevel =
        levels.isNotEmpty && levels.first is Map<String, dynamic>
            ? levels.first as Map<String, dynamic>
            : null;

    final String levelName = (firstLevel?["name"] as String?) ?? "Level 0";
    final List<dynamic> sprites =
        (firstLevel?["sprites"] as List<dynamic>?) ?? const <dynamic>[];
    final Map<String, dynamic>? firstSprite =
        sprites.isNotEmpty && sprites.first is Map<String, dynamic>
            ? sprites.first as Map<String, dynamic>
            : null;

    final Map<String, dynamic> localPlayer = <String, dynamic>{
      "id": _localPlayerId,
      "x": (firstSprite?["x"] as num?)?.toDouble() ?? 100.0,
      "y": (firstSprite?["y"] as num?)?.toDouble() ?? 100.0,
      "width": (firstSprite?["width"] as num?)?.toDouble() ?? 20.0,
      "height": (firstSprite?["height"] as num?)?.toDouble() ?? 20.0,
      "color": "blue",
      "direction": "none",
    };

    gameState = <String, dynamic>{
      "level": levelName,
      "players": <Map<String, dynamic>>[localPlayer],
      "flagOwnerId": null,
      "tickCounter": 0,
    };

    playerData = localPlayer;
    isConnected = true;
  }

  void _startSimulation() {
    _simulationTimer?.cancel();
    _simulationTimer = Timer.periodic(_simulationStep, (_) {
      _stepSimulation();
    });
  }

  void _stepSimulation() {
    if (playerData is! Map<String, dynamic>) {
      return;
    }
    final Map<String, dynamic> player = playerData as Map<String, dynamic>;
    final String direction = (player["direction"] as String?) ?? "none";
    double dx = 0.0;
    double dy = 0.0;

    switch (direction) {
      case "up":
        dy = -_playerSpeedPerTick;
        break;
      case "down":
        dy = _playerSpeedPerTick;
        break;
      case "left":
        dx = -_playerSpeedPerTick;
        break;
      case "right":
        dx = _playerSpeedPerTick;
        break;
      case "upLeft":
        dx = -_playerSpeedPerTick;
        dy = -_playerSpeedPerTick;
        break;
      case "upRight":
        dx = _playerSpeedPerTick;
        dy = -_playerSpeedPerTick;
        break;
      case "downLeft":
        dx = -_playerSpeedPerTick;
        dy = _playerSpeedPerTick;
        break;
      case "downRight":
        dx = _playerSpeedPerTick;
        dy = _playerSpeedPerTick;
        break;
    }

    if (_jumpRequested) {
      dy -= _playerSpeedPerTick * 2;
      _jumpRequested = false;
    }

    player["x"] = (player["x"] as num).toDouble() + dx;
    player["y"] = (player["y"] as num).toDouble() + dy;
    gameState["tickCounter"] = ((gameState["tickCounter"] as int?) ?? 0) + 1;
    notifyListeners();
  }

  // Filtrar les dades del propi jugador (fent servir l'id de player)
  dynamic getPlayerData(String playerId) {
    final List<dynamic> players =
        (gameState["players"] as List<dynamic>?) ?? const <dynamic>[];
    return players.firstWhere(
      (player) => player is Map<String, dynamic> && player["id"] == playerId,
      orElse: () => null,
    );
  }

  // Aturar simulació local
  void disconnect() {
    _simulationTimer?.cancel();
    isConnected = false;
    notifyListeners();
  }

  // Tractar input del joc (en local) mantenint la mateixa API
  void sendMessage(String message) {
    if (playerData is! Map<String, dynamic>) {
      return;
    }

    try {
      final Map<String, dynamic> data =
          jsonDecode(message) as Map<String, dynamic>;
      final String type = (data["type"] as String?) ?? "";
      final Map<String, dynamic> player = playerData as Map<String, dynamic>;

      if (type == "direction") {
        final String direction = (data["value"] as String?) ?? "none";
        player["direction"] = direction;
      } else if (type == "jump") {
        _jumpRequested = true;
      }

      notifyListeners();
    } catch (e) {
      if (kDebugMode) {
        print("Missatge local invàlid: $e");
      }
    }
  }

  // Obté una imatge de 'assets' (si no la té ja en caché)
  Future<ui.Image> getImage(String assetName) async {
    final String normalizedAssetName = assetName.startsWith('assets/')
        ? assetName.substring('assets/'.length)
        : assetName;
    if (!imagesCache.containsKey(normalizedAssetName)) {
      final ByteData data =
          await rootBundle.load('assets/$normalizedAssetName');
      final Uint8List bytes = data.buffer.asUint8List();
      imagesCache[normalizedAssetName] = await decodeImage(bytes);
    }
    return imagesCache[normalizedAssetName]!;
  }

  Future<ui.Image> decodeImage(Uint8List bytes) {
    final Completer<ui.Image> completer = Completer();
    ui.decodeImageFromList(bytes, (ui.Image img) => completer.complete(img));
    return completer.future;
  }

  Future<void> _loadGameData() async {
    try {
      gameData = await gamesTool.loadGameData(rootBundle);
      final Set<String> imageFiles =
          gamesTool.collectReferencedImageFiles(gameData);
      for (final String imageFile in imageFiles) {
        await getImage(gamesTool.toRelativeAssetKey(imageFile));
      }
    } catch (e) {
      if (kDebugMode) {
        print("Error carregant els assets del joc: $e");
      }
    }
  }

  @override
  void dispose() {
    _simulationTimer?.cancel();
    super.dispose();
  }
}
