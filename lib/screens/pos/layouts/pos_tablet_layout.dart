import 'package:flutter/material.dart';

class PosTabletLayout extends StatelessWidget {
  final Widget controlBar;
  final Widget cartList;
  final Widget shortcutBar;
  final Widget paymentPanel;
  final double maxHeight;

  const PosTabletLayout({
    super.key,
    required this.controlBar,
    required this.cartList,
    required this.shortcutBar,
    required this.paymentPanel,
    required this.maxHeight,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        controlBar,
        Expanded(child: cartList),
        shortcutBar,
        const Divider(height: 1),
        SizedBox(
          height: maxHeight * 0.45,
          child: paymentPanel,
        ),
      ],
    );
  }
}
