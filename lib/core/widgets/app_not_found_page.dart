import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../app/router/app_routes.dart';
import '../extensions/context_extensions.dart';
import 'app_message_view.dart';

class AppNotFoundPage extends StatelessWidget {
  const AppNotFoundPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(),
      body: AppMessageView(
        message: context.l10n.pageNotFound,
        icon: Icons.search_off,
        onRetry: () => context.go(AppRoutes.feed),
      ),
    );
  }
}
