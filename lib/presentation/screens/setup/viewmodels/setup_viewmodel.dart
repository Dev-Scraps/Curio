import 'package:riverpod_annotation/riverpod_annotation.dart';
import '../../../../core/services/system/permissions.dart';
import '../../../../core/services/storage/storage.dart';
import '../../../../core/services/content/sync.dart';

part 'setup_viewmodel.g.dart';

class SetupState {
  final String language;
  final String performanceMode;
  final int libraryTabs;
  final bool useMediaStore;
  final bool storagePermissionGranted;
  final bool notificationPermissionGranted;
  final bool isAccountConnected;

  SetupState({
    required this.language,
    required this.performanceMode,
    required this.libraryTabs,
    required this.useMediaStore,
    this.storagePermissionGranted = false,
    this.notificationPermissionGranted = false,
    this.isAccountConnected = false,
  });

  SetupState copyWith({
    String? language,
    String? performanceMode,
    int? libraryTabs,
    bool? useMediaStore,
    bool? storagePermissionGranted,
    bool? notificationPermissionGranted,
    bool? isAccountConnected,
  }) {
    return SetupState(
      language: language ?? this.language,
      performanceMode: performanceMode ?? this.performanceMode,
      libraryTabs: libraryTabs ?? this.libraryTabs,
      useMediaStore: useMediaStore ?? this.useMediaStore,
      storagePermissionGranted:
          storagePermissionGranted ?? this.storagePermissionGranted,
      notificationPermissionGranted:
          notificationPermissionGranted ?? this.notificationPermissionGranted,
      isAccountConnected: isAccountConnected ?? this.isAccountConnected,
    );
  }

  bool get canContinue => storagePermissionGranted && isAccountConnected;
}

@riverpod
class SetupViewModel extends _$SetupViewModel {
  @override
  SetupState build() {
    final storage = ref.read(storageServiceProvider);
    final syncState = ref.watch(syncServiceProvider);

    // Initial check
    Future.microtask(() => _checkPermissionsAsync());

    return SetupState(
      language: storage.language,
      performanceMode: storage.performanceMode,
      libraryTabs: storage.libraryTabs,
      useMediaStore: storage.useMediaStore,
      isAccountConnected: syncState.activeAccount != null,
    );
  }

  Future<void> _checkPermissionsAsync() async {
    if (!ref.mounted) return;

    final permissionService = ref.read(permissionServiceProvider);
    final hasStorage = await permissionService.hasStoragePermission();
    final hasNotification = await permissionService.hasNotificationPermission();

    if (!ref.mounted) return;

    state = state.copyWith(
      storagePermissionGranted: hasStorage,
      notificationPermissionGranted: hasNotification,
    );
  }

  void setLanguage(String value) {
    state = state.copyWith(language: value);
    ref.read(storageServiceProvider).setLanguage(value);
  }

  void setPerformanceMode(String value) {
    state = state.copyWith(performanceMode: value);
    ref.read(storageServiceProvider).setPerformanceMode(value);
  }

  void setLibraryTabs(int value) {
    state = state.copyWith(libraryTabs: value);
    ref.read(storageServiceProvider).setLibraryTabs(value);
  }

  void setUseMediaStore(bool value) {
    state = state.copyWith(useMediaStore: value);
    ref.read(storageServiceProvider).setUseMediaStore(value);
  }

  Future<bool> requestStoragePermission() async {
    final granted = await ref
        .read(permissionServiceProvider)
        .requestStoragePermission();
    state = state.copyWith(storagePermissionGranted: granted);
    return granted;
  }

  Future<bool> requestNotificationPermission() async {
    final granted = await ref
        .read(permissionServiceProvider)
        .requestNotificationPermission();
    state = state.copyWith(notificationPermissionGranted: granted);
    return granted;
  }

  Future<void> importCookies() async {
    // Mock file path for now
    final filePath = '/path/to/cookies.txt';
    await ref.read(syncServiceProvider.notifier).importCookies(filePath);
  }

  Future<void> completeSetup() async {
    await ref.read(storageServiceProvider).setSetupCompleted(true);
  }

  void setAccountConnected(bool isConnected) {
    state = state.copyWith(isAccountConnected: isConnected);
  }
}
