import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:file_picker/file_picker.dart';
import '../../../models/point_reward.dart';

class RewardFormState {
  final bool isActive;
  final String? imageUrl;
  final bool isUploading;
  final File? pickedImageFile;
  final String rewardType;

  RewardFormState({
    this.isActive = true,
    this.imageUrl,
    this.isUploading = false,
    this.pickedImageFile,
    this.rewardType = 'GIFT',
  });

  RewardFormState copyWith({
    bool? isActive,
    String? imageUrl,
    bool? isUploading,
    File? pickedImageFile,
    String? rewardType,
  }) {
    return RewardFormState(
      isActive: isActive ?? this.isActive,
      imageUrl: imageUrl ?? this.imageUrl,
      isUploading: isUploading ?? this.isUploading,
      pickedImageFile: pickedImageFile ?? this.pickedImageFile,
      rewardType: rewardType ?? this.rewardType,
    );
  }
}

class RewardFormController extends AutoDisposeNotifier<RewardFormState> {
  late final TextEditingController nameCtrl;
  late final TextEditingController descCtrl;
  late final TextEditingController pointsCtrl;
  late final TextEditingController stockCtrl;
  late final TextEditingController discountCtrl;
  late final TextEditingController expiryCtrl;

  late final FocusNode nameFocus;
  late final FocusNode descFocus;
  late final FocusNode pointsFocus;
  late final FocusNode stockFocus;
  late final FocusNode discountFocus;
  late final FocusNode expiryFocus;

  final formKey = GlobalKey<FormState>();

  PointReward? _initialReward;

  @override
  RewardFormState build() {
    return RewardFormState();
  }

  void initialize(PointReward? initialReward) {
    _initialReward = initialReward;
    nameCtrl = TextEditingController(text: initialReward?.name ?? '');
    descCtrl = TextEditingController(text: initialReward?.description ?? '');
    pointsCtrl = TextEditingController(text: (initialReward?.pointPrice ?? 0).toString());
    stockCtrl = TextEditingController(text: (initialReward?.stockQuantity ?? 1).toString());
    discountCtrl = TextEditingController(text: (initialReward?.discountValue ?? 50).toString());
    expiryCtrl = TextEditingController(text: (initialReward?.couponExpiryDays ?? 30).toString());
    
    nameFocus = FocusNode();
    descFocus = FocusNode();
    pointsFocus = FocusNode();
    stockFocus = FocusNode();
    discountFocus = FocusNode();
    expiryFocus = FocusNode();

    Future.microtask(() {
      state = state.copyWith(
        isActive: initialReward?.isActive ?? true,
        imageUrl: initialReward?.imageUrl,
        rewardType: initialReward?.rewardType ?? 'GIFT',
        pickedImageFile: null,
      );
    });
  }

  void disposeControllers() {
    nameCtrl.dispose();
    descCtrl.dispose();
    pointsCtrl.dispose();
    stockCtrl.dispose();
    discountCtrl.dispose();
    expiryCtrl.dispose();
    
    nameFocus.dispose();
    descFocus.dispose();
    pointsFocus.dispose();
    stockFocus.dispose();
    discountFocus.dispose();
    expiryFocus.dispose();
  }

  void requestFocus() {
    nameFocus.requestFocus();
  }

  void setRewardType(String type) {
    state = state.copyWith(rewardType: type);
  }

  void setIsActive(bool active) {
    state = state.copyWith(isActive: active);
  }

  Future<void> pickImage(BuildContext context) async {
    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(type: FileType.image, allowMultiple: false);
      if (result != null && result.files.single.path != null) {
        state = state.copyWith(pickedImageFile: File(result.files.single.path!));
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('ไม่สามารถเลือกรูปภาพได้: $e')));
      }
    }
  }

  Future<String?> _uploadImage(File file) async {
    try {
      final String baseDir = Directory.current.path;
      final String targetDirPath = '$baseDir\\backend\\public\\rewards';
      final dir = Directory(targetDirPath);
      if (!await dir.exists()) await dir.create(recursive: true);
      final ext = file.path.contains('.') ? '.${file.path.split('.').last}' : '.png';
      final uniqueName = 'reward_${DateTime.now().millisecondsSinceEpoch}$ext';
      await file.copy('$targetDirPath\\$uniqueName');
      return '/rewards/$uniqueName';
    } catch (e) {
      debugPrint('Upload error: $e');
      return null;
    }
  }

  Future<PointReward?> submit() async {
    if (formKey.currentState!.validate()) {
      state = state.copyWith(isUploading: true);
      String? finalImageUrl = state.imageUrl;
      if (state.pickedImageFile != null) {
        finalImageUrl = await _uploadImage(state.pickedImageFile!);
      }
      state = state.copyWith(isUploading: false);
      final reward = PointReward(
        id: _initialReward?.id ?? 0,
        name: nameCtrl.text.trim(),
        description: descCtrl.text.trim(),
        pointPrice: int.tryParse(pointsCtrl.text) ?? 0,
        stockQuantity: int.tryParse(stockCtrl.text) ?? 0,
        imageUrl: finalImageUrl,
        isActive: state.isActive,
        rewardType: state.rewardType,
        discountValue: double.tryParse(discountCtrl.text) ?? 0,
        couponExpiryDays: int.tryParse(expiryCtrl.text) ?? 30,
      );
      return reward;
    }
    return null;
  }
}

final rewardFormProvider = NotifierProvider.autoDispose<RewardFormController, RewardFormState>(
  () => RewardFormController(),
);
