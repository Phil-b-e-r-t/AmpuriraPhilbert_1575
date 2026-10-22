import 'package:flutter/material.dart';
import 'theme.dart';

extension Ctx on BuildContext {
  Color get primary => Theme.of(this).colorScheme.primary;
  void snack(String m) => ScaffoldMessenger.of(this)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(m)));
}

PreferredSizeWidget appBar(BuildContext c, String title,
        {bool back = true, List<Widget>? actions}) =>
    AppBar(
      automaticallyImplyLeading: false,
      leading: back
          ? IconButton(
              icon: const Icon(Icons.arrow_back),
              onPressed: () => Navigator.maybePop(c))
          : null,
      title: Text(title,
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
      centerTitle: false,
      titleSpacing: back ? 0 : 20,
      backgroundColor: Colors.white,
      elevation: 0,
      scrolledUnderElevation: 0,
      actions: actions,
      bottom: const PreferredSize(
          preferredSize: Size.fromHeight(1),
          child: Divider(height: 1, color: C.border)),
    );

class PrimaryButton extends StatefulWidget {
  final String label;
  final VoidCallback? onTap;
  final IconData? icon;
  final bool outlined, loading;
  final Color? color;
  const PrimaryButton(this.label,
      {super.key,
      this.onTap,
      this.icon,
      this.outlined = false,
      this.loading = false,
      this.color});

  @override
  State<PrimaryButton> createState() => _PrimaryButtonState();
}

class _PrimaryButtonState extends State<PrimaryButton> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final active = widget.onTap != null && !widget.loading;
    final baseColor = widget.color ?? context.primary;
    final child = widget.loading
        ? const SizedBox(
            width: 20,
            height: 20,
            child:
                CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
        : Row(mainAxisSize: MainAxisSize.min, children: [
            if (widget.icon != null) ...[
              Icon(widget.icon, size: 18),
              const SizedBox(width: 8)
            ],
            Text(widget.label,
                style:
                    const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
          ]);
    final shape =
        RoundedRectangleBorder(borderRadius: BorderRadius.circular(8));
    return MouseRegion(
      cursor: active ? SystemMouseCursors.click : SystemMouseCursors.basic,
      onEnter: active ? (_) => setState(() => _hovered = true) : null,
      onExit: (_) => setState(() => _hovered = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 140),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(8),
          boxShadow: _hovered && active
              ? [
                  BoxShadow(
                    color: baseColor.withValues(alpha: .22),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  )
                ]
              : const [],
        ),
        child: SizedBox(
          width: double.infinity,
          height: 48,
          child: widget.outlined
              ? OutlinedButton(
                  onPressed: active ? widget.onTap : null,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: baseColor,
                    backgroundColor: _hovered && active
                        ? baseColor.withValues(alpha: .08)
                        : Colors.transparent,
                    overlayColor: baseColor.withValues(alpha: .1),
                    side: BorderSide(
                        color: _hovered && active
                            ? baseColor
                            : widget.color == null
                                ? context.primary
                                : C.border),
                    shape: shape,
                  ),
                  child: child)
              : ElevatedButton(
                  onPressed: active ? widget.onTap : null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _hovered && active
                        ? Color.lerp(context.primary, Colors.black, .1)
                        : context.primary,
                    foregroundColor: Colors.white,
                    overlayColor: Colors.white.withValues(alpha: .12),
                    elevation: _hovered && active ? 2 : 0,
                    shape: shape,
                  ),
                  child: child),
        ),
      ),
    );
  }
}

class AppField extends StatelessWidget {
  final String hint;
  final IconData? icon;
  final TextEditingController? controller;
  final bool obscure;
  final Widget? suffix;
  final TextInputType? type;
  final ValueChanged<String>? onChanged;
  const AppField(this.hint,
      {super.key,
      this.icon,
      this.controller,
      this.obscure = false,
      this.suffix,
      this.type,
      this.onChanged});

  @override
  Widget build(BuildContext context) {
    OutlineInputBorder b(Color c) => OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: BorderSide(color: c));
    return TextField(
      controller: controller,
      obscureText: obscure,
      keyboardType: type,
      onChanged: onChanged,
      style: const TextStyle(fontSize: 13),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: const TextStyle(color: C.grey, fontSize: 13),
        prefixIcon: icon == null ? null : Icon(icon, size: 18, color: C.grey),
        suffixIcon: suffix,
        isDense: true,
        contentPadding:
            const EdgeInsets.symmetric(vertical: 14, horizontal: 12),
        enabledBorder: b(C.border),
        border: b(C.border),
        focusedBorder: b(context.primary),
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
      child: Text(t,
          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500)));
}

/// Pill tabs (inventory tabs, report tabs, range tabs)
class SegTabs extends StatelessWidget {
  final List<String> labels;
  final int index;
  final ValueChanged<int> onChanged;
  const SegTabs(this.labels, this.index, this.onChanged, {super.key});
  @override
  Widget build(BuildContext context) => Row(
        children: [
          for (var i = 0; i < labels.length; i++)
            Expanded(
              child: _SegTab(
                  label: labels[i],
                  selected: i == index,
                  isLast: i == labels.length - 1,
                  onTap: () => onChanged(i)),
            ),
        ],
      );
}

class _SegTab extends StatefulWidget {
  final String label;
  final bool selected, isLast;
  final VoidCallback onTap;
  const _SegTab(
      {required this.label,
      required this.selected,
      required this.isLast,
      required this.onTap});

  @override
  State<_SegTab> createState() => _SegTabState();
}

class _SegTabState extends State<_SegTab> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) => MouseRegion(
        cursor: SystemMouseCursors.click,
        onEnter: (_) => setState(() => _hovered = true),
        onExit: (_) => setState(() => _hovered = false),
        child: GestureDetector(
          onTap: widget.onTap,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 140),
            margin: EdgeInsets.only(right: widget.isLast ? 0 : 8),
            padding: const EdgeInsets.symmetric(vertical: 10),
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: widget.selected
                  ? (_hovered
                      ? Color.lerp(context.primary, Colors.black, .08)
                      : context.primary)
                  : _hovered
                      ? context.primary.withValues(alpha: .08)
                      : C.bg,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                  color:
                      widget.selected || _hovered ? context.primary : C.border),
            ),
            child: Text(widget.label,
                style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: widget.selected ? Colors.white : C.grey)),
          ),
        ),
      );
}

/// Product picture. UPLOAD your exported PNGs to assets/images/ (see README).
class ProductImage extends StatelessWidget {
  final String path;
  final double w, h;
  const ProductImage(this.path, {super.key, this.w = 32, this.h = 56});
  @override
  Widget build(BuildContext context) => SizedBox(
        width: w,
        height: h,
        child: path.isEmpty
            ? _fallback()
            : Image.asset(path,
                fit: BoxFit.contain, errorBuilder: (_, __, ___) => _fallback()),
      );
  Widget _fallback() => Container(
        decoration:
            BoxDecoration(color: C.bg, borderRadius: BorderRadius.circular(6)),
        child: const Icon(Icons.inventory_2_outlined, size: 18, color: C.grey),
      );
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
            errorBuilder: (_, __, ___) => Icon(methodIcon(method),
                size: size * .8, color: context.primary)),
      );
}

Future<T?> showSheet<T>(BuildContext c, String title, Widget body) =>
    showModalBottomSheet<T>(
      context: c,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (ctx) => Padding(
        padding: EdgeInsets.fromLTRB(
            20, 12, 20, MediaQuery.of(ctx).viewInsets.bottom + 20),
        child: SingleChildScrollView(
          child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(children: [
                  Expanded(
                      child: Text(title,
                          style: const TextStyle(
                              fontSize: 16, fontWeight: FontWeight.w700))),
                  IconButton(
                      icon: const Icon(Icons.close, size: 20),
                      onPressed: () => Navigator.pop(ctx)),
                ]),
                body,
              ]),
        ),
      ),
    );
