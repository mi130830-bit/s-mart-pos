import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../models/promotion.dart';
import '../../../repositories/promotion_repository.dart';

class PromotionListState {
  final List<Promotion> promotions;
  final bool isLoading;

  PromotionListState({
    this.promotions = const [],
    this.isLoading = true,
  });

  PromotionListState copyWith({
    List<Promotion>? promotions,
    bool? isLoading,
  }) {
    return PromotionListState(
      promotions: promotions ?? this.promotions,
      isLoading: isLoading ?? this.isLoading,
    );
  }
}

class PromotionListController extends Notifier<PromotionListState> {
  final PromotionRepository _repo = PromotionRepository();

  @override
  PromotionListState build() {
    Future.microtask(() => loadData());
    return PromotionListState();
  }

  Future<void> loadData() async {
    state = state.copyWith(isLoading: true);
    final data = await _repo.getAllPromotions();
    state = state.copyWith(
      promotions: data,
      isLoading: false,
    );
  }

  Future<void> toggleStatus(Promotion promo) async {
    final newPromo = Promotion(
      id: promo.id,
      name: promo.name,
      type: promo.type,
      startDate: promo.startDate,
      endDate: promo.endDate,
      startTime: promo.startTime,
      endTime: promo.endTime,
      daysOfWeek: promo.daysOfWeek,
      memberOnly: promo.memberOnly,
      priority: promo.priority,
      isActive: !promo.isActive,
      conditions: promo.conditions,
      rewards: promo.rewards,
    );
    await _repo.savePromotion(newPromo);
    await loadData();
  }

  Future<void> deletePromotion(int id) async {
    await _repo.deletePromotion(id);
    await loadData();
  }
}

final promotionListProvider = NotifierProvider<PromotionListController, PromotionListState>(
  () => PromotionListController(),
);
