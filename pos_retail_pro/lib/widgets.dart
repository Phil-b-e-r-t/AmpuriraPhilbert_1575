import 'package:flutter/material.dart';
import 'theme.dart';

extension Ctx on BuildContext {
  Color get primary => Theme.of(this).colorScheme.primary;
  bool get wide => MediaQuery.sizeOf(this).width >= kWideBreakpoint;
  void snack(String m) => ScaffoldMessenger.of(this)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(m)));
}

PreferredSizeWidget appBar(BuildContext c, String title,
        {bool back = true, List<Widget>? actions, bool divider = false}) =>
    AppBar(
      automaticallyImplyLeading: false,
      leading: back ? IconButton(icon: const Icon(Icons.arrow_back), onPressed: () => Navigator.maybePop(c)) : null,
      title: Text(title, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w600, color: C.text)),
      centerTitle: false,
      titleSpacing: back ? 0 : 20,
      backgroundColor: Colors.white,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      scrolledUnderElevation: 0,
      actions: [...?actions, const SizedBox(width: 4)],
      bottom: divider
          ? const PreferredSize(preferredSize: Size.fromHeight(1), child: Divider(height: 1, color: C.divider))
          : null,
    );

/// Keeps content readable on large screens by limiting its width and centering it.
class Centered extends StatelessWidget {
  final Widget child;
  final double maxWidth;
  const Centered({super.key, required this.child, this.maxWidth = 960});
  @override
  Widget build(BuildContext context) =>
      Align(alignment: Alignment.topCenter, child: ConstrainedBox(constraints: BoxConstraints(maxWidth: maxWidth), child: child));
}

/// White, flat surface with a thin light-blue outline: the basic building block of every screen.
class AppCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final VoidCallback? onTap;
  final Color? color, borderColor;
  const AppCard({super.key, required this.child, this.padding = const EdgeInsets.all(16), this.onTap, this.color, this.borderColor});
  @override
  Widget build(BuildContext context) => Material(
        color: color ?? Colors.white,
        clipBehavior: Clip.antiAlias,
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10), side: BorderSide(color: borderColor ?? C.border, width: 1.2)),
        child: InkWell(onTap: onTap, child: Padding(padding: padding, child: child)),
      );
}

class SectionTitle extends StatelessWidget {
  final String text;
  final Widget? trailing;
  const SectionTitle(this.text, {super.key, this.trailing});
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: Row(children: [
          Expanded(child: Text(text, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: C.text))),
          if (trailing != null) trailing!,
        ]),
      );
}

/// Small coloured badge (category, stock status, promo).
class Pill extends StatelessWidget {
  final String text;
  final Color color;
  const Pill(this.text, this.color, {super.key});
  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(color: color.withValues(alpha: .12), borderRadius: BorderRadius.circular(20)),
        child: Text(text, style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w700, color: color)),
      );
}

class EmptyState extends StatelessWidget {
  final IconData icon;
  final String title, message;
  const EmptyState(this.icon, this.title, this.message, {super.key});
  @override
  Widget build(BuildContext context) => Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(color: context.primary.withValues(alpha: .08), shape: BoxShape.circle),
                child: Icon(icon, size: 30, color: context.primary)),
            const SizedBox(height: 16),
            Text(title, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
            const SizedBox(height: 6),
            Text(message, textAlign: TextAlign.center, style: const TextStyle(fontSize: 12.5, color: C.grey, height: 1.45)),
          ]),
        ),
      );
}

class PrimaryButton extends StatelessWidget {
  final String label;
  final VoidCallback? onTap;
  final IconData? icon;
  final bool outlined, loading;
  final Color? color;
  final double height;
  const PrimaryButton(this.label,
      {super.key, this.onTap, this.icon, this.outlined = false, this.loading = false, this.color, this.height = 50});

  @override
  Widget build(BuildContext context) {
    final active = onTap != null && !loading;
    final base = color ?? context.primary;
    final shape = RoundedRectangleBorder(borderRadius: BorderRadius.circular(10));
    const textStyle = TextStyle(fontSize: 14.5, fontWeight: FontWeight.w600);
    final child = loading
        ? SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: outlined ? base : Colors.white))
        : Row(mainAxisSize: MainAxisSize.min, children: [
            if (icon != null) ...[Icon(icon, size: 18), const SizedBox(width: 8)],
            Flexible(child: Text(label, overflow: TextOverflow.ellipsis)),
          ]);
    return SizedBox(
      width: double.infinity,
      height: height,
      child: outlined
          ? OutlinedButton(
              onPressed: active ? onTap : null,
              style: OutlinedButton.styleFrom(
                foregroundColor: base,
                backgroundColor: Colors.white,
                side: BorderSide(color: color == null ? base.withValues(alpha: .45) : C.border, width: 1.2),
                shape: shape,
                textStyle: textStyle,
              ),
              child: child)
          : FilledButton(
              onPressed: active ? onTap : null,
              style: FilledButton.styleFrom(
                backgroundColor: base,
                foregroundColor: Colors.white,
                disabledBackgroundColor: C.divider,
                disabledForegroundColor: C.grey,
                elevation: 0,
                shape: shape,
                textStyle: textStyle,
              ),
              child: child),
    );
  }
}

class AppField extends StatelessWidget {
  final String hint;
  final IconData? icon;
  final TextEditingController? controller;
  final bool obscure;

  /// Grey-filled variant used for search boxes.
  final bool soft;
  final Widget? suffix;
  final TextInputType? type;
  final ValueChanged<String>? onChanged, onSubmitted;
  const AppField(this.hint,
      {super.key,
      this.icon,
      this.controller,
      this.obscure = false,
      this.soft = false,
      this.suffix,
      this.type,
      this.onChanged,
      this.onSubmitted});

  @override
  Widget build(BuildContext context) {
    OutlineInputBorder b(Color c, [double w = 1.2]) =>
        OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: c, width: w));
    return TextField(
      controller: controller,
      obscureText: obscure,
      keyboardType: type,
      onChanged: onChanged,
      onSubmitted: onSubmitted,
      style: const TextStyle(fontSize: 14),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: const TextStyle(color: C.hint, fontSize: 14),
        prefixIcon: icon == null ? null : Icon(icon, size: 20, color: C.hint),
        suffixIcon: suffix,
        isDense: true,
        filled: true,
        fillColor: soft ? C.bg : Colors.white,
        contentPadding: const EdgeInsets.symmetric(vertical: 14, horizontal: 14),
        enabledBorder: b(C.border),
        border: b(C.border),
        focusedBorder: b(context.primary, 1.6),
      ),
    );
  }
}

class FieldLabel extends StatelessWidget {
  final String t;
  const FieldLabel(this.t, {super.key});
  @override
  Widget build(BuildContext context) => Padding(
      padding: const EdgeInsets.only(bottom: 6, top: 14),
      child: Text(t, style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w500, color: C.text)));
}

/// Tab buttons (inventory filters, report types, ranges): the active one is filled with the brand
/// colour, the others are white with a light outline.
class SegTabs extends StatelessWidget {
  final List<String> labels;
  final int index;
  final ValueChanged<int> onChanged;
  const SegTabs(this.labels, this.index, this.onChanged, {super.key});
  @override
  Widget build(BuildContext context) {
    final primary = context.primary;
    return Row(children: [
      for (var i = 0; i < labels.length; i++) ...[
        if (i > 0) const SizedBox(width: 8),
        Expanded(
          child: Material(
            color: i == index ? primary : Colors.white,
            clipBehavior: Clip.antiAlias,
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
                side: BorderSide(color: i == index ? primary : C.border, width: 1.2)),
            child: InkWell(
              onTap: () => onChanged(i),
              child: Container(
                height: 40,
                alignment: Alignment.center,
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: Text(labels[i],
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                        fontSize: 12.5, fontWeight: FontWeight.w600, color: i == index ? Colors.white : C.text)),
              ),
            ),
          ),
        ),
      ],
    ]);
  }
}

/// Product picture. Falls back to a coloured tile with the product's first letter.
class ProductImage extends StatelessWidget {
  final String path, name;
  final double w, h;
  const ProductImage(this.path, {super.key, this.w = 32, this.h = 56, this.name = ''});
  @override
  Widget build(BuildContext context) {
    final assetPath = path == 'assets/images/coca.png' ? 'assets/images/coke.png' : path;
    return SizedBox(
      width: w,
      height: h,
      child: assetPath.isEmpty
          ? _fallback(context)
          : Image.asset(assetPath, fit: BoxFit.contain, errorBuilder: (_, __, ___) => _fallback(context)),
    );
  }

  Widget _fallback(BuildContext context) {
    final side = (w.isFinite ? w : 60) < (h.isFinite ? h : 60) ? (w.isFinite ? w : 60) : (h.isFinite ? h : 60);
    return Container(
      decoration: BoxDecoration(color: context.primary.withValues(alpha: .10), borderRadius: BorderRadius.circular(10)),
      alignment: Alignment.center,
      child: name.isEmpty
          ? Icon(Icons.inventory_2_outlined, size: 18, color: context.primary)
          : Text(name.trim().isEmpty ? '?' : name.trim()[0].toUpperCase(),
              style: TextStyle(fontSize: side * .42, fontWeight: FontWeight.w800, color: context.primary)),
    );
  }
}

String methodKey(String m) => switch (m) {
      'Cash' => 'cash',
      'Card' => 'card',
      'Mobile Money' => 'momo',
      'Bank Transfer' => 'bank',
      _ => 'paypal',
    };

IconData methodIcon(String m) => switch (m) {
      'Cash' => Icons.payments_outlined,
      'Card' => Icons.credit_card,
      'Mobile Money' => Icons.smartphone,
      'Bank Transfer' => Icons.account_balance,
      _ => Icons.paypal,
    };

/// Payment icon: uses assets/images/pay_<key>.png if you uploaded it, else a Material icon.
class MethodIcon extends StatelessWidget {
  final String method;
  final double size;
  const MethodIcon(this.method, {super.key, this.size = 26});
  @override
  Widget build(BuildContext context) => SizedBox(
        width: size,
        height: size,
        child: Image.asset('assets/images/pay_${methodKey(method)}.png',
            fit: BoxFit.contain,
            errorBuilder: (_, __, ___) => Icon(methodIcon(method), size: size * .8, color: context.primary)),
      );
}

Future<T?> showSheet<T>(BuildContext c, String title, Widget body) => showModalBottomSheet<T>(
      context: c,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.white,
      constraints: const BoxConstraints(maxWidth: 560),
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(18))),
      builder: (ctx) => Padding(
        padding: EdgeInsets.fromLTRB(20, 8, 20, MediaQuery.of(ctx).viewInsets.bottom + 20),
        child: SingleChildScrollView(
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
            Center(
                child: Container(
                    width: 40,
                    height: 4,
                    margin: const EdgeInsets.only(bottom: 8),
                    decoration: BoxDecoration(color: C.divider, borderRadius: BorderRadius.circular(2)))),
            Row(children: [
              Expanded(child: Text(title, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700, color: C.text))),
              IconButton(icon: const Icon(Icons.close, size: 20), onPressed: () => Navigator.pop(ctx)),
            ]),
            body,
          ]),
        ),
      ),
    );
