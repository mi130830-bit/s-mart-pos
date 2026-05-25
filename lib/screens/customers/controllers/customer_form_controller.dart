import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../models/customer.dart';
import '../../../../models/member_tier.dart';
import '../../../../repositories/customer_repository.dart';
import '../../../../services/mysql_service.dart';
import '../../../../services/alert_service.dart';

class CustomerFormState {
  final DateTime? dateOfBirth;
  final DateTime? expiryDate;
  final int? selectedTierId;
  final String? lineUserId;
  final String? lineDisplayName;
  final String? linePictureUrl;
  final List<MemberTier> tiers;
  final bool isSaving;

  CustomerFormState({
    this.dateOfBirth,
    this.expiryDate,
    this.selectedTierId,
    this.lineUserId,
    this.lineDisplayName,
    this.linePictureUrl,
    this.tiers = const [],
    this.isSaving = false,
  });

  CustomerFormState copyWith({
    DateTime? dateOfBirth,
    DateTime? expiryDate,
    int? selectedTierId,
    String? lineUserId,
    String? lineDisplayName,
    String? linePictureUrl,
    List<MemberTier>? tiers,
    bool? isSaving,
    bool clearLine = false,
  }) {
    return CustomerFormState(
      dateOfBirth: dateOfBirth ?? this.dateOfBirth,
      expiryDate: expiryDate ?? this.expiryDate,
      selectedTierId: selectedTierId ?? this.selectedTierId,
      lineUserId: clearLine ? null : (lineUserId ?? this.lineUserId),
      lineDisplayName: clearLine ? null : (lineDisplayName ?? this.lineDisplayName),
      linePictureUrl: clearLine ? null : (linePictureUrl ?? this.linePictureUrl),
      tiers: tiers ?? this.tiers,
      isSaving: isSaving ?? this.isSaving,
    );
  }
}

final customerFormProvider = AutoDisposeNotifierProviderFamily<CustomerFormController, CustomerFormState, Customer?>(
  () => CustomerFormController(),
);

class CustomerFormController extends AutoDisposeFamilyNotifier<CustomerFormState, Customer?> {
  final CustomerRepository repo = CustomerRepository();
  Customer? initialCustomer;

  final GlobalKey<FormState> formKey = GlobalKey<FormState>();

  late TextEditingController memberCodeCtrl;
  late TextEditingController firstNameCtrl;
  late TextEditingController lastNameCtrl;
  late TextEditingController phoneCtrl;
  late TextEditingController addressCtrl;
  late TextEditingController shippingAddressCtrl;
  late TextEditingController nationalIdCtrl;
  late TextEditingController taxIdCtrl;
  late TextEditingController remarksCtrl;
  late TextEditingController distanceKmCtrl;

  bool _mounted = true;

  @override
  CustomerFormState build(Customer? arg) {
    initialCustomer = arg;
    _mounted = true;
    final c = initialCustomer;

    memberCodeCtrl = TextEditingController(text: c?.memberCode ?? '');
    firstNameCtrl = TextEditingController(text: c?.firstName ?? '');
    lastNameCtrl = TextEditingController(text: c?.lastName ?? '');
    phoneCtrl = TextEditingController(text: c?.phone ?? '');
    addressCtrl = TextEditingController(text: c?.address ?? '');
    shippingAddressCtrl = TextEditingController(text: c?.shippingAddress ?? '');
    nationalIdCtrl = TextEditingController(text: c?.nationalId ?? '');
    taxIdCtrl = TextEditingController(text: c?.taxId ?? '');
    remarksCtrl = TextEditingController(text: c?.remarks ?? '');
    distanceKmCtrl = TextEditingController(text: c?.distanceKm.toString() ?? '0.0');

    ref.onDispose(() {
      _mounted = false;
      memberCodeCtrl.dispose();
      firstNameCtrl.dispose();
      lastNameCtrl.dispose();
      phoneCtrl.dispose();
      addressCtrl.dispose();
      shippingAddressCtrl.dispose();
      nationalIdCtrl.dispose();
      taxIdCtrl.dispose();
      remarksCtrl.dispose();
      distanceKmCtrl.dispose();
    });

    Future.microtask(() {
      if (_mounted) _loadTiers();
    });

    return CustomerFormState(
      dateOfBirth: c?.dateOfBirth,
      expiryDate: c?.membershipExpiryDate,
      selectedTierId: c?.tierId,
      lineUserId: c?.lineUserId,
      lineDisplayName: c?.lineDisplayName,
      linePictureUrl: c?.linePictureUrl,
    );
  }

  Future<void> _loadTiers() async {
    try {
      final loadedTiers = await repo.getAllTiers();
      if (_mounted) {
        state = state.copyWith(tiers: loadedTiers);
      }
    } catch (e) {
      debugPrint('Error loading tiers: $e');
    }
  }

  void setDateOfBirth(DateTime? date) {
    if (date != null && _mounted) {
      state = state.copyWith(dateOfBirth: date);
    }
  }

  void setExpiryDate(DateTime? date) {
    if (date != null && _mounted) {
      state = state.copyWith(expiryDate: date);
    }
  }

  void setTierId(int? tierId) {
    if (_mounted) {
      state = state.copyWith(selectedTierId: tierId);
    }
  }

  void unlinkLine() {
    if (_mounted) {
      state = state.copyWith(clearLine: true);
    }
  }

  Future<void> fetchDistanceFromHistory(BuildContext context) async {
    final name = firstNameCtrl.text.trim();
    if (name.isEmpty) {
      AlertService.show(
        context: context,
        message: 'กรุณากรอกชื่อลูกค้าก่อนดึงข้อมูลระยะทาง',
        type: 'warning',
      );
      return;
    }

    try {
      final db = MySQLService();
      // ค้นหาประวัติจัดส่งที่เสร็จสิ้นล่าสุดของลูกค้ารายนี้ ที่มีระยะทาง > 0
      final res = await db.query(
        '''
        SELECT distanceKm 
        FROM delivery_history 
        WHERE customerName LIKE :cname 
          AND distanceKm > 0 
        ORDER BY completedAt DESC 
        LIMIT 1
        ''',
        {'cname': '%$name%'},
      );

      if (res.isNotEmpty) {
        final dist = double.tryParse(res.first['distanceKm']?.toString() ?? '0') ?? 0.0;
        if (dist > 0) {
          distanceKmCtrl.text = dist.toStringAsFixed(1);
          if (!context.mounted) return;
          AlertService.show(
            context: context,
            message: 'ดึงระยะทางสำเร็จ: $dist กม.',
            type: 'success',
          );
        } else {
          if (!context.mounted) return;
          AlertService.show(
            context: context,
            message: 'ไม่พบประวัติระยะทางของลูกค้าคนนี้ในรายงานขนส่ง',
            type: 'warning',
          );
        }
      } else {
        if (!context.mounted) return;
        AlertService.show(
          context: context,
          message: 'ไม่พบประวัติระยะทางของลูกค้าคนนี้ในรายงานขนส่ง',
          type: 'warning',
        );
      }
    } catch (e) {
      debugPrint('Error fetching distance from history: $e');
      if (!context.mounted) return;
      AlertService.show(
        context: context,
        message: 'เกิดข้อผิดพลาดในการดึงข้อมูลระยะทาง',
        type: 'error',
      );
    }
  }

  Future<void> save(BuildContext context) async {
    if (state.isSaving) return;
    if (formKey.currentState!.validate()) {
      if (!_mounted) return;
      state = state.copyWith(isSaving: true);

      final newCustomer = Customer(
        id: initialCustomer?.id ?? 0,
        memberCode: memberCodeCtrl.text.isEmpty
            ? 'AUTO-${DateTime.now().millisecondsSinceEpoch.toString().substring(5)}'
            : memberCodeCtrl.text,
        firstName: firstNameCtrl.text,
        lastName: lastNameCtrl.text,
        phone: phoneCtrl.text,
        currentPoints: initialCustomer?.currentPoints ?? 0,
        address: addressCtrl.text,
        shippingAddress: shippingAddressCtrl.text,
        dateOfBirth: state.dateOfBirth,
        membershipExpiryDate: state.expiryDate,
        firebaseUid: initialCustomer?.firebaseUid,
        title: initialCustomer?.title,
        nationalId: nationalIdCtrl.text,
        email: initialCustomer?.email,
        taxId: taxIdCtrl.text,
        creditLimit: initialCustomer?.creditLimit,
        currentDebt: initialCustomer?.currentDebt ?? 0.0,
        remarks: remarksCtrl.text,
        distanceKm: double.tryParse(distanceKmCtrl.text) ?? 0.0,
        totalSpending: initialCustomer?.totalSpending ?? 0.0,
        tierId: state.selectedTierId,
        lineUserId: state.lineUserId,
        lineDisplayName: state.lineDisplayName,
        linePictureUrl: state.linePictureUrl,
      );

      try {
        final savedId = await repo.saveCustomer(newCustomer);
        
        if (!context.mounted) return;

        if (savedId > 0) {
          final resultCustomer = newCustomer.copyWith(id: savedId);
          Navigator.of(context).pop(resultCustomer);
        } else {
          if (_mounted) state = state.copyWith(isSaving: false);
          AlertService.show(
            context: context,
            message: 'เกิดข้อผิดพลาดในการบันทึก (savedId <= 0)',
            type: 'error',
          );
        }
      } catch (e, stackTrace) {
        debugPrint('Error saving customer: $e\n$stackTrace');
        if (!context.mounted) return;
        
        if (_mounted) state = state.copyWith(isSaving: false);
        AlertService.show(
          context: context,
          message: 'Error: $e\nดูรายละเอียดเพิ่มเติมใน console',
          type: 'error',
        );
      }
    } else {
      AlertService.show(
        context: context,
        message: 'กรุณากรอกข้อมูลที่จำเป็นให้ครบถ้วน',
        type: 'warning',
      );
    }
  }
}
