import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../money/money.dart';
import '../providers.dart';

/// AsyncValue icin yukleniyor/hata/veri govdesi.
class AsyncBody<T> extends ConsumerWidget {
  const AsyncBody({
    super.key,
    required this.value,
    required this.builder,
    this.onRetry,
  });

  final AsyncValue<T> value;
  final Widget Function(T data) builder;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = ref.watch(tokensProvider);
    final s = ref.watch(stringsProvider);
    return value.when(
      data: builder,
      loading: () => Center(
        child: CircularProgressIndicator(color: t.color('accent')),
      ),
      error: (e, _) => Center(
        child: Padding(
          padding: EdgeInsets.all(t.screenPadding),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(LucideIcons.alertCircle, color: t.color('negative'), size: 36),
              SizedBox(height: t.spacing('md')),
              Text(s('common.error'), textAlign: TextAlign.center),
              SizedBox(height: t.spacing('xs')),
              Text(
                '$e',
                textAlign: TextAlign.center,
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: t.fontSize('caption'),
                  color: t.color('textSecondary'),
                ),
              ),
              if (onRetry != null) ...[
                SizedBox(height: t.spacing('lg')),
                OutlinedButton(
                  onPressed: onRetry,
                  style: OutlinedButton.styleFrom(
                    minimumSize: Size(140, t.minTouchTarget),
                  ),
                  child: Text(s('common.retry')),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class EmptyView extends ConsumerWidget {
  const EmptyView({super.key, this.message, this.icon = LucideIcons.inbox});

  final String? message;
  final IconData icon;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = ref.watch(tokensProvider);
    final s = ref.watch(stringsProvider);
    return Center(
      child: Padding(
        padding: EdgeInsets.all(t.spacing('xxl')),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 40, color: t.color('neutral')),
            SizedBox(height: t.spacing('md')),
            Text(
              message ?? s('common.empty'),
              textAlign: TextAlign.center,
              style: TextStyle(color: t.color('textSecondary')),
            ),
          ],
        ),
      ),
    );
  }
}

/// Tutar metni. [signed] ise pozitif yesil / negatif kirmizi; degilse notr.
class MoneyText extends ConsumerWidget {
  const MoneyText(
    this.minor, {
    super.key,
    this.signed = false,
    this.style,
    this.showSymbol = true,
  });

  final int minor;
  final bool signed;
  final TextStyle? style;
  final bool showSymbol;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = ref.watch(tokensProvider);
    Color? color;
    if (signed && minor > 0) color = t.color('positive');
    if (signed && minor < 0) color = t.color('negative');
    return Text(
      showSymbol ? formatMinorTry(minor) : formatMinor(minor),
      style: (style ?? const TextStyle()).copyWith(
        color: color ?? style?.color,
        fontFeatures: const [FontFeature.tabularFigures()],
      ),
    );
  }
}

/// Durum rozeti (token renginde).
class StatusChip extends StatelessWidget {
  const StatusChip({super.key, required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.16),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 12,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

/// Arama kutusu.
class SearchBox extends ConsumerWidget {
  const SearchBox({super.key, required this.onChanged});

  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(stringsProvider);
    return TextField(
      onChanged: onChanged,
      textInputAction: TextInputAction.search,
      decoration: InputDecoration(
        hintText: s('common.search'),
        prefixIcon: const Icon(LucideIcons.search, size: 20),
        isDense: true,
      ),
    );
  }
}

/// Tutar girdisi icin: rakam, nokta, virgul, eksi.
final moneyInputFormatters = <TextInputFormatter>[
  FilteringTextInputFormatter.allow(RegExp(r'[0-9.,\-]')),
];

const moneyKeyboard = TextInputType.numberWithOptions(decimal: true, signed: false);

/// Basari / hata bildirimleri (docs/04 §9: yesil/kirmizi).
void showSuccess(BuildContext context, WidgetRef ref, String message) {
  _toast(context, ref, message, ref.read(tokensProvider).color('positive'));
}

void showError(BuildContext context, WidgetRef ref, String message) {
  _toast(context, ref, message, ref.read(tokensProvider).color('negative'));
}

void showWarning(BuildContext context, WidgetRef ref, String message) {
  _toast(context, ref, message, ref.read(tokensProvider).color('warning'));
}

void _toast(BuildContext context, WidgetRef ref, String message, Color color) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: color,
        behavior: SnackBarBehavior.floating,
      ),
    );
}

/// Onay penceresi (iptal / ters kayit islemlerinden once, docs/04 §9).
Future<bool> confirmDialog(
  BuildContext context,
  WidgetRef ref, {
  required String message,
}) async {
  final s = ref.read(stringsProvider);
  final res = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      content: Text(message),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx, false),
          child: Text(s('common.cancel')),
        ),
        TextButton(
          onPressed: () => Navigator.pop(ctx, true),
          child: Text(s('common.confirm')),
        ),
      ],
    ),
  );
  return res ?? false;
}
