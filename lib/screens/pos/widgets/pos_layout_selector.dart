import 'package:flutter/material.dart';
import '../layouts/pos_desktop_layout.dart';
import '../layouts/pos_tablet_layout.dart';

class PosLayoutSelector extends StatelessWidget {
  final Widget controlBar;
  final Widget cartList;
  final Widget shortcutBar;
  final Widget paymentPanel;

  const PosLayoutSelector({
    super.key,
    required this.controlBar,
    required this.cartList,
    required this.shortcutBar,
    required this.paymentPanel,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isWide = constraints.maxWidth > 900;
        if (isWide) {
          return PosDesktopLayout(
            controlBar: controlBar,
            cartList: cartList,
            shortcutBar: shortcutBar,
            paymentPanel: paymentPanel,
          );
        } else {
          return PosTabletLayout(
            controlBar: controlBar,
            cartList: cartList,
            shortcutBar: shortcutBar,
            paymentPanel: paymentPanel,
            maxHeight: constraints.maxHeight,
          );
        }
      },
    );
  }
}
