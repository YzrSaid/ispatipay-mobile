import 'package:flutter/material.dart';
import '../main.dart';
import '../services/settings_service.dart';
import '../services/telegram_service.dart';

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
  late TextEditingController _botTokenController;
  late TextEditingController _localServerController;
  bool _obscureApiHash = true;
  bool _obscureBotToken = true;
  bool _isSaving = false;
  bool _isSignedIn = false;
  String _signedInPhone = '';

  @override
  void initState() {
    super.initState();
    final s = SettingsService.settings;
    _apiIdController = TextEditingController(text: s.telegramApiId);
    _apiHashController = TextEditingController(text: s.telegramApiHash);
    _botUsernameController = TextEditingController(text: s.botUsername);
    _botTokenController = TextEditingController(text: s.botToken);
    _localServerController = TextEditingController(text: s.localTelegramServer);
    _isSignedIn = s.phone.isNotEmpty;
    _signedInPhone = s.phone;

    void syncFormState() {
      if (!mounted) return;
      setState(() {});
    }

    _apiIdController.addListener(syncFormState);
    _apiHashController.addListener(syncFormState);
    _botUsernameController.addListener(syncFormState);
    _botTokenController.addListener(syncFormState);
    _localServerController.addListener(syncFormState);
  }

  @override
  void dispose() {
    _apiIdController.dispose();
    _apiHashController.dispose();
    _botUsernameController.dispose();
    _botTokenController.dispose();
    _localServerController.dispose();
    super.dispose();
  }

  Future<void> _saveSettings() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSaving = true);
    await SettingsService.save(SettingsService.settings.copyWith(
      telegramApiId: _apiIdController.text.trim(),
      telegramApiHash: _apiHashController.text.trim(),
      botUsername: _botUsernameController.text.trim(),
      botToken: _botTokenController.text.trim(),
      localTelegramServer: _localServerController.text.trim(),
      phone: _signedInPhone,
    ));
    setState(() => _isSaving = false);

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Row(
            children: [
              Icon(Icons.check_circle_rounded,
                  color: AppTheme.accentGreen, size: 18),
              SizedBox(width: 8),
              Text('Settings saved successfully'),
            ],
          ),
          behavior: SnackBarBehavior.floating,
          backgroundColor: AppTheme.cardColor,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final canSaveSettings = _hasRequiredSettings && _hasPendingChanges;

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
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed:
                      (_isSaving || !canSaveSettings) ? null : _saveSettings,
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
    final isReady = isConfigured && _isSignedIn && !_hasPendingChanges;
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: AppTheme.accentGreen,
            borderRadius: BorderRadius.circular(14),
          ),
          child:
              const Icon(Icons.settings_rounded, color: Colors.black, size: 24),
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
                  style:
                      TextStyle(color: AppTheme.textSecondary, fontSize: 12)),
            ],
          ),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: isReady
                ? AppTheme.accentGreen.withValues(alpha: 0.15)
                : Colors.orange.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: isReady
                  ? AppTheme.accentGreen.withValues(alpha: 0.4)
                  : Colors.orange.withValues(alpha: 0.4),
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                isReady
                    ? Icons.check_circle_rounded
                    : Icons.warning_amber_rounded,
                size: 14,
                color: isReady ? AppTheme.accentGreen : Colors.orange,
              ),
              const SizedBox(width: 4),
              Text(
                isReady ? 'Ready' : 'Setup',
                style: TextStyle(
                  color: isReady ? AppTheme.accentGreen : Colors.orange,
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
            Row(
              children: [
                const Expanded(
                  child: Text('Telegram API Credentials',
                      style: TextStyle(
                        color: AppTheme.textPrimary,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      )),
                ),
                IconButton(
                  tooltip: 'How to get credentials',
                  onPressed: _showHowToCredentialsDialog,
                  icon: const Icon(Icons.help_outline_rounded,
                      color: AppTheme.textSecondary, size: 20),
                ),
              ],
            ),
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
            const SizedBox(height: 16),
            _buildField(
              controller: _botTokenController,
              label: 'Bot Token',
              hint: '123456:ABCDEF...',
              icon: Icons.lock_rounded,
              obscureText: _obscureBotToken,
              suffixIcon: IconButton(
                icon: Icon(
                  _obscureBotToken ? Icons.visibility_off : Icons.visibility,
                  color: AppTheme.textSecondary,
                  size: 18,
                ),
                onPressed: () =>
                    setState(() => _obscureBotToken = !_obscureBotToken),
              ),
              validator: (v) =>
                  v?.isEmpty ?? true ? 'Bot token is required' : null,
            ),
            const SizedBox(height: 16),
            _buildField(
              controller: _localServerController,
              label: 'Local Server',
              hint: 'http://localhost:8000',
              icon: Icons.computer,
              validator: (v) => null,
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton(
                    onPressed: () async {
                      final server = _localServerController.text.trim();
                      if (server.isEmpty) {
                        ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                                content: Text('Set local server URL first')));
                        return;
                      }
                      final phone =
                          await _promptForInput('Phone', '+1234567890');
                      if (phone == null || phone.isEmpty) return;
                      final sent = await _startAuth(server, phone);
                      if (sent != null) {
                        final code = await _promptForInput('Code', '12345');
                        if (code == null || code.isEmpty) return;
                        final res = await _completeAuth(server, phone, code);
                        if (res != null && res['signed_in'] == true) {
                          if (!mounted) return;
                          setState(() {
                            _isSignedIn = true;
                            _signedInPhone = phone;
                          });
                          ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                  content: Text('Signed in successfully')));
                        } else if (res != null &&
                            res['password_required'] == true) {
                          if (!mounted) return;
                          ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                  content:
                                      Text('2FA enabled: password required')));
                        } else {
                          if (!mounted) return;
                          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                              content: Text(
                                  'Sign-in failed: ${res?['error'] ?? 'unknown'}')));
                        }
                      } else {
                        if (!mounted) return;
                        ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                                content: Text('Failed to send code')));
                      }
                    },
                    child: const Text('Sign In'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Icon(
                  _isSignedIn
                      ? Icons.verified_rounded
                      : Icons.info_outline_rounded,
                  size: 14,
                  color: _isSignedIn
                      ? AppTheme.accentGreen
                      : AppTheme.textSecondary,
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    _isSignedIn
                        ? 'Signed in successfully. You can now save the settings.'
                        : 'Sign in first, then save the settings.',
                    style: const TextStyle(
                        color: AppTheme.textSecondary, fontSize: 12),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  bool get _hasRequiredSettings =>
      _apiIdController.text.trim().isNotEmpty &&
      _apiHashController.text.trim().isNotEmpty &&
      _botUsernameController.text.trim().isNotEmpty &&
      _botTokenController.text.trim().isNotEmpty;

  bool get _hasPendingChanges {
    final saved = SettingsService.settings;
    return _isSignedIn &&
        (_signedInPhone != saved.phone ||
            _apiIdController.text.trim() != saved.telegramApiId ||
            _apiHashController.text.trim() != saved.telegramApiHash ||
            _botUsernameController.text.trim() != saved.botUsername ||
            _botTokenController.text.trim() != saved.botToken ||
            _localServerController.text.trim() != saved.localTelegramServer);
  }

  void _showHowToCredentialsDialog() {
    showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          insetPadding:
              const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
          backgroundColor: AppTheme.cardColor,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          titlePadding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
          contentPadding: const EdgeInsets.fromLTRB(20, 14, 20, 12),
          actionsPadding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
          titleTextStyle: const TextStyle(
            color: AppTheme.textPrimary,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
          title: const Text('How to get credentials'),
          content: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ...[
                    '1. Go to my.telegram.org/apps',
                    '2. Log in with your phone number',
                    '3. Create a new application',
                    '4. Copy your API ID and API Hash',
                    '5. Use the recommended and currently working bot: @deezload2bot',
                    '6. Enter the bot username with @ prefix'
                  ].map(
                    (step) => Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: Text(
                        step,
                        style: const TextStyle(
                          color: AppTheme.textSecondary,
                          fontSize: 13,
                          height: 1.3,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text(
                'Close',
                style: TextStyle(color: AppTheme.accentGreen),
              ),
            ),
          ],
        );
      },
    );
  }

  Future<String?> _promptForInput(String title, String hint) async {
    String? result;
    await showDialog(
      context: context,
      builder: (ctx) {
        final c = TextEditingController(text: hint);
        return AlertDialog(
          title: Text(title),
          content: TextField(
              controller: c, decoration: InputDecoration(hintText: hint)),
          actions: [
            TextButton(
                onPressed: () => Navigator.of(ctx).pop(),
                child: const Text('Cancel')),
            TextButton(
                onPressed: () {
                  result = c.text.trim();
                  Navigator.of(ctx).pop();
                },
                child: const Text('OK')),
          ],
        );
      },
    );
    return result;
  }

  Future<Map<String, dynamic>?> _startAuth(String server, String phone) async {
    final serverUrl =
        server.endsWith('/') ? server.substring(0, server.length - 1) : server;
    final sent =
        await TelegramService.startAuth(serverUrl: serverUrl, phone: phone);
    return sent;
  }

  Future<Map<String, dynamic>?> _completeAuth(
      String server, String phone, String code) async {
    final serverUrl =
        server.endsWith('/') ? server.substring(0, server.length - 1) : server;
    final res = await TelegramService.completeAuth(
        serverUrl: serverUrl, phone: phone, code: code);
    return res;
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
}
