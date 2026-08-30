import 'package:pos_desktop/utils/snackbar_utils.dart';
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

  void initializeCouponFromPosState(PosStateNotifier posState) {
    final code = posState.appliedCouponCode;
    if (code == null || code.isEmpty || posState.couponDiscountAmount <= 0) {
      return;
    }
    couponCtrl.text = code;
    couponApplied = true;
    couponResult = CouponValidationResult.valid(
      couponCode: code,
      discountValue: posState.couponDiscountAmount,
      rewardName: null,
      customerName: posState.currentCustomer?.name,
      expiresAt: null,
      status: posState.isSourceCouponLocked ? 'RESERVED' : 'ACTIVE',
      reservedOnlineOrderId: posState.sourceOnlineOrderId,
    );
  }

  bool clearCoupon(PosStateNotifier posState) {
    if (posState.isSourceCouponLocked) {
      SnackbarUtils.showLeft(context,
          'คูปองนี้ถูกสำรองมากับออเดอร์ออนไลน์ ต้องยกเลิกหรือปฏิเสธออเดอร์เพื่อคืนคูปอง');
      return false;
    }
    setState(() {
      couponApplied = false;
      couponResult = null;
      couponCtrl.clear();
      posState.applyCouponDiscount(0, null);
    });
    return true;
  }

  Future<void> validateAndApplyCoupon(
      PosStateNotifier posState, VoidCallback onUpdateRemainingAmount) async {
    final code = couponCtrl.text.trim().toUpperCase();
    if (code.isEmpty) return;
    final customer = posState.currentCustomer;
    if (customer == null || customer.id <= 0) {
      SnackbarUtils.showLeft(
          context, 'กรุณาเลือกลูกค้าที่เป็นเจ้าของคูปองก่อนใช้สิทธิ์');
      return;
    }

    setState(() {
      isValidatingCoupon = true;
      couponResult = null;
    });

    final repo = RewardRepository();
    final result = await repo.validateCoupon(
      code,
      customerId: customer.id,
      sourceOnlineOrderId: posState.sourceOnlineOrderId,
    );

    if (!mounted) return;

    setState(() {
      isValidatingCoupon = false;
      couponResult = result;
    });

    if (result.isValid) {
      if ((result.discountValue ?? 0) > posState.pointRedemptionBase) {
        setState(() {
          couponResult = CouponValidationResult.invalid(
              'มูลค่าคูปองสูงกว่ายอดสินค้าหลังส่วนลด จึงใช้กับบิลนี้ไม่ได้');
        });
        return;
      }
      if (posState.pointsToRedeem > 0) {
        posState.clearPointDiscount();
        SnackbarUtils.showLeft(
            context, 'ล้างการแลกแต้มแล้ว เพราะคูปองใช้ร่วมกับแต้มไม่ได้');
      }
      // Auto-apply
      posState.applyCouponDiscount(
          result.discountValue ?? 0, result.couponCode);
      setState(() => couponApplied = true);

      onUpdateRemainingAmount();

      if (mounted) {
        SnackbarUtils.showLeft(context,
            '🎟️ ใช้คูปอง ${result.couponCode} — ลด ฿${result.discountValue?.toStringAsFixed(2)}');
      }
    }
  }
}
