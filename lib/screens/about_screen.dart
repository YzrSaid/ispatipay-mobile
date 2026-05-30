// lib/screens/about_screen.dart
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../main.dart';

class AboutScreen extends StatelessWidget {
  const AboutScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.bgColor,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            children: [
              _buildHeader(),
              const SizedBox(height: 28),
              _buildLogoSection(),
              const SizedBox(height: 28),
              _buildInfoCard(),
              const SizedBox(height: 20),
              _buildFeaturesCard(),
              const SizedBox(height: 20),
              _buildUsageCard(),
              const SizedBox(height: 20),
              _buildGithubButton(context),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFFFF4081), Color(0xFFFF6E40)],
            ),
            borderRadius: BorderRadius.circular(14),
          ),
          child: const Icon(Icons.info_rounded, color: Colors.black, size: 24),
        ),
        const SizedBox(width: 14),
        const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('About',
                style: TextStyle(
                  color: AppTheme.textPrimary,
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                )),
            Text('App information & help',
                style: TextStyle(color: AppTheme.textSecondary, fontSize: 12)),
          ],
        ),
      ],
    );
  }

  Widget _buildLogoSection() {
    return Column(
      children: [
        Container(
          width: 90,
          height: 90,
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [AppTheme.accentGreen, AppTheme.accentCyan],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(24),
            boxShadow: [
              BoxShadow(
                color: AppTheme.accentGreen.withValues(alpha: 0.4),
                blurRadius: 24,
                spreadRadius: 4,
              ),
            ],
          ),
          child: const Icon(Icons.music_note_rounded, color: Colors.black, size: 46),
        ),
        const SizedBox(height: 16),
        const Text('ISPATIPAY',
            style: TextStyle(
              color: AppTheme.textPrimary,
              fontSize: 28,
              fontWeight: FontWeight.w900,
              letterSpacing: 4,
            )),
        const SizedBox(height: 6),
        const Text('v1.0.0 — Flutter Mobile Edition',
            style: TextStyle(color: AppTheme.textSecondary, fontSize: 13)),
      ],
    );
  }

  Widget _buildInfoCard() {
    return _card(
      title: 'What is Ispatipay?',
      icon: Icons.help_outline_rounded,
      iconColor: AppTheme.accentCyan,
      content:
          'Ispatipay is a Spotify music downloader and player that works through a Telegram bot. '
          'Paste any Spotify track, album, or playlist link and the music is automatically '
          'downloaded or streamed to your device.',
    );
  }

  Widget _buildFeaturesCard() {
    return _listCard(
      title: 'Features',
      icon: Icons.star_rounded,
      iconColor: Colors.amber,
      items: [
        '🎵 Download individual tracks',
        '💿 Download full albums',
        '📋 Download entire playlists',
        '▶️ Stream music instantly',
        '🎮 Full playback controls (play, pause, skip)',
        '🔀 Shuffle & repeat modes',
        '📱 Clean, modern mobile UI',
        '📊 Live download progress',
        '🔧 Configurable Telegram credentials',
      ],
    );
  }

  Widget _buildUsageCard() {
    return _listCard(
      title: 'How to Use',
      icon: Icons.help_rounded,
      iconColor: AppTheme.accentGreen,
      items: [
        '1. Set up Telegram credentials in Settings',
        '2. Go to Downloader tab and paste a Spotify link',
        '3. Tap "Start Download" — the bot handles the rest',
        '4. Or go to Player tab to stream immediately',
        '5. Control playback with the on-screen player',
      ],
    );
  }

  Widget _buildGithubButton(BuildContext context) {
    return GestureDetector(
      onTap: () async {
        final uri = Uri.parse('https://github.com/YzrSaid/ispatipay');
        if (await canLaunchUrl(uri)) {
          await launchUrl(uri, mode: LaunchMode.externalApplication);
        }
      },
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppTheme.cardColor,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppTheme.borderColor),
        ),
        child: const Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.code_rounded, color: AppTheme.textPrimary, size: 20),
            SizedBox(width: 10),
            Text('View Source on GitHub',
                style: TextStyle(
                  color: AppTheme.textPrimary,
                  fontWeight: FontWeight.bold,
                )),
            SizedBox(width: 6),
            Icon(Icons.open_in_new_rounded, color: AppTheme.textSecondary, size: 16),
          ],
        ),
      ),
    );
  }

  Widget _card({
    required String title,
    required IconData icon,
    required Color iconColor,
    required String content,
  }) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppTheme.cardColor,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppTheme.borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: iconColor, size: 18),
              const SizedBox(width: 8),
              Text(title,
                  style: const TextStyle(
                    color: AppTheme.textPrimary,
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                  )),
            ],
          ),
          const SizedBox(height: 12),
          Text(content,
              style: const TextStyle(
                color: AppTheme.textSecondary,
                fontSize: 13,
                height: 1.6,
              )),
        ],
      ),
    );
  }

  Widget _listCard({
    required String title,
    required IconData icon,
    required Color iconColor,
    required List<String> items,
  }) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppTheme.cardColor,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppTheme.borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: iconColor, size: 18),
              const SizedBox(width: 8),
              Text(title,
                  style: const TextStyle(
                    color: AppTheme.textPrimary,
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                  )),
            ],
          ),
          const SizedBox(height: 14),
          ...items.map((item) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Text(
                  item,
                  style: const TextStyle(
                      color: AppTheme.textSecondary, fontSize: 13, height: 1.4),
                ),
              )),
        ],
      ),
    );
  }
}
