import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

/// Vector icons drawn by the app itself (Lucide, ISC licence).
///
/// They do not depend on the Material Icons font, so they always render on the web build,
/// Android and iOS. Each icon is a 24x24 stroke drawing that takes its colour and size from
/// the surrounding [IconTheme] (navigation bar, buttons...) unless set explicitly.
class AppIcons {
  AppIcons._();

  static const _open =
      '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24" fill="none" stroke="#000000" '
      'stroke-width="2" stroke-linecap="round" stroke-linejoin="round">';
  static const _close = '</svg>';

  /// Home / dashboard.
  static const home = '$_open'
      '<path d="M15 21v-8a1 1 0 0 0-1-1h-4a1 1 0 0 0-1 1v8"/>'
      '<path d="M3 10a2 2 0 0 1 .709-1.528l7-5.999a2 2 0 0 1 2.582 0l7 5.999A2 2 0 0 1 21 10v9a2 2 0 0 1-2 2H5a2 2 0 0 1-2-2z"/>'
      '$_close';

  /// Settings (gear).
  static const settings = '$_open'
      '<path d="M12.22 2h-.44a2 2 0 0 0-2 2v.18a2 2 0 0 1-1 1.73l-.43.25a2 2 0 0 1-2 0l-.15-.08a2 2 0 0 0-2.73.73l-.22.38a2 2 0 0 0 .73 2.73l.15.1a2 2 0 0 1 1 1.72v.51a2 2 0 0 1-1 1.74l-.15.09a2 2 0 0 0-.73 2.73l.22.38a2 2 0 0 0 2.73.73l.15-.08a2 2 0 0 1 2 0l.43.25a2 2 0 0 1 1 1.73V20a2 2 0 0 0 2 2h.44a2 2 0 0 0 2-2v-.18a2 2 0 0 1 1-1.73l.43-.25a2 2 0 0 1 2 0l.15.08a2 2 0 0 0 2.73-.73l.22-.39a2 2 0 0 0-.73-2.73l-.15-.08a2 2 0 0 1-1-1.74v-.5a2 2 0 0 1 1-1.74l.15-.09a2 2 0 0 0 .73-2.73l-.22-.38a2 2 0 0 0-2.73-.73l-.15.08a2 2 0 0 1-2 0l-.43-.25a2 2 0 0 1-1-1.73V4a2 2 0 0 0-2-2z"/>'
      '<circle cx="12" cy="12" r="3"/>'
      '$_close';

  /// Sales / new sale (shopping cart).
  static const cart = '$_open'
      '<circle cx="8" cy="21" r="1"/><circle cx="19" cy="21" r="1"/>'
      '<path d="M2.05 2.05h2l2.66 12.42a2 2 0 0 0 2 1.58h9.78a2 2 0 0 0 1.95-1.57l1.65-7.43H5.12"/>'
      '$_close';

  /// Scan a QR code / barcode.
  static const scanQr = '$_open'
      '<path d="M17 12v4a1 1 0 0 1-1 1h-4"/><path d="M17 3h2a2 2 0 0 1 2 2v2"/><path d="M17 8V7"/>'
      '<path d="M21 17v2a2 2 0 0 1-2 2h-2"/><path d="M3 7V5a2 2 0 0 1 2-2h2"/><path d="M7 17h.01"/>'
      '<path d="M7 21H5a2 2 0 0 1-2-2v-2"/><rect x="7" y="7" width="5" height="5" rx="1"/>'
      '$_close';

  /// Price check (magnifier with a tick).
  static const priceCheck = '$_open'
      '<path d="m21 21-4.34-4.34"/><circle cx="11" cy="11" r="8"/><path d="m8 11 2 2 4-4"/>'
      '$_close';

  /// Reports: line chart that rises over time.
  static const reports = '$_open'
      '<path d="M3 3v16a2 2 0 0 0 2 2h16"/><path d="m19 9-5 5-4-4-3 3"/>'
      '$_close';

  /// Promotions (price tag).
  static const promotions = '$_open'
      '<path d="M12.586 2.586A2 2 0 0 0 11.172 2H4a2 2 0 0 0-2 2v7.172a2 2 0 0 0 .586 1.414l8.704 8.704a2.426 2.426 0 0 0 3.42 0l6.58-6.58a2.426 2.426 0 0 0 0-3.42z"/>'
      '<circle cx="7.5" cy="7.5" r=".5" fill="#000000"/>'
      '$_close';

  /// Team (group of people).
  static const team = '$_open'
      '<path d="M16 21v-2a4 4 0 0 0-4-4H6a4 4 0 0 0-4 4v2"/><circle cx="9" cy="7" r="4"/>'
      '<path d="M22 21v-2a4 4 0 0 0-3-3.87"/><path d="M16 3.13a4 4 0 0 1 0 7.75"/>'
      '$_close';

  /// Notifications (bell).
  static const bell = '$_open'
      '<path d="M10.268 21a2 2 0 0 0 3.464 0"/>'
      '<path d="M3.262 15.326A1 1 0 0 0 4 17h16a1 1 0 0 0 .74-1.673C19.41 13.956 18 12.499 18 8A6 6 0 0 0 6 8c0 4.499-1.411 5.956-2.738 7.326"/>'
      '$_close';

  /// Alerts (ringing bell).
  static const alerts = '$_open'
      '<path d="M10.268 21a2 2 0 0 0 3.464 0"/>'
      '<path d="M22 8c0-2.3-.8-4.3-2-6"/><path d="M2 8c0-2.3.8-4.3 2-6"/>'
      '<path d="M3.262 15.326A1 1 0 0 0 4 17h16a1 1 0 0 0 .74-1.673C19.41 13.956 18 12.499 18 8A6 6 0 0 0 6 8c0 4.499-1.411 5.956-2.738 7.326"/>'
      '$_close';

  /// Inventory (box).
  static const inventory = '$_open'
      '<path d="M11 21.73a2 2 0 0 0 2 0l7-4A2 2 0 0 0 21 16V8a2 2 0 0 0-1-1.73l-7-4a2 2 0 0 0-2 0l-7 4A2 2 0 0 0 3 8v8a2 2 0 0 0 1 1.73z"/>'
      '<path d="M12 22V12"/><path d="m3.3 7 8.7 5 8.7-5"/><path d="m7.5 4.27 9 5.15"/>'
      '$_close';

  /// Customers (single person).
  static const customers = '$_open'
      '<path d="M19 21v-2a4 4 0 0 0-4-4H9a4 4 0 0 0-4 4v2"/><circle cx="12" cy="7" r="4"/>'
      '$_close';
}

/// Draws one of the [AppIcons]. Colour and size default to the ambient [IconTheme],
/// so it can be dropped in wherever an [Icon] was used.
class AppIcon extends StatelessWidget {
  final String svg;
  final double? size;
  final Color? color;
  const AppIcon(this.svg, {super.key, this.size, this.color});

  @override
  Widget build(BuildContext context) {
    final theme = IconTheme.of(context);
    final s = size ?? theme.size ?? 24;
    final c = color ?? theme.color ?? Theme.of(context).colorScheme.onSurface;
    return SvgPicture.string(
      svg,
      width: s,
      height: s,
      colorFilter: ColorFilter.mode(c, BlendMode.srcIn),
    );
  }
}
