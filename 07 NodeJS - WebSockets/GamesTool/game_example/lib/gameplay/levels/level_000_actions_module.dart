import '../core/gameplay_module.dart';

/// Level-specific extension point for level index 0.
class Level000ActionsModule extends GameplayModule {
  const Level000ActionsModule();

  @override
  Future<void> onLevelMounted(GameplayContext context) async {
    // Hook for level 000 actions/events.
  }
}
