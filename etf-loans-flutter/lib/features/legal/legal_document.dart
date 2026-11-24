import 'package:flutter/material.dart';

import 'package:etf_loans/theme/theme_config.dart';

class LegalDocument extends StatelessWidget {
  const LegalDocument({
    super.key,
    required this.title,
    required this.introduction,
    required this.sections,
  });

  final String title;
  final String introduction;
  final List<({String title, List<String> paragraphs, bool bullets})> sections;

  @override
  Widget build(BuildContext context) {
    const bodyStyle = TextStyle(
      fontFamily: ThemeConfig.bodyFontFamily,
      color: ThemeConfig.bodyText,
      fontSize: 13.5,
      letterSpacing: 0,
      height: 1.52,
    );
    final headingStyle = bodyStyle.copyWith(
      color: ThemeConfig.ink,
      fontSize: 15,
      fontWeight: FontWeight.w700,
      fontVariations: const [FontVariation.weight(700)],
    );
    return Scaffold(
      backgroundColor: ThemeConfig.paperBg,
      body: SafeArea(
        child: Column(
          children: [
            Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 720),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Flexible(
                        child: TextButton.icon(
                          onPressed: () => Navigator.maybePop(context),
                          icon: const Icon(Icons.arrow_back, size: 18),
                          label: const Text('Back'),
                          style: TextButton.styleFrom(
                            padding: EdgeInsets.zero,
                            minimumSize: const Size(48, 64),
                            foregroundColor: ThemeConfig.ink,
                            textStyle: bodyStyle.copyWith(
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                              fontVariations: const [FontVariation.weight(600)],
                            ),
                          ),
                        ),
                      ),
                      Image.asset(
                        'assets/logos/logo.png',
                        width: 35,
                        height: 35,
                      ),
                    ],
                  ),
                ),
              ),
            ),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 680),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Semantics(
                          header: true,
                          child: Text(
                            title,
                            style: headingStyle.copyWith(
                              fontFamily: ThemeConfig.headingFontFamily,
                              fontSize: 27,
                              fontWeight: FontWeight.w800,
                              fontVariations: const [FontVariation.weight(800)],
                              letterSpacing: -0.55,
                              height: 1.15,
                            ),
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'Last updated 13 November 2026',
                          style: bodyStyle.copyWith(
                            color: ThemeConfig.mutedText,
                          ),
                        ),
                        const SizedBox(height: 24),
                        Text(introduction, style: bodyStyle),
                        for (final section in sections) ...[
                          const SizedBox(height: 23),
                          Semantics(
                            header: true,
                            child: Text(section.title, style: headingStyle),
                          ),
                          const SizedBox(height: 7),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            spacing: 7,
                            children: [
                              for (final paragraph in section.paragraphs)
                                if (section.bullets)
                                  Row(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      const ExcludeSemantics(
                                        child: SizedBox(
                                          width: 18,
                                          child: Text('•', style: bodyStyle),
                                        ),
                                      ),
                                      Expanded(
                                        child: Text(
                                          paragraph,
                                          style: bodyStyle,
                                        ),
                                      ),
                                    ],
                                  )
                                else
                                  Text(paragraph, style: bodyStyle),
                            ],
                          ),
                        ],
                        const SizedBox(height: 20),
                        Text(
                          'Internal demo copy. Pending formal approval.',
                          style: bodyStyle.copyWith(
                            fontSize: 12,
                            color: ThemeConfig.mutedText,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
