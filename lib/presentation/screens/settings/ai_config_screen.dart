import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gap/gap.dart';
import 'package:material_symbols_icons/symbols.dart';
import '../../../core/services/ai/learning.dart';
import '../../../core/services/storage/storage.dart';
import 'widgets/settings_widgets.dart';

class AIConfigScreen extends ConsumerStatefulWidget {
  const AIConfigScreen({super.key});

  @override
  ConsumerState<AIConfigScreen> createState() => _AIConfigScreenState();
}

class _AIConfigScreenState extends ConsumerState<AIConfigScreen> {
  late TextEditingController _geminiKeyController;
  late TextEditingController _perplexityKeyController;

  bool _obscureGeminiKey = true;
  bool _obscurePerplexityKey = true;

  List<String> _geminiModels = [];
  List<String> _perplexityModels = [];

  String? _selectedGeminiModel;
  String? _selectedPerplexityModel;

  bool _isFetchingGemini = false;
  bool _isFetchingPerplexity = false;

  String? _geminiError;
  String? _perplexityError;

  String _activeProvider = 'gemini';

  @override
  void initState() {
    super.initState();
    final storage = ref.read(storageServiceProvider);

    _activeProvider = storage.selectedAIProvider;
    _geminiKeyController = TextEditingController(
      text: storage.geminiApiKey ?? '',
    );
    _perplexityKeyController = TextEditingController(
      text: storage.perplexityApiKey ?? '',
    );

    _selectedGeminiModel = storage.geminiModel;
    _selectedPerplexityModel = storage.perplexityModel;

    // Initial fetch if keys exist
    if (_geminiKeyController.text.isNotEmpty) _fetchModels('gemini');
    if (_perplexityKeyController.text.isNotEmpty) _fetchModels('perplexity');
  }

  @override
  void dispose() {
    _geminiKeyController.dispose();
    _perplexityKeyController.dispose();
    super.dispose();
  }

  Future<void> _fetchModels(String provider) async {
    setState(() {
      if (provider == 'gemini') {
        _isFetchingGemini = true;
        _geminiError = null;
      } else {
        _isFetchingPerplexity = true;
        _perplexityError = null;
      }
    });

    try {
      final models = await ref
          .read(aiLearningServiceProvider)
          .fetchAvailableModels(provider: provider);

      setState(() {
        if (provider == 'gemini') {
          _geminiModels = models;
          if (_selectedGeminiModel == null ||
              !models.contains(_selectedGeminiModel)) {
            _selectedGeminiModel = models.isNotEmpty ? models.first : null;
          }
        } else {
          _perplexityModels = models;
          if (_selectedPerplexityModel == null ||
              !models.contains(_selectedPerplexityModel)) {
            _selectedPerplexityModel = models.isNotEmpty ? models.first : null;
          }
        }
      });

      // Save initial selection if it changed
      _saveSettings();
    } catch (e) {
      setState(() {
        if (provider == 'gemini')
          _geminiError = e.toString();
        else
          _perplexityError = e.toString();
      });
    } finally {
      setState(() {
        if (provider == 'gemini')
          _isFetchingGemini = false;
        else
          _isFetchingPerplexity = false;
      });
    }
  }

  Future<void> _saveSettings() async {
    final storage = ref.read(storageServiceProvider);
    await storage.setSelectedAIProvider(_activeProvider);
    await storage.setGeminiApiKey(_geminiKeyController.text.trim());
    await storage.setPerplexityApiKey(_perplexityKeyController.text.trim());

    if (_selectedGeminiModel != null) {
      await storage.setGeminiModel(_selectedGeminiModel!);
    }
    if (_selectedPerplexityModel != null) {
      await storage.setPerplexityModel(_selectedPerplexityModel!);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('AI Configuration'), centerTitle: true),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Connection Status Card
          _buildStatusCard(),
          const Gap(24),

          // Gemini Section
          _buildProviderSection(
            title: 'GOOGLE GEMINI',
            provider: 'gemini',
            controller: _geminiKeyController,
            obscureKey: _obscureGeminiKey,
            onToggleObscure: () =>
                setState(() => _obscureGeminiKey = !_obscureGeminiKey),
            models: _geminiModels,
            selectedModel: _selectedGeminiModel,
            isFetching: _isFetchingGemini,
            error: _geminiError,
            onModelChanged: (val) {
              setState(() => _selectedGeminiModel = val);
              _saveSettings();
            },
            onKeySubmitted: () {
              _saveSettings();
              _fetchModels('gemini');
            },
          ),

          const Gap(24),

          // Perplexity Section
          _buildProviderSection(
            title: 'PERPLEXITY AI',
            provider: 'perplexity',
            controller: _perplexityKeyController,
            obscureKey: _obscurePerplexityKey,
            onToggleObscure: () =>
                setState(() => _obscurePerplexityKey = !_obscurePerplexityKey),
            models: _perplexityModels,
            selectedModel: _selectedPerplexityModel,
            isFetching: _isFetchingPerplexity,
            error: _perplexityError,
            onModelChanged: (val) {
              setState(() => _selectedPerplexityModel = val);
              _saveSettings();
            },
            onKeySubmitted: () {
              _saveSettings();
              _fetchModels('perplexity');
            },
          ),
        ],
      ),
    );
  }

  Widget _buildProviderSection({
    required String title,
    required String provider,
    required TextEditingController controller,
    required bool obscureKey,
    required VoidCallback onToggleObscure,
    required List<String> models,
    required String? selectedModel,
    required bool isFetching,
    required String? error,
    required Function(String?) onModelChanged,
    required VoidCallback onKeySubmitted,
  }) {
    final isActive = _activeProvider == provider;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            SectionHeader(title: title),
            if (isActive)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.primary.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  'ACTIVE',
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: Theme.of(context).colorScheme.primary,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              )
            else
              TextButton(
                onPressed: () {
                  setState(() => _activeProvider = provider);
                  _saveSettings();
                },
                child: const Text('Set as Active'),
              ),
          ],
        ),
        const Gap(8),
        SettingsCard(
          children: [
            // API Key field
            TextField(
              controller: controller,
              obscureText: obscureKey,
              decoration: InputDecoration(
                labelText: 'API Key',
                hintText: 'Enter your API key',
                suffixIcon: IconButton(
                  icon: Icon(
                    obscureKey ? Symbols.visibility : Symbols.visibility_off,
                    color: Theme.of(context).colorScheme.primary,
                    size: 18.0,
                  ),
                  onPressed: onToggleObscure,
                ),
              ),
              onChanged: (_) => _saveSettings(),
              onSubmitted: (_) => onKeySubmitted(),
            ),

            if (error != null) ...[
              const Gap(8),
              Text(
                error,
                style: const TextStyle(color: Colors.red, fontSize: 12),
              ),
            ],

            // Model Selection
            const Gap(16),
            Row(
              children: [
                Expanded(
                  child: isFetching
                      ? const Center(child: LinearProgressIndicator())
                      : DropdownButtonFormField<String>(
                          value: selectedModel,
                          decoration: const InputDecoration(
                            labelText: 'Selected Model',
                            contentPadding: EdgeInsets.symmetric(
                              horizontal: 12,
                            ),
                          ),
                          items: models
                              .map(
                                (m) =>
                                    DropdownMenuItem(value: m, child: Text(m)),
                              )
                              .toList(),
                          onChanged: onModelChanged,
                        ),
                ),
                const Gap(8),
                IconButton(
                  onPressed: onKeySubmitted,
                  icon: const Icon(Symbols.refresh, size: 20),
                  tooltip: 'Refresh Models',
                ),
              ],
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildStatusCard() {
    final storage = ref.read(storageServiceProvider);
    final isGeminiOk =
        storage.geminiApiKey?.isNotEmpty == true && _geminiError == null;
    final isPerplexityOk =
        storage.perplexityApiKey?.isNotEmpty == true &&
        _perplexityError == null;

    final isCurrentProviderOk = _activeProvider == 'gemini'
        ? isGeminiOk
        : isPerplexityOk;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isCurrentProviderOk
            ? Theme.of(context).colorScheme.primaryContainer.withOpacity(0.1)
            : Theme.of(context).colorScheme.tertiaryContainer.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isCurrentProviderOk
              ? Theme.of(context).colorScheme.primary.withOpacity(0.3)
              : Theme.of(context).colorScheme.tertiary.withOpacity(0.3),
        ),
      ),
      child: Row(
        children: [
          Icon(
            isCurrentProviderOk ? Symbols.check_circle : Symbols.warning,
            color: isCurrentProviderOk
                ? Theme.of(context).colorScheme.primary
                : Theme.of(context).colorScheme.tertiary,
            size: 20.0,
          ),
          const Gap(12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isCurrentProviderOk
                      ? 'AI Service Ready'
                      : 'AI Service Not Ready',
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
                Text(
                  'Active: ${_activeProvider.toUpperCase()}',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
