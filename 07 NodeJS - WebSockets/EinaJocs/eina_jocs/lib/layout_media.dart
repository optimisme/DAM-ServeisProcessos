import 'package:flutter/cupertino.dart';
import 'package:flutter_cupertino_desktop_kit/flutter_cupertino_desktop_kit.dart';

class LayoutMedia extends StatelessWidget {
  const LayoutMedia({super.key});

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: CDKText(
        'Layout Media',
        role: CDKTextRole.bodyStrong,
      ),
    );
  }
}
