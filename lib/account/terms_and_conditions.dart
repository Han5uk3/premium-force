import 'package:flutter/material.dart';
import 'package:premium_force_main/l10n/app_localizations.dart';

class TermsAndConditionsPage extends StatelessWidget {
  const TermsAndConditionsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Color(0xFF1E1105),
            Color(0xFF1E1105),
            Color.fromARGB(255, 26, 23, 23),
            Color.fromARGB(255, 26, 23, 23),
          ],
        ),
      ),
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: _buildAppBar(context),
        body: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                AppLocalizations.of(context)!.termsIntro,
                style: const TextStyle(
                  color: Colors.white70,
                  fontSize: 14,
                  height: 1.5,
                ),
              ),
              _buildSection(
                AppLocalizations.of(context)!.termsSection1Title,
                AppLocalizations.of(context)!.termsSection1Content,
              ),
              _buildSection(
                AppLocalizations.of(context)!.termsSection2Title,
                AppLocalizations.of(context)!.termsSection2Content,
              ),
              _buildSection(
                AppLocalizations.of(context)!.termsSection3Title,
                AppLocalizations.of(context)!.termsSection3Content,
              ),
              _buildSection(
                AppLocalizations.of(context)!.termsSection4Title,
                AppLocalizations.of(context)!.termsSection4Content,
              ),
              _buildSection(
                AppLocalizations.of(context)!.termsSection5Title,
                AppLocalizations.of(context)!.termsSection5Content,
              ),
              _buildSection(
                AppLocalizations.of(context)!.termsSection6Title,
                AppLocalizations.of(context)!.termsSection6Content,
              ),
              _buildSection(
                AppLocalizations.of(context)!.termsSection7Title,
                AppLocalizations.of(context)!.termsSection7Content,
              ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSection(String title, String content) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            content,
            style: const TextStyle(
              color: Colors.white70,
              fontSize: 14,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }

  PreferredSizeWidget _buildAppBar(BuildContext context) {
    return PreferredSize(
      preferredSize: const Size.fromHeight(kToolbarHeight),
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.bottomCenter,
            end: Alignment.topCenter,
            colors: [Colors.black.withAlpha(150), Colors.transparent],
          ),
        ),
        child: AppBar(
          centerTitle: true,
          title: Text(
            AppLocalizations.of(context)!.termsAndConditions,
            style: const TextStyle(
              fontSize: 18,
              color: Colors.white,
              fontWeight: FontWeight.bold,
              letterSpacing: 0.5,
            ),
          ),
          backgroundColor: Colors.transparent,
          elevation: 0,
          leading: IconButton(
            icon: const Icon(
              Icons.arrow_back_ios,
              size: 16,
              color: Colors.white,
            ),
            onPressed: () => Navigator.pop(context),
          ),
        ),
      ),
    );
  }
}
