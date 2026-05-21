import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../models/point_reward.dart';
import '../../../repositories/reward_repository.dart';

class RewardManagementState {
  final List<PointReward> rewards;
  final List<RedemptionRecord> redemptions;
  final bool isLoading;

  RewardManagementState({
    this.rewards = const [],
    this.redemptions = const [],
    this.isLoading = true,
  });

  RewardManagementState copyWith({
    List<PointReward>? rewards,
    List<RedemptionRecord>? redemptions,
    bool? isLoading,
  }) {
    return RewardManagementState(
      rewards: rewards ?? this.rewards,
      redemptions: redemptions ?? this.redemptions,
      isLoading: isLoading ?? this.isLoading,
    );
  }

  int get pendingCount => redemptions.where((r) => r.isPending && !r.isCoupon).length;
}

class RewardManagementController extends Notifier<RewardManagementState> {
  final RewardRepository _repository = RewardRepository();

  @override
  RewardManagementState build() {
    // Initial state load
    Future.microtask(() => loadAll());
    return RewardManagementState();
  }

  Future<void> loadAll() async {
    state = state.copyWith(isLoading: true);
    final rewards = await _repository.getAllRewards();
    final redemptions = await _repository.getRedemptionList();
    state = state.copyWith(
      rewards: rewards,
      redemptions: redemptions,
      isLoading: false,
    );
  }

  Future<void> loadRewards() async {
    state = state.copyWith(isLoading: true);
    final data = await _repository.getAllRewards();
    state = state.copyWith(
      rewards: data,
      isLoading: false,
    );
  }

  Future<void> loadRedemptions() async {
    final data = await _repository.getRedemptionList();
    state = state.copyWith(
      redemptions: data,
    );
  }

  Future<bool> deleteReward(int rewardId) async {
    final success = await _repository.deleteReward(rewardId);
    if (success) {
      await loadRewards();
    }
    return success;
  }

  Future<bool> fulfillRedemption(int redemptionId) async {
    final success = await _repository.fulfillRedemption(redemptionId);
    if (success) {
      await loadRedemptions();
    }
    return success;
  }

  Future<bool> saveReward(PointReward reward) async {
    final success = await _repository.saveReward(reward);
    if (success) {
      await loadRewards();
    }
    return success;
  }
}

final rewardManagementProvider = NotifierProvider<RewardManagementController, RewardManagementState>(
  () => RewardManagementController(),
);
