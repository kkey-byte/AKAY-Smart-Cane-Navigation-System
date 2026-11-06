import '../../theme/gabay_typography.dart';
import 'package:flutter/material.dart';
import '../../theme/gabay_theme.dart';

/// A transparent, centered title that belongs to the page's scroll content.
class GabayPageHeader extends StatelessWidget {
  const GabayPageHeader({
    super.key,
    required this.title,
    this.showBack = true,
    this.leading,
    this.actions = const [],
  });
  final String title;
  final bool showBack;
  final Widget? leading;
  final List<Widget> actions;

  @override
  Widget build(BuildContext context) => SafeArea(
    bottom: false,
    child: ConstrainedBox(
      constraints: const BoxConstraints(minHeight: 60),
      child: Stack(
        alignment: Alignment.center,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 64),
            child: Text(
              title,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: context.gabay.textPrimary,
                fontSize: GabayTypography.pageTitle,
                fontWeight: GabayTypography.semibold,
              ),
            ),
          ),
          if (leading != null || showBack)
            Align(
              alignment: Alignment.centerLeft,
              child:
                  leading ??
                  IconButton(
                    tooltip: 'Back',
                    onPressed: () => Navigator.maybePop(context),
                    icon: const Icon(
                      Icons.arrow_back_ios_new_rounded,
                      size: 20,
                    ),
                  ),
            ),
          if (actions.isNotEmpty)
            Align(
              alignment: Alignment.centerRight,
              child: Row(mainAxisSize: MainAxisSize.min, children: actions),
            ),
        ],
      ),
    ),
  );
}

/// Coordinates the existing inner scroll view with an unpinned page title.
class GabayScrollingPage extends StatelessWidget {
  const GabayScrollingPage({
    super.key,
    required this.header,
    required this.body,
  });
  final Widget header, body;
  @override
  Widget build(BuildContext context) => SafeArea(
    bottom: false,
    child: NestedScrollView(
      headerSliverBuilder: (context, innerBoxIsScrolled) => [
        SliverToBoxAdapter(child: header),
      ],
      body: body,
    ),
  );
}
