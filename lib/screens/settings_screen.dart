import 'package:flutter/material.dart';
import '../main.dart';
import '../models/models.dart';
import '../services/settings_service.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _apiIdController;
  late TextEditingController _apiHashController;
  late TextEditingController _botUsernameController;
  bool _obscureApiHash = true;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    final s = SettingsService.settings;
    _apiIdController = TextEditingController(text: s.telegramApiId);
    _apiHashController = TextEditingController(text: s.telegramApiHash);
    _botUsernameController = TextEditingController(text: s.botUsername);
  }

  @override
  void dispose() {
    _apiIdController.dispose();
    _apiHashController.dispose();
    _botUsernameController.dispose();
    super.dispose();
  }

  Future<void> _saveSettings() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSaving = true);
    await SettingsService.save(SettingsService.settings.copyWith(
      telegramApiId: _apiIdController.text.trim(),
      telegramApiHash: _apiHashController.text.trim(),
      botUsername: _botUsernameController.text.trim(),
    ));
    setState(() => _isSaving = false);

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Row(
            children: [
              Icon(Icons.check_circle_rounded, color: AppTheme.accentGreen, size: 18),
              SizedBox(width: 8),
              Text('Settings saved successfully'),
            ],
          ),
          behavior: SnackBarBehavior.floating,
          backgroundColor: AppTheme.cardColor,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.bgColor,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildHeader(),
              const SizedBox(height: 24),
              _buildConfigCard(),
              const SizedBox(height: 20),
              _buildHowToCard(),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _isSaving ? null : _saveSettings,
                  child: _isSaving
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            color: Colors.black,
                            strokeWidth: 2,
                          ),
                        )
                      : const Text('Save Settings'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    final isConfigured = SettingsService.settings.isConfigured;
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFFFF6B35), Color(0xFFFF8C42)],
            ),
            borderRadius: BorderRadius.circular(14),
          ),
          child: const Icon(Icons.settings_rounded, color: Colors.black, size: 24),
        ),
        const SizedBox(width: 14),
        const Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Settings',
                  style: TextStyle(
                    color: AppTheme.textPrimary,
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                  )),
              Text('Configure Telegram credentials',
                  style: TextStyle(color: AppTheme.textSecondary, fontSize: 12)),
            ],
          ),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: isConfigured
                ? AppTheme.accentGreen.withValues(alpha: 0.15)
                : Colors.orange.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: isConfigured
                  ? AppTheme.accentGreen.withValues(alpha: 0.4)
                  : Colors.orange.withValues(alpha: 0.4),
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                isConfigured ? Icons.check_circle_rounded : Icons.warning_amber_rounded,
                size: 14,
                color: isConfigured ? AppTheme.accentGreen : Colors.orange,
              ),
              const SizedBox(width: 4),
              Text(
                isConfigured ? 'Ready' : 'Setup',
                style: TextStyle(
                  color: isConfigured ? AppTheme.accentGreen : Colors.orange,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildConfigCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppTheme.cardColor,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppTheme.borderColor),
      ),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Telegram API Credentials',
                style: TextStyle(
                  color: AppTheme.textPrimary,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                )),
            const SizedBox(height: 4),
            const Text('Get these from my.telegram.org/apps',
                style: TextStyle(color: AppTheme.textSecondary, fontSize: 12)),
            const SizedBox(height: 20),
            _buildField(
              controller: _apiIdController,
              label: 'API ID',
              hint: 'e.g. 12345678',
              icon: Icons.key_rounded,
              keyboardType: TextInputType.number,
              validator: (v) =>
                  v?.isEmpty ?? true ? 'API ID is required' : null,
            ),
            const SizedBox(height: 16),
            _buildField(
              controller: _apiHashController,
              label: 'API Hash',
              hint: 'Your API hash string',
              icon: Icons.vpn_key_rounded,
              obscureText: _obscureApiHash,
              suffixIcon: IconButton(
                icon: Icon(
                  _obscureApiHash ? Icons.visibility_off : Icons.visibility,
                  color: AppTheme.textSecondary,
                  size: 18,
                ),
                onPressed: () =>
                    setState(() => _obscureApiHash = !_obscureApiHash),
              ),
              validator: (v) =>
                  v?.isEmpty ?? true ? 'API Hash is required' : null,
            ),
            const SizedBox(height: 16),
            _buildField(
              controller: _botUsernameController,
              label: 'Bot Username',
              hint: '@spotifydownloaderbot',
              icon: Icons.smart_toy_rounded,
              validator: (v) =>
                  v?.isEmpty ?? true ? 'Bot username is required' : null,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildField({
    required TextEditingController controller,
    required String label,
    required String hint,
    required IconData icon,
    bool obscureText = false,
    Widget? suffixIcon,
    TextInputType? keyboardType,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      obscureText: obscureText,
      keyboardType: keyboardType,
      style: const TextStyle(color: AppTheme.textPrimary),
      validator: validator,
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        prefixIcon: Icon(icon, color: AppTheme.textSecondary, size: 20),
        suffixIcon: suffixIcon,
      ),
    );
  }

  Widget _buildHowToCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppTheme.accentCyan.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppTheme.accentCyan.withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.info_outline_rounded,
                  color: AppTheme.accentCyan, size: 20),
              SizedBox(width: 8),
              Text('How to get credentials',
                  style: TextStyle(
                    color: AppTheme.accentCyan,
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                  )),
            ],
          ),
          const SizedBox(height: 14),
          ...[
            '1. Go to my.telegram.org/apps',
            '2. Log in with your phone number',
            '3. Create a new application',
            '4. Copy your API ID and API Hash',
            '5. Find a bot that downloads Spotify music (e.g. @spotifydownloaderbot)',
            '6. Enter the bot username with @ prefix',
          ].map((step) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('• ',
                        style: TextStyle(color: AppTheme.accentCyan, fontSize: 13)),
                    Expanded(
                      child: Text(
                        step,
                        style: const TextStyle(
                            color: AppTheme.textSecondary, fontSize: 13),
                      ),
                    ),
                  ],
                ),
              )),
        ],
      ),
    );
  }
}
