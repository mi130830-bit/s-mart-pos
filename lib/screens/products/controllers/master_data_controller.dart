import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../models/product_type.dart';
import '../../../models/shelf.dart';
import '../../../models/unit.dart';
import '../../../repositories/product_type_repository.dart';
import '../../../repositories/shelf_repository.dart';
import '../../../repositories/unit_repository.dart';
import '../../../services/logger_service.dart';

final unitRepositoryProvider = Provider((ref) => UnitRepository());
final productTypeRepositoryProvider = Provider((ref) => ProductTypeRepository());
final shelfRepositoryProvider = Provider((ref) => ShelfRepository());

class MasterDataState {
  final List<Unit> units;
  final List<ProductType> productTypes;
  final List<Shelf> shelves;
  final bool isLoading;

  MasterDataState({
    this.units = const [],
    this.productTypes = const [],
    this.shelves = const [],
    this.isLoading = false,
  });

  MasterDataState copyWith({
    List<Unit>? units,
    List<ProductType>? productTypes,
    List<Shelf>? shelves,
    bool? isLoading,
  }) {
    return MasterDataState(
      units: units ?? this.units,
      productTypes: productTypes ?? this.productTypes,
      shelves: shelves ?? this.shelves,
      isLoading: isLoading ?? this.isLoading,
    );
  }
}

final masterDataProvider = AutoDisposeNotifierProvider<MasterDataController, MasterDataState>(
  () => MasterDataController(),
);

class MasterDataController extends AutoDisposeNotifier<MasterDataState> {
  late final UnitRepository _unitRepo;
  late final ProductTypeRepository _typeRepo;
  late final ShelfRepository _shelfRepo;
  bool _mounted = true;

  @override
  MasterDataState build() {
    _unitRepo = ref.read(unitRepositoryProvider);
    _typeRepo = ref.read(productTypeRepositoryProvider);
    _shelfRepo = ref.read(shelfRepositoryProvider);
    
    _mounted = true;
    ref.onDispose(() => _mounted = false);
    
    return MasterDataState();
  }

  Future<void> loadData() async {
    if (!_mounted) return;
    state = state.copyWith(isLoading: true);

    try {
      final results = await Future.wait([
        _unitRepo.getAllUnits(),
        _typeRepo.getAllProductTypes(),
        _shelfRepo.getAllShelves(),
      ]);
      
      if (_mounted) {
        state = state.copyWith(
          units: results[0] as List<Unit>,
          productTypes: results[1] as List<ProductType>,
          shelves: results[2] as List<Shelf>,
          isLoading: false,
        );
      }
    } catch (e, stackTrace) {
      LoggerService.error('MasterData', 'Failed to load master data', e, stackTrace);
      if (_mounted) {
        state = state.copyWith(isLoading: false);
      }
    }
  }

  Future<void> _loadUnits() async {
    final units = await _unitRepo.getAllUnits();
    if (_mounted) state = state.copyWith(units: units);
  }

  Future<void> _loadProductTypes() async {
    final types = await _typeRepo.getAllProductTypes();
    if (_mounted) state = state.copyWith(productTypes: types);
  }

  Future<void> _loadShelves() async {
    final shelves = await _shelfRepo.getAllShelves();
    if (_mounted) state = state.copyWith(shelves: shelves);
  }

  // --- Units ---
  Future<bool> saveUnit(int id, String name) async {
    try {
      bool success = false;
      if (id > 0) {
        success = await _unitRepo.updateUnit(id, name);
      } else {
        final newId = await _unitRepo.saveUnit(name);
        success = newId > 0;
      }
      if (success) {
        await _loadUnits();
      }
      return success;
    } catch (e, stackTrace) {
      LoggerService.error('MasterData', 'Failed to save unit', e, stackTrace);
      return false;
    }
  }

  Future<bool> deleteUnit(int id) async {
    try {
      final success = await _unitRepo.deleteUnit(id);
      if (success) {
        await _loadUnits();
      }
      return success;
    } catch (e, stackTrace) {
      LoggerService.error('MasterData', 'Failed to delete unit', e, stackTrace);
      return false;
    }
  }

  // --- Product Types ---
  Future<bool> saveProductType(ProductType type) async {
    try {
      final newId = await _typeRepo.saveProductType(type);
      if (newId != 0) {
        await _loadProductTypes();
        return true;
      }
      return false;
    } catch (e, stackTrace) {
      LoggerService.error('MasterData', 'Failed to save product type', e, stackTrace);
      return false;
    }
  }

  Future<bool> deleteProductType(int id) async {
    try {
      final success = await _typeRepo.deleteProductType(id);
      if (success) {
        await _loadProductTypes();
      }
      return success;
    } catch (e, stackTrace) {
      LoggerService.error('MasterData', 'Failed to delete product type', e, stackTrace);
      return false;
    }
  }

  // --- Shelves ---
  Future<bool> saveShelf(int id, String name) async {
    try {
      bool success = false;
      if (id > 0) {
        success = await _shelfRepo.updateShelf(id, name);
      } else {
        final newId = await _shelfRepo.saveShelf(name);
        success = newId > 0;
      }
      if (success) {
        await _loadShelves();
      }
      return success;
    } catch (e, stackTrace) {
      LoggerService.error('MasterData', 'Failed to save shelf', e, stackTrace);
      return false;
    }
  }

  Future<bool> deleteShelf(int id) async {
    try {
      final success = await _shelfRepo.deleteShelf(id);
      if (success) {
        await _loadShelves();
      }
      return success;
    } catch (e, stackTrace) {
      LoggerService.error('MasterData', 'Failed to delete shelf', e, stackTrace);
      return false;
    }
  }
}
