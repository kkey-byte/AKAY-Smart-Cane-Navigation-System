import '../../theme/gabay_typography.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../theme/gabay_theme.dart';

/// Shared blue title bar for the requested report, legal and password pages.
class GabayBlueAppBar extends StatelessWidget implements PreferredSizeWidget {
  const GabayBlueAppBar({
    super.key,
    required this.title,
    this.showBack = true,
    this.leading,
  });
  final String title;
  final bool showBack;
  final Widget? leading;
  @override
  Size get preferredSize => const Size.fromHeight(60);
  @override
  Widget build(BuildContext context) => AppBar(
    title: Text(
      title,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: const TextStyle(
        fontSize: GabayTypography.pageTitle,
        fontWeight: GabayTypography.semibold,
      ),
    ),
    centerTitle: true,
    toolbarHeight: 60,
    automaticallyImplyLeading: showBack,
    leading: leading,
    foregroundColor: context.gabay.textPrimary,
    backgroundColor: Colors.transparent,
    surfaceTintColor: Colors.transparent,
    elevation: 0,
    systemOverlayStyle: const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.dark,
      statusBarBrightness: Brightness.light,
    ),
  );
}
