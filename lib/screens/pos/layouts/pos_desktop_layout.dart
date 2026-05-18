import 'package:flutter/material.dart';

class PosDesktopLayout extends StatelessWidget {
  final Widget controlBar;
  final Widget cartList;
  final Widget shortcutBar;
  final Widget paymentPanel;

  const PosDesktopLayout({
    super.key,
    required this.controlBar,
    required this.cartList,
    required this.shortcutBar,
    required this.paymentPanel,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          flex: 3,
          child: Column(
            children: [
              controlBar,
              Expanded(child: cartList),
              shortcutBar,
            ],
          ),
        ),
        const VerticalDivider(width: 1),
        Expanded(
          flex: 1,
          child: paymentPanel,
        ),
      ],
    );
  }
}
