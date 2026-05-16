import 'package:decimal/decimal.dart';
import '../../models/order_item.dart';
import '../../models/customer.dart';
import '../../models/member_tier.dart';
import '../../models/product.dart';
import '../../models/product_price_tier.dart';
import '../../models/promotion.dart';

/// ผลลัพธ์โปรโมชั่นที่ apply แล้ว
class PromotionResult {
  final Decimal discountAmount;
  final Promotion? appliedPromotion; // โปรที่ถูก apply
  final List<FreeItemRequest> freeItems; // รายการแถมฟรีที่ต้องเพิ่มลงตะกร้า

  PromotionResult({
    Decimal? discountAmount,
    this.appliedPromotion,
    this.freeItems = const [],
  }) : discountAmount = discountAmount ?? Decimal.zero;
}

/// รายการโปรแถมฟรี
class FreeItemRequest {
  final int productId;
  final double quantity;
  FreeItemRequest({required this.productId, required this.quantity});
}

enum VatType {
  none('ไม่คิด'),
  included('Vat In'),
  excluded('Vat Out');

  final String label;
  const VatType(this.label);
}

class PriceCalculationResult {
  final Decimal totalBeforeDiscount;
  final Decimal billDiscountAmount; // Original manual discount
  final Decimal extraDiscountAmount; // ✅ New Extra Manual Discount
  final Decimal subtotalAfterBillDiscount;
  final Decimal promoDiscountAmount;
  final Decimal subtotalAfterPromo;
  final Decimal pointDiscountAmount; // ✅ ส่วนลดแต้ม
  final Decimal subtotalAfterPoints; // ✅ ยอดหลังหักแต้ม
  final Decimal vatAmount;
  final Decimal grandTotal;
  final Decimal netTotal; // Excludes VAT if VAT is included

  PriceCalculationResult({
    required this.totalBeforeDiscount,
    required this.billDiscountAmount,
    required this.extraDiscountAmount,
    required this.subtotalAfterBillDiscount,
    required this.promoDiscountAmount,
    required this.subtotalAfterPromo,
    required this.pointDiscountAmount,
    required this.subtotalAfterPoints,
    required this.vatAmount,
    required this.grandTotal,
    required this.netTotal,
  });
}

class PriceCalculationService {
  // Helper to convert double to Decimal
  Decimal toDecimal(double val) => Decimal.parse(val.toString());

  // Configs
  double _globalMemberDiscountRate = 0.0;

  void updateSettings({double? memberDiscountRate}) {
    if (memberDiscountRate != null) {
      _globalMemberDiscountRate = memberDiscountRate;
    }
  }

  Decimal calculateUnitPrice({
    required Product product,
    required Decimal quantity,
    Customer? customer,
    MemberTier? customerTier,
  }) {
    // 1. Base Price (Retail / Wholesale / Member)
    Decimal basePrice = product.retailPriceDecimal;

    if (customer != null) {
      if (customerTier != null) {
        if (customerTier.priceLevel == 'wholesale') {
          basePrice = product.wholesalePriceDecimal != Decimal.zero
              ? product.wholesalePriceDecimal
              : product.retailPriceDecimal;
        } else if (customerTier.priceLevel == 'member') {
          if (product.memberRetailPrice != null &&
              product.memberRetailPrice! > 0) {
            basePrice = product.memberRetailPriceDecimal;
          }
        }
      }
      // Fallback: If no tier logic, check legacy member price
      else if (product.memberRetailPrice != null &&
          product.memberRetailPrice! > 0) {
        basePrice = product.memberRetailPriceDecimal;
      }
    }

    // 2. Tier Pricing (Based on Quantity) - Volume Pricing overrides others
    if (product.priceTiers != null && product.priceTiers!.isNotEmpty) {
      // Find best tier
      ProductPriceTier? bestTier;
      for (var tier in product.priceTiers!) {
        if (quantity >= toDecimal(tier.minQuantity.toDouble())) {
          if (bestTier == null || tier.minQuantity > bestTier.minQuantity) {
            bestTier = tier;
          }
        }
      }

      if (bestTier != null) {
        basePrice = toDecimal(bestTier.price);
      }
    }

    return basePrice;
  }

  /// Update item totals (price * qty - itemDiscount)
  OrderItem recalculateItemTotal(OrderItem item) {
    // Recalculate Total
    // total = (price * quantity) - discount
    final rawTotal = item.price * item.quantity;
    final netTotal = rawTotal - item.discount;

    return item.copyWith(total: netTotal);
  }


  /// ✅ คำนวณโปรโมชั่น — Priority-Only (apply แค่โปรอันดับสูงสุดที่ qualify)
  PromotionResult calculatePromotions(
      List<OrderItem> cart, List<Promotion> activePromotions) {
    if (activePromotions.isEmpty || cart.isEmpty) {
      return PromotionResult();
    }

    Decimal cartTotal = Decimal.zero;
    for (var item in cart) {
      cartTotal += item.total;
    }

    // เรียง Priority DESC — เอาอันดับสูงสุดก่อนเสมอ
    final sorted = List<Promotion>.from(activePromotions)
      ..sort((a, b) {
        if (b.priority != a.priority) return b.priority.compareTo(a.priority);
        return b.id.compareTo(a.id);
      });

    for (var promo in sorted) {
      if (!promo.isValid) continue;

      final conditions = promo.conditions;
      final rewards = promo.rewards;

      bool requirementsMet = false;
      int sets = 0;

      // --- A. ยอดขั้นต่ำ (min_spend) ---
      if (conditions.containsKey('min_spend')) {
        final minSpend =
            toDecimal(double.tryParse(conditions['min_spend'].toString()) ?? 0);
        if (cartTotal >= minSpend) {
          requirementsMet = true;
          sets = 1;
        }
      }

      // --- B. ซื้อตามจำนวน (buy_items) ---
      else if (conditions.containsKey('buy_items')) {
        final buyItems = conditions['buy_items'];
        if (buyItems is List && buyItems.isNotEmpty) {
          final req = buyItems.first;
          final reqProdId = int.tryParse(req['product_id'].toString()) ?? 0;
          final reqQty =
              toDecimal(double.tryParse(req['qty'].toString()) ?? 0);

          Decimal foundQty = Decimal.zero;
          for (var item in cart) {
            if (item.productId == reqProdId || reqProdId == 0) {
              foundQty += item.quantity;
            }
          }

          if (foundQty >= reqQty && reqQty > Decimal.zero) {
            requirementsMet = true;
            sets = (foundQty.toDouble() / reqQty.toDouble()).floor();
          }
        }
      }

      // --- C. ลดสินค้าเฉพาะ (per_product) ---
      else if (conditions.containsKey('target_products')) {
        final targetIds = (conditions['target_products'] as List? ?? [])
            .map((e) => int.tryParse(e.toString()) ?? 0)
            .where((id) => id > 0)
            .toList();
        bool anyFound = false;
        for (var item in cart) {
          if (targetIds.contains(item.productId)) {
            anyFound = true;
            break;
          }
        }
        if (anyFound) {
          requirementsMet = true;
          sets = 1;
        }
      }

      if (!requirementsMet || sets == 0) continue;

      // --- Apply Rewards ---
      Decimal discount = Decimal.zero;
      final List<FreeItemRequest> freeItems = [];

      final rewardType = rewards['type']?.toString() ?? '';

      if (rewardType == 'discount_amount' ||
          rewards.containsKey('discount_amount')) {
        final amt = toDecimal(
            double.tryParse(rewards['discount_amount'].toString()) ?? 0);
        discount = amt * toDecimal(sets.toDouble());
      } else if (rewardType == 'discount_percent' ||
          rewards.containsKey('discount_percent')) {
        final pct = (toDecimal(
                    double.tryParse(
                            rewards['discount_percent'].toString()) ??
                        0) /
                toDecimal(100))
            .toDecimal(scaleOnInfinitePrecision: 10);

        if (conditions.containsKey('min_spend')) {
          // ลด % จากยอดรวม
          discount = cartTotal * pct;
        } else if (conditions.containsKey('target_products')) {
          // ลด % เฉพาะสินค้าเป้าหมาย
          final targetIds = (conditions['target_products'] as List? ?? [])
              .map((e) => int.tryParse(e.toString()) ?? 0)
              .toList();
          for (var item in cart) {
            if (targetIds.contains(item.productId)) {
              discount += item.total * pct;
            }
          }
        } else {
          discount = cartTotal * pct;
        }
      } else if (rewards.containsKey('get_items')) {
        // ✅ Free Item — ไม่หักเงิน แต่ส่งขอให้ PosStateManager เพิ่มลงตะกร้า
        final getItems = rewards['get_items'];
        if (getItems is List) {
          for (var gi in getItems) {
            final prodId = int.tryParse(gi['product_id'].toString()) ?? 0;
            final qty = double.tryParse(gi['qty'].toString()) ?? 1.0;
            if (prodId > 0) {
              freeItems.add(FreeItemRequest(
                  productId: prodId, quantity: qty * sets));
            }
          }
        }
      }

      // ✅ เจอโปรที่ qualify แล้ว — หยุด (ไม่สะสม)
      return PromotionResult(
        discountAmount: discount,
        appliedPromotion: promo,
        freeItems: freeItems,
      );
    }

    return PromotionResult(); // ไม่มีโปรที่ apply
  }

  /// คำนวณยอดรวม, VAT, ส่วนลดทั้งหมด
  PriceCalculationResult calculateTotals({
    required List<OrderItem> cart,
    required double billDiscountVal,
    required bool isPercentDiscount,
    required double promoDiscountVal,
    double extraDiscountVal = 0.0,
    double pointDiscountAmount = 0.0,
    required VatType vatType,
    Customer? customer,
    MemberTier? tier,
    String? roundingMode,
    double vatRate = 7.0, // ✅ รับ VAT Rate จาก Settings แทน Hardcode
  }) {
    // 1. Sum Item Totals
    Decimal sumTotal = Decimal.zero;
    for (var item in cart) {
      sumTotal += item.total;
    }

    Decimal tierDiscountAmount = Decimal.zero;
    if (tier != null && tier.discountPercentage > 0) {
      final percent = (toDecimal(tier.discountPercentage) / toDecimal(100))
          .toDecimal(scaleOnInfinitePrecision: 10);
      tierDiscountAmount = sumTotal * percent;
    } else if (customer != null && _globalMemberDiscountRate > 0) {
      final percent = (toDecimal(_globalMemberDiscountRate) / toDecimal(100))
          .toDecimal(scaleOnInfinitePrecision: 10);
      tierDiscountAmount = sumTotal * percent;
    }

    Decimal subtotalAfterTier = sumTotal - tierDiscountAmount;

    // 3. Bill Discount 1
    Decimal billDiscountAmount = Decimal.zero;
    if (subtotalAfterTier > Decimal.zero) {
      if (isPercentDiscount) {
        // val is %, e.g. 10.0
        final percent = (toDecimal(billDiscountVal) / toDecimal(100))
            .toDecimal(scaleOnInfinitePrecision: 10);

        billDiscountAmount = subtotalAfterTier * percent;
      } else {
        billDiscountAmount = toDecimal(billDiscountVal);
      }
      // Clamp
      if (billDiscountAmount > subtotalAfterTier) {
        billDiscountAmount = subtotalAfterTier;
      }
    }

    Decimal subtotalAfterBill1 = subtotalAfterTier - billDiscountAmount;

    // 3.5 Extra Bill Discount (Discount 2)
    Decimal extraDiscountAmount = Decimal.zero;
    if (subtotalAfterBill1 > Decimal.zero && extraDiscountVal > 0) {
      extraDiscountAmount = toDecimal(extraDiscountVal);
      if (extraDiscountAmount > subtotalAfterBill1) {
        extraDiscountAmount = subtotalAfterBill1;
      }
    }

    Decimal subtotalAfterBill = subtotalAfterBill1 - extraDiscountAmount;

    // 4. Promo Discount
    Decimal promoDiscount = toDecimal(promoDiscountVal);
    if (promoDiscount > subtotalAfterBill) {
      promoDiscount = subtotalAfterBill;
    }

    Decimal subtotalAfterPromo = subtotalAfterBill - promoDiscount;

    // 5. Point Redemption Discount (ก่อน VAT)
    Decimal pointDiscount = toDecimal(pointDiscountAmount);
    if (pointDiscount > subtotalAfterPromo) {
      pointDiscount = subtotalAfterPromo; // ไม่ให้ยอดติดลบ
    }
    Decimal subtotalAfterPts = subtotalAfterPromo - pointDiscount;

    // 6. VAT Calculation
    Decimal vat = Decimal.zero;
    Decimal grandTotal = subtotalAfterPts;
    Decimal netTotal = subtotalAfterPts;

    if (vatType == VatType.excluded) {
      final vatRateDecimal = (toDecimal(vatRate) / toDecimal(100))
          .toDecimal(scaleOnInfinitePrecision: 10);
      vat = subtotalAfterPts * vatRateDecimal;
      grandTotal = subtotalAfterPts + vat;
    }

    // 7. Rounding Logic
    Decimal roundedGrandTotal = grandTotal;
    // Default 'none' if undefined.

    if (roundingMode != null && roundingMode != 'none') {
      double val = grandTotal.toDouble();
      if (roundingMode == 'up') {
        val = val.ceilToDouble();
      } else if (roundingMode == 'down') {
        val = val.floorToDouble();
      } else if (roundingMode == 'auto') {
        val = val.roundToDouble();
      } else if (roundingMode == 'satang_25') {
        val = (val * 4).roundToDouble() / 4.0;
      }
      roundedGrandTotal = toDecimal(val);
    }

    // Recalculate VAT/Net based on Rounded Total if VAT Included
    if (vatType == VatType.included) {
      // VAT In: ยอด = Net + VAT → Net = Total / (1 + rate/100)
      final vatRatio = (toDecimal(vatRate) / toDecimal(100 + vatRate))
          .toDecimal(scaleOnInfinitePrecision: 10);
      vat = roundedGrandTotal * vatRatio;
      netTotal = roundedGrandTotal - vat;
    } else if (vatType == VatType.excluded) {
      netTotal = subtotalAfterPts;
    }

    return PriceCalculationResult(
      totalBeforeDiscount: sumTotal,
      billDiscountAmount: billDiscountAmount + tierDiscountAmount, // existing API keeps tier inside billDiscount
      extraDiscountAmount: extraDiscountAmount,
      subtotalAfterBillDiscount: subtotalAfterBill,
      promoDiscountAmount: promoDiscount,
      subtotalAfterPromo: subtotalAfterPromo,
      pointDiscountAmount: pointDiscount,
      subtotalAfterPoints: subtotalAfterPts,
      vatAmount: vat,
      grandTotal: roundedGrandTotal,
      netTotal: netTotal,
    );
  }
}
