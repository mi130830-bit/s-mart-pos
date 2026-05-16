import 'package:flutter/material.dart';
import '../../../../repositories/reward_repository.dart';
import '../../pos_state_manager.dart';

mixin CouponControllerMixin<T extends StatefulWidget> on State<T> {
  final TextEditingController couponCtrl = TextEditingController();
  bool isValidatingCoupon = false;
  CouponValidationResult? couponResult;
  bool couponApplied = false;

  void disposeCouponController() {
    couponCtrl.dispose();
  }

  void clearCoupon(PosStateManager posState) {
    setState(() {
      couponApplied = false;
      couponResult = null;
      couponCtrl.clear();
      posState.applyCouponDiscount(0, null);
    });
  }

  Future<void> validateAndApplyCoupon(
      PosStateManager posState, VoidCallback onUpdateRemainingAmount) async {
    final code = couponCtrl.text.trim().toUpperCase();
    if (code.isEmpty) return;

    setState(() {
      isValidatingCoupon = true;
      couponResult = null;
    });

    final repo = RewardRepository();
    final result = await repo.validateCoupon(code);

    if (!mounted) return;

    setState(() {
      isValidatingCoupon = false;
      couponResult = result;
    });

    if (result.isValid) {
      // Auto-apply
      posState.applyCouponDiscount(
          result.discountValue ?? 0, result.couponCode);
      setState(() => couponApplied = true);
      
      onUpdateRemainingAmount();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(
              '🎟️ ใช้คูปอง ${result.couponCode} — ลด ฿${result.discountValue?.toStringAsFixed(2)}'),
          backgroundColor: Colors.green,
        ));
      }
    }
  }
}
