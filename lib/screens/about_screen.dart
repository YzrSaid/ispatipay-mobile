// lib/screens/about_screen.dart
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../main.dart';

class AboutScreen extends StatelessWidget {
  const AboutScreen({super.key});

  static const String _developerName = 'M.A. Yazar';
  static const String _developerGithub = 'https://github.com/YzrSaid';
  static const String _developerPortfolio =
      'https://ma-said-portfolio.vercel.app/';
  static const String _developerEmail = 'said.mohammadaldrin.2025@gmail.com';
  static const String _developerKoFi = 'ko-fi.com/mayazarrr';
  static const String _projectRepo = 'https://github.com/YzrSaid/ispatipay';

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
              _buildUsageCard(),
              const SizedBox(height: 20),
              _buildDeveloperCard(context),
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
            color: AppTheme.accentGreen,
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
            color: AppTheme.accentGreen,
            borderRadius: BorderRadius.circular(24),
            boxShadow: [
              BoxShadow(
                color: AppTheme.accentGreen.withValues(alpha: 0.4),
                blurRadius: 24,
                spreadRadius: 4,
              ),
            ],
          ),
          child: const Icon(Icons.music_note_rounded,
              color: Colors.black, size: 46),
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
      title: 'About this app',
      icon: Icons.info_outline_rounded,
      iconColor: AppTheme.accentGreen,
      content:
          'Ispatipay is a Spotify music downloader and player that works through a Telegram bot. '
          'Paste any Spotify track, album, or playlist link and the music is automatically '
          'downloaded or streamed to your device.',
    );
  }

  Widget _buildUsageCard() {
    return _listCard(
      title: 'How to Use',
      icon: Icons.help_outline_rounded,
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

  Widget _buildDeveloperCard(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppTheme.cardColor,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppTheme.borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.person_rounded, color: AppTheme.accentGreen, size: 18),
              SizedBox(width: 8),
              Text(
                'Developer',
                style: TextStyle(
                  color: AppTheme.textPrimary,
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          const Text(
            _developerName,
            style: TextStyle(
              color: AppTheme.textPrimary,
              fontSize: 22,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 4),
          const Text(
            'Built with a Spotify-inspired look and Telegram-powered workflow.',
            style: TextStyle(
              color: AppTheme.textSecondary,
              fontSize: 13,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 18),
          _buildProjectRepoTile(),
          const SizedBox(height: 18),
          const Text(
            'Connect with Me',
            style: TextStyle(
              color: AppTheme.textPrimary,
              fontSize: 15,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.start,
            spacing: 15,
            children: [
              _buildIconLink(
                tooltip: 'GitHub',
                icon: Icons.code_rounded,
                uri: Uri.parse(_developerGithub),
              ),
              _buildIconLink(
                tooltip: 'Portfolio',
                icon: Icons.language_rounded,
                uri: Uri.parse(_developerPortfolio),
              ),
              _buildIconLink(
                tooltip: 'Email',
                icon: Icons.email_rounded,
                uri: Uri(scheme: 'mailto', path: _developerEmail),
              ),
            ],
          ),
          const SizedBox(height: 15),
          const Text(
            'Treat me to a coffee ☕',
            style: TextStyle(
              color: AppTheme.textPrimary,
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          GestureDetector(
            onTap: () async {
              final uri = Uri.parse('https://$_developerKoFi');
              if (await canLaunchUrl(uri)) {
                await launchUrl(uri, mode: LaunchMode.externalApplication);
              }
            },
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
              decoration: BoxDecoration(
                color: AppTheme.surfaceColor,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: AppTheme.borderColor),
              ),
              child: Row(
                children: [
                  Container(
                    width: 34,
                    height: 34,
                    decoration: BoxDecoration(
                      color: AppTheme.textSecondary.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.coffee_rounded,
                        color: AppTheme.textSecondary, size: 18),
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Text(
                      'Ko-fi',
                      style: TextStyle(
                        color: AppTheme.textPrimary,
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  const Icon(Icons.open_in_new_rounded,
                      color: AppTheme.textSecondary, size: 16),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProjectRepoTile() {
    return GestureDetector(
      onTap: () async {
        final uri = Uri.parse(_projectRepo);
        if (await canLaunchUrl(uri)) {
          await launchUrl(uri, mode: LaunchMode.externalApplication);
        }
      },
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: AppTheme.surfaceColor,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppTheme.borderColor),
        ),
        child: Row(
          children: [
            Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(
                color: AppTheme.textSecondary.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.source_rounded,
                  color: AppTheme.textSecondary, size: 18),
            ),
            const SizedBox(width: 12),
            const Expanded(
              child: Text(
                'Project on GitHub',
                style: TextStyle(
                  color: AppTheme.textPrimary,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            const Icon(Icons.open_in_new_rounded,
                color: AppTheme.textSecondary, size: 16),
          ],
        ),
      ),
    );
  }

  Widget _buildIconLink({
    required String tooltip,
    required IconData icon,
    required Uri uri,
  }) {
    return Tooltip(
      message: tooltip,
      child: GestureDetector(
        onTap: () async {
          if (await canLaunchUrl(uri)) {
            await launchUrl(uri, mode: LaunchMode.externalApplication);
          }
        },
        child: Container(
          width: 54,
          height: 54,
          decoration: BoxDecoration(
            color: AppTheme.surfaceColor,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppTheme.borderColor),
          ),
          child: Icon(icon, color: AppTheme.textSecondary, size: 22),
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
