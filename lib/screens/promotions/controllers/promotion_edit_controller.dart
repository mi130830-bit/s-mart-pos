import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../models/promotion.dart';
import '../../../repositories/promotion_repository.dart';

class PromotionEditState {
  final bool memberOnly;
  final String conditionType;
  final List<int> conditionProductIds;
  final String rewardType;
  final List<int> rewardProductIds;
  final DateTime? startDate;
  final DateTime? endDate;
  final TimeOfDay? startTime;
  final TimeOfDay? endTime;
  final List<int> daysOfWeek;
  final bool isSaving;

  PromotionEditState({
    this.memberOnly = false,
    this.conditionType = 'min_spend',
    this.conditionProductIds = const [],
    this.rewardType = 'discount_percent',
    this.rewardProductIds = const [],
    this.startDate,
    this.endDate,
    this.startTime,
    this.endTime,
    this.daysOfWeek = const [],
    this.isSaving = false,
  });

  PromotionEditState copyWith({
    bool? memberOnly,
    String? conditionType,
    List<int>? conditionProductIds,
    String? rewardType,
    List<int>? rewardProductIds,
    DateTime? startDate,
    DateTime? endDate,
    TimeOfDay? startTime,
    TimeOfDay? endTime,
    List<int>? daysOfWeek,
    bool? isSaving,
  }) {
    return PromotionEditState(
      memberOnly: memberOnly ?? this.memberOnly,
      conditionType: conditionType ?? this.conditionType,
      conditionProductIds: conditionProductIds ?? this.conditionProductIds,
      rewardType: rewardType ?? this.rewardType,
      rewardProductIds: rewardProductIds ?? this.rewardProductIds,
      startDate: startDate ?? this.startDate,
      endDate: endDate ?? this.endDate,
      startTime: startTime ?? this.startTime,
      endTime: endTime ?? this.endTime,
      daysOfWeek: daysOfWeek ?? this.daysOfWeek,
      isSaving: isSaving ?? this.isSaving,
    );
  }
}

class PromotionEditController extends AutoDisposeNotifier<PromotionEditState> {
  final PromotionRepository _repo = PromotionRepository();
  final formKey = GlobalKey<FormState>();

  late final TextEditingController nameCtrl;
  late final TextEditingController priorityCtrl;
  late final TextEditingController minSpendCtrl;
  late final TextEditingController buyQtyCtrl;
  late final TextEditingController rewardValCtrl;

  Promotion? _initialPromotion;

  @override
  PromotionEditState build() {
    return PromotionEditState();
  }

  void initialize(Promotion? promotion) {
    _initialPromotion = promotion;
    
    nameCtrl = TextEditingController(text: promotion?.name ?? '');
    priorityCtrl = TextEditingController(text: promotion?.priority.toString() ?? '0');
    minSpendCtrl = TextEditingController(text: '0');
    buyQtyCtrl = TextEditingController(text: '1');
    rewardValCtrl = TextEditingController(text: '0');

    String cType = 'min_spend';
    List<int> cIds = [];
    String rType = 'discount_percent';
    List<int> rIds = [];

    if (promotion != null) {
      if (promotion.conditions.containsKey('min_spend')) {
        cType = 'min_spend';
        minSpendCtrl.text = promotion.conditions['min_spend'].toString();
      } else if (promotion.conditions.containsKey('buy_items')) {
        cType = 'buy_items';
        final list = promotion.conditions['buy_items'] as List;
        if (list.isNotEmpty) {
          cIds = [int.parse(list[0]['product_id'].toString())];
          buyQtyCtrl.text = list[0]['qty'].toString();
        }
      } else if (promotion.conditions.containsKey('target_products')) {
        cType = 'target_products';
        cIds = (promotion.conditions['target_products'] as List).map((e) => int.parse(e.toString())).toList();
      }

      if (promotion.rewards.containsKey('discount_amount')) {
        rType = 'discount_amount';
        rewardValCtrl.text = promotion.rewards['discount_amount'].toString();
      } else if (promotion.rewards.containsKey('discount_percent')) {
        rType = 'discount_percent';
        rewardValCtrl.text = promotion.rewards['discount_percent'].toString();
      } else if (promotion.rewards.containsKey('get_items')) {
        rType = 'get_items';
        final list = promotion.rewards['get_items'] as List;
        if (list.isNotEmpty) {
          rIds = [int.parse(list[0]['product_id'].toString())];
          rewardValCtrl.text = list[0]['qty'].toString();
        }
      }
    }

    TimeOfDay? sTime;
    TimeOfDay? eTime;
    if (promotion?.startTime != null) {
      final parts = promotion!.startTime!.split(':');
      if (parts.length == 2) sTime = TimeOfDay(hour: int.parse(parts[0]), minute: int.parse(parts[1]));
    }
    if (promotion?.endTime != null) {
      final parts = promotion!.endTime!.split(':');
      if (parts.length == 2) eTime = TimeOfDay(hour: int.parse(parts[0]), minute: int.parse(parts[1]));
    }

    Future.microtask(() {
      state = state.copyWith(
        memberOnly: promotion?.memberOnly ?? false,
        conditionType: cType,
        conditionProductIds: cIds,
        rewardType: rType,
        rewardProductIds: rIds,
        startDate: promotion?.startDate,
        endDate: promotion?.endDate,
        startTime: sTime,
        endTime: eTime,
        daysOfWeek: List<int>.from(promotion?.daysOfWeek ?? []),
      );
    });
  }

  void disposeControllers() {
    nameCtrl.dispose();
    priorityCtrl.dispose();
    minSpendCtrl.dispose();
    buyQtyCtrl.dispose();
    rewardValCtrl.dispose();
  }

  void setMemberOnly(bool value) => state = state.copyWith(memberOnly: value);
  void setConditionType(String value) => state = state.copyWith(conditionType: value);
  void setRewardType(String value) => state = state.copyWith(rewardType: value);
  void setStartDate(DateTime? date) => state = state.copyWith(startDate: date);
  void setEndDate(DateTime? date) => state = state.copyWith(endDate: date);
  void setStartTime(TimeOfDay? time) => state = state.copyWith(startTime: time);
  void setEndTime(TimeOfDay? time) => state = state.copyWith(endTime: time);
  
  void setConditionProductIds(List<int> ids) => state = state.copyWith(conditionProductIds: ids);
  void setRewardProductIds(List<int> ids) => state = state.copyWith(rewardProductIds: ids);

  void toggleDayOfWeek(int dayVal, bool isSelected) {
    final newList = List<int>.from(state.daysOfWeek);
    if (isSelected) {
      newList.add(dayVal);
    } else {
      newList.remove(dayVal);
    }
    state = state.copyWith(daysOfWeek: newList);
  }

  Future<bool> save() async {
    if (!formKey.currentState!.validate()) return false;
    
    state = state.copyWith(isSaving: true);

    Map<String, dynamic> conditions = {};
    if (state.conditionType == 'min_spend') {
      conditions['min_spend'] = double.parse(minSpendCtrl.text);
    } else if (state.conditionType == 'buy_items') {
      conditions['buy_items'] = [
        {'product_id': state.conditionProductIds.isNotEmpty ? state.conditionProductIds.first : 0, 'qty': double.parse(buyQtyCtrl.text)}
      ];
    } else if (state.conditionType == 'target_products') {
      conditions['target_products'] = state.conditionProductIds;
    }

    Map<String, dynamic> rewards = {};
    if (state.rewardType == 'discount_amount') {
      rewards['type'] = 'discount_amount';
      rewards['discount_amount'] = double.parse(rewardValCtrl.text);
    } else if (state.rewardType == 'discount_percent') {
      rewards['type'] = 'discount_percent';
      rewards['discount_percent'] = double.parse(rewardValCtrl.text);
    } else if (state.rewardType == 'get_items') {
      rewards['type'] = 'get_items';
      rewards['get_items'] = [
        {'product_id': state.rewardProductIds.isNotEmpty ? state.rewardProductIds.first : 0, 'qty': double.parse(rewardValCtrl.text)}
      ];
    }

    String? startT;
    String? endT;
    if (state.startTime != null) {
      startT = "\${state.startTime!.hour.toString().padLeft(2, '0')}:\${state.startTime!.minute.toString().padLeft(2, '0')}";
    }
    if (state.endTime != null) {
      endT = "\${state.endTime!.hour.toString().padLeft(2, '0')}:\${state.endTime!.minute.toString().padLeft(2, '0')}";
    }

    final newP = Promotion(
      id: _initialPromotion?.id ?? 0,
      name: nameCtrl.text,
      type: state.conditionType == 'target_products' ? 'per_product' : 'simple',
      priority: int.tryParse(priorityCtrl.text) ?? 0,
      memberOnly: state.memberOnly,
      isActive: _initialPromotion?.isActive ?? true,
      conditions: conditions,
      rewards: rewards,
      startDate: state.startDate,
      endDate: state.endDate,
      startTime: startT,
      endTime: endT,
      daysOfWeek: state.daysOfWeek,
    );

    await _repo.savePromotion(newP);
    state = state.copyWith(isSaving: false);
    return true;
  }
}

final promotionEditProvider = NotifierProvider.autoDispose<PromotionEditController, PromotionEditState>(
  () => PromotionEditController(),
);
