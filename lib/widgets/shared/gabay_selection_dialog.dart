import 'gabay_modal_motion.dart';
import '../../theme/gabay_typography.dart';
import 'package:flutter/material.dart';
import '../../theme/gabay_theme.dart';

class GabaySelectionOption<T> {
  const GabaySelectionOption({
    required this.value,
    required this.child,
    this.enabled = true,
    this.searchText = '',
  });
  final T value;
  final Widget child;
  final bool enabled;
  final String searchText;
}

Future<T?> showGabaySelectionDialog<T>(
  BuildContext context, {
  required String title,
  required List<GabaySelectionOption<T>> options,
  T? selectedValue,
  String? subtitle,
  bool searchable = false,
}) {
  FocusScope.of(context).unfocus();
  return showDialog<T>(
    animationStyle: gabayModalAnimation(context),
    context: context,
    barrierColor: Colors.black.withValues(alpha: .32),
    builder: (_) => _SelectionDialog<T>(
      title: title,
      options: options,
      selectedValue: selectedValue,
      subtitle: subtitle,
      searchable: searchable,
    ),
  );
}

class _SelectionDialog<T> extends StatefulWidget {
  const _SelectionDialog({
    required this.title,
    required this.options,
    required this.selectedValue,
    required this.searchable,
    this.subtitle,
  });
  final String title;
  final String? subtitle;
  final List<GabaySelectionOption<T>> options;
  final T? selectedValue;
  final bool searchable;
  @override
  State<_SelectionDialog<T>> createState() => _SelectionDialogState<T>();
}

class _SelectionDialogState<T> extends State<_SelectionDialog<T>> {
  String _search = '';
  @override
  Widget build(BuildContext context) {
    final g = context.gabay;
    final options = widget.options
        .where(
          (option) =>
              option.searchText.toLowerCase().contains(_search.toLowerCase()),
        )
        .toList();
    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
      child: DecoratedBox(
        decoration: GabayTheme.cardDecoration(
          context,
        ).copyWith(boxShadow: const []),
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxWidth: 440,
            maxHeight: MediaQuery.sizeOf(context).height * .75,
          ),
          child: SizedBox(
            width: 440,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          widget.title,
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                      ),
                      IconButton(
                        tooltip: 'Close ${widget.title}',
                        onPressed: () => Navigator.pop(context),
                        icon: const Icon(Icons.close_rounded, size: 21),
                      ),
                    ],
                  ),
                  if (widget.subtitle != null)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: Text(
                        widget.subtitle!,
                        style: GabayTheme.bodyMedium(context),
                      ),
                    ),
                  if (widget.searchable)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: TextField(
                        decoration: InputDecoration(
                          hintText: 'Search ${widget.title}',
                          prefixIcon: const Icon(Icons.search_rounded),
                        ),
                        onChanged: (value) => setState(() => _search = value),
                      ),
                    ),
                  Flexible(
                    child: options.isEmpty
                        ? Padding(
                            padding: const EdgeInsets.all(20),
                            child: Text(
                              'No options found',
                              style: GabayTheme.bodyMedium(context),
                            ),
                          )
                        : ListView.separated(
                            shrinkWrap: true,
                            padding: const EdgeInsets.only(top: 8),
                            itemCount: options.length,
                            separatorBuilder: (_, index) =>
                                const SizedBox(height: 8),
                            itemBuilder: (context, index) {
                              final option = options[index];
                              final selected =
                                  option.value == widget.selectedValue;
                              return Semantics(
                                selected: selected,
                                button: true,
                                enabled: option.enabled,
                                child: Material(
                                  color: selected
                                      ? g.accentTint
                                      : g.chipBackground,
                                  borderRadius: BorderRadius.circular(16),
                                  child: InkWell(
                                    borderRadius: BorderRadius.circular(16),
                                    onTap: option.enabled
                                        ? () => Navigator.pop(
                                            context,
                                            option.value,
                                          )
                                        : null,
                                    child: ConstrainedBox(
                                      constraints: const BoxConstraints(
                                        minHeight: 48,
                                      ),
                                      child: Padding(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 14,
                                          vertical: 12,
                                        ),
                                        child: Row(
                                          children: [
                                            Expanded(
                                              child: DefaultTextStyle(
                                                style: TextStyle(
                                                  color: option.enabled
                                                      ? g.textPrimary
                                                      : g.textSecondary,
                                                  fontSize:
                                                      GabayTypography.body,
                                                  fontWeight:
                                                      GabayTypography.regular,
                                                ),
                                                child: option.child,
                                              ),
                                            ),
                                            const SizedBox(width: 12),
                                            selected
                                                ? Icon(
                                                    Icons.check_rounded,
                                                    color: g.accent,
                                                    size: 22,
                                                  )
                                                : const SizedBox(width: 22),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              );
                            },
                          ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Retains normal FormField validation/save semantics; only the picker changes.
class GabayDropdownFormField<T> extends FormField<T> {
  GabayDropdownFormField({
    super.key,
    T? initialValue,
    T? value,
    required this.items,
    required this.onChanged,
    this.dialogTitle,
    this.decoration = const InputDecoration(),
    this.hint,
    this.icon,
    this.style,
    bool isExpanded = true,
    Color? dropdownColor,
    super.validator,
    super.onSaved,
    super.autovalidateMode,
  }) : super(
         initialValue: initialValue ?? value,
         enabled: onChanged != null && items?.isNotEmpty == true,
         builder: (field) =>
             (field as _GabayDropdownFormFieldState<T>).buildField(),
       );
  final List<DropdownMenuItem<T>>? items;
  final ValueChanged<T?>? onChanged;
  final String? dialogTitle;
  final InputDecoration decoration;
  final Widget? hint, icon;
  final TextStyle? style;
  @override
  FormFieldState<T> createState() => _GabayDropdownFormFieldState<T>();
}

class _GabayDropdownFormFieldState<T> extends FormFieldState<T> {
  @override
  GabayDropdownFormField<T> get widget =>
      super.widget as GabayDropdownFormField<T>;
  bool _opening = false;
  @override
  void didUpdateWidget(covariant GabayDropdownFormField<T> oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.initialValue != widget.initialValue) {
      setValue(widget.initialValue);
    }
  }

  Future<void> _choose() async {
    if (_opening || !widget.enabled) return;
    _opening = true;
    try {
      final selected = await showGabaySelectionDialog<T>(
        context,
        title:
            widget.dialogTitle ??
            widget.decoration.labelText ??
            'Select an option',
        selectedValue: value,
        options: [
          for (final item in widget.items ?? <DropdownMenuItem<T>>[])
            if (item.value != null)
              GabaySelectionOption<T>(
                value: item.value as T,
                child: item.child,
                enabled: item.enabled,
              ),
        ],
      );
      if (!mounted || !widget.enabled || selected == null) return;
      didChange(selected);
      widget.onChanged?.call(selected);
    } finally {
      _opening = false;
    }
  }

  Widget buildField() {
    final selected = widget.items
        ?.where((item) => item.value == value)
        .firstOrNull;
    return Semantics(
      button: true,
      enabled: widget.enabled,
      child: InkWell(
        onTap: widget.enabled ? _choose : null,
        borderRadius: BorderRadius.circular(GabayMetrics.controlRadius),
        child: InputDecorator(
          isEmpty: false,
          decoration: widget.decoration.copyWith(
            enabled: widget.enabled,
            errorText: errorText,
            suffixIcon:
                widget.icon ?? const Icon(Icons.keyboard_arrow_down_rounded),
          ),
          child: DefaultTextStyle(
            style:
                widget.style ??
                TextStyle(
                  color: context.gabay.textPrimary,
                  fontSize: GabayTypography.body,
                ),
            child:
                selected?.child ??
                widget.hint ??
                const Text('Select an option'),
          ),
        ),
      ),
    );
  }
}
