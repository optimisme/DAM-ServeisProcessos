import '../core/gameplay_module.dart';

/// Level-specific extension point for level index 1.
class Level001ActionsModule extends GameplayModule {
  const Level001ActionsModule();

  @override
  Future<void> onLevelMounted(GameplayContext context) async {
    // Hook for level 001 actions/events.
  }
}
