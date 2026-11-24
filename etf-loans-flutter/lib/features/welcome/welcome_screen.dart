import 'package:flutter/material.dart';

import 'package:etf_loans/core/constants/app_routes.dart';
import 'package:etf_loans/shared/widgets/brand_card.dart';
import 'package:etf_loans/shared/widgets/custom_widgets.dart';
import 'package:etf_loans/shared/widgets/emi_calculator.dart';
import 'package:etf_loans/theme/theme_config.dart';

class WelcomeScreen extends StatelessWidget {
  const WelcomeScreen({this.onTerms, this.onPrivacy, super.key});

  final VoidCallback? onTerms;
  final VoidCallback? onPrivacy;

  static void _signIn(BuildContext context) {
    Navigator.pushNamed(context, AppRoutes.signIn);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: ThemeConfig.paperBg,
      body: SafeArea(
        child: SingleChildScrollView(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 440),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const _Hero(),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 36, 20, 18),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      spacing: 46,
                      children: [
                        const _Section(
                          label: 'How it works',
                          title: 'Three steps, no branch visits',
                          child: _Process(),
                        ),
                        const _Section(
                          label: 'Pricing',
                          title: 'One rule, shown up front',
                          description: 'Illustrative flat interest on what you borrow. The demo assumes no processing fee or other charges.',
                          child: _Pricing(),
                        ),
                        const _Section(
                          label: 'Try it',
                          title: 'Work out your EMI',
                          description:
                              'Explore an illustrative estimate for your loan.',
                          child: EmiCalculator(initialPrincipal: 100000),
                        ),
                        const _Section(
                          label: 'What you need',
                          title: 'Who can apply',
                          child: _Eligibility(),
                        ),
                        const _Section(
                          label: 'Questions',
                          title: 'Good to know',
                          child: _Faq(),
                        ),
                        _Footer(
                          onEligibility: () => _signIn(context),
                          onTerms:
                              onTerms ??
                              () =>
                                  Navigator.pushNamed(context, AppRoutes.terms),
                          onPrivacy:
                              onPrivacy ??
                              () => Navigator.pushNamed(
                                context,
                                AppRoutes.privacy,
                              ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

TextStyle _body(
  double size, {
  Color color = ThemeConfig.bodyText,
  double height = 1.4,
}) => TextStyle(
  fontFamily: ThemeConfig.bodyFontFamily,
  fontSize: size,
  color: color,
  height: height,
  letterSpacing: 0,
);

TextStyle _strong(double size, {Color color = ThemeConfig.ink}) =>
    _body(size, color: color, height: 1.2).copyWith(
      fontWeight: FontWeight.w700,
      fontVariations: const [FontVariation.weight(700)],
    );

TextStyle _heading(double size, {Color color = ThemeConfig.ink}) =>
    _strong(size, color: color).copyWith(
      fontFamily: ThemeConfig.headingFontFamily,
      fontWeight: FontWeight.w800,
      fontVariations: const [FontVariation.weight(800)],
      letterSpacing: -size * 0.035,
      height: 1.08,
    );

class _Hero extends StatelessWidget {
  const _Hero();

  @override
  Widget build(BuildContext context) {
    const highlights = [
      ('Borrow up to', '₹5,00,000'),
      ('Interest from', '2% a month'),
      ('Demo processing fee', '₹0'),
      ('Illustrative payout', 'Same day'),
    ];
    final headline = _heading(36, color: ThemeConfig.cardBg);
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 23, 20, 25),
      decoration: const BoxDecoration(
        gradient: ThemeConfig.heroGradientMobile,
        borderRadius: BorderRadius.vertical(bottom: Radius.circular(32)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Image.asset('assets/logos/logo.png', width: 36, height: 36),
              const SizedBox(width: 10),
              Flexible(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  spacing: 3,
                  children: [
                    Text(
                      'ETF Loans',
                      style: _heading(18, color: ThemeConfig.cardBg),
                    ),
                    Text(
                      'BY EPIC TAASFORCE',
                      style: _strong(
                        10,
                        color: ThemeConfig.onDeepMuted,
                      ).copyWith(letterSpacing: 1.2),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 42),
          Semantics(
            header: true,
            child: Text.rich(
              TextSpan(
                text: 'Personal loans\n',
                children: [
                  TextSpan(
                    text: 'without the paperwork.',
                    style: headline.copyWith(color: ThemeConfig.accentLime),
                  ),
                ],
              ),
              style: headline,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'Explore what you could borrow.\nSee the full cost before you commit.',
            style: _body(15, color: ThemeConfig.onDeep, height: 1.45),
          ),
          const SizedBox(height: 27),
          Table(
            defaultVerticalAlignment:
                TableCellVerticalAlignment.intrinsicHeight,
            columnWidths: const {1: FixedColumnWidth(8)},
            children: [
              for (var index = 0; index < highlights.length; index += 2)
                TableRow(
                  children: [
                    _Highlight(highlights[index]),
                    const SizedBox(width: 8),
                    _Highlight(highlights[index + 1]),
                  ],
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _Highlight extends StatelessWidget {
  const _Highlight(this.highlight);

  final (String, String) highlight;

  @override
  Widget build(BuildContext context) {
    final (label, value) = highlight;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: ThemeConfig.cardBg.withValues(alpha: 0.075),
          borderRadius: BorderRadius.circular(ThemeConfig.radiusBase),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 15),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            spacing: 3,
            children: [
              Text(label, style: _body(11, color: ThemeConfig.onDeepMuted)),
              Text(value, style: _heading(18, color: ThemeConfig.cardBg)),
            ],
          ),
        ),
      ),
    );
  }
}

class _Section extends StatelessWidget {
  const _Section({
    required this.label,
    required this.title,
    required this.child,
    this.description,
  });

  final String label;
  final String title;
  final String? description;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          label.toUpperCase(),
          style: _strong(
            10,
            color: ThemeConfig.primaryGreenMid,
          ).copyWith(letterSpacing: 1.4),
        ),
        const SizedBox(height: 7),
        Semantics(header: true, child: Text(title, style: _heading(23))),
        if (description case final description?) ...[
          const SizedBox(height: 8),
          Text(description, style: _body(14)),
        ],
        const SizedBox(height: 15),
        child,
      ],
    );
  }
}

class _Process extends StatelessWidget {
  const _Process();

  @override
  Widget build(BuildContext context) {
    const steps = [
      (
        'Check your limit',
        'Share a few basic details to see an illustrative limit. Credit checks are simulated and your score is unaffected in this demo.',
      ),
      (
        'Pick an amount and an EMI plan',
        'Review the EMI, interest and total repayment before accepting an offer.',
      ),
      (
        'Get the money',
        'In the illustrated flow, approved funds would be sent to your bank account.',
      ),
    ];
    return Column(
      spacing: 22,
      children: [
        for (final (index, (title, description)) in steps.indexed)
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            spacing: 14,
            children: [
              Container(
                constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: ThemeConfig.tintGreen,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  '${index + 1}',
                  style: _heading(17, color: ThemeConfig.primaryGreenMid),
                ),
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  spacing: 4,
                  children: [
                    Text(title, style: _strong(15)),
                    Text(description, style: _body(14)),
                  ],
                ),
              ),
            ],
          ),
      ],
    );
  }
}

class _Pricing extends StatelessWidget {
  const _Pricing();

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: 8,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Flexible(
                child: Text(
                  'IF YOU REPAY IN',
                  style: _strong(10).copyWith(letterSpacing: 1),
                ),
              ),
              Flexible(
                child: Text(
                  'INTEREST',
                  style: _strong(10).copyWith(letterSpacing: 1),
                ),
              ),
            ],
          ),
        ),
        const _PriceRow('6 months or less', 'Lowest cost', 2, featured: true),
        const _PriceRow('7 to 24 months', 'Smaller EMIs', 3),
      ],
    );
  }
}

class _PriceRow extends StatelessWidget {
  const _PriceRow(this.tenure, this.note, this.rate, {this.featured = false});

  final String tenure;
  final String note;
  final int rate;
  final bool featured;

  @override
  Widget build(BuildContext context) {
    final textColor = featured ? ThemeConfig.onDeep : ThemeConfig.ink;
    final noteColor = featured
        ? ThemeConfig.onDeepMuted
        : ThemeConfig.mutedText;
    return BrandCard(
      color: featured ? ThemeConfig.primaryGreenDeep : ThemeConfig.cardBg,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      child: Row(
        spacing: 10,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              spacing: 3,
              children: [
                Text(tenure, style: _strong(14, color: textColor)),
                Text(note, style: _body(12, color: noteColor)),
              ],
            ),
          ),
          Expanded(
            child: Text.rich(
              TextSpan(
                text: '$rate%',
                style: _heading(
                  26,
                  color: featured ? ThemeConfig.accentLime : textColor,
                ),
                children: [
                  TextSpan(
                    text: ' a month',
                    style: _body(12, color: noteColor),
                  ),
                ],
              ),
              textAlign: TextAlign.end,
            ),
          ),
        ],
      ),
    );
  }
}

class _Eligibility extends StatelessWidget {
  const _Eligibility();

  @override
  Widget build(BuildContext context) {
    const criteria = [
      ('Age', '21 to 60 years'),
      ('Monthly income', '₹15,000 or more'),
      ('Credit score', '650 or above'),
      ('Documents', 'PAN, Aadhaar and a selfie'),
    ];
    return BrandCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          for (final (index, (label, value)) in criteria.indexed) ...[
            if (index > 0)
              const Divider(height: 1, color: ThemeConfig.ruleLight),
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 11),
              child: Row(
                spacing: 8,
                children: [
                  Expanded(child: Text(label, style: _body(13))),
                  Expanded(
                    flex: 2,
                    child: Text(
                      value,
                      style: _strong(14),
                      textAlign: TextAlign.end,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _Faq extends StatelessWidget {
  const _Faq();

  @override
  Widget build(BuildContext context) {
    const answers = [
      (
        'Will checking my limit lower my credit score?',
        'This demo simulates credit checks. No bureau enquiry is made.',
      ),
      (
        'How is my limit worked out?',
        'Income, existing EMIs and credit information are example inputs. Actual eligibility would depend on an approved assessment.',
      ),
      (
        'Why do you need a selfie?',
        'A selfie may be used to verify your identity as part of a loan application.',
      ),
      (
        'Are there processing or hidden fees?',
        'The calculator assumes zero processing fees. Check the approved quote for any applicable charges.',
      ),
      (
        'Can I close my loan early?',
        'Refer to your loan agreement for any early repayment terms.',
      ),
    ];
    return Column(
      spacing: 7,
      children: [
        for (final (question, answer) in answers)
          _FaqCard(question: question, answer: answer),
      ],
    );
  }
}

class _FaqCard extends StatefulWidget {
  const _FaqCard({required this.question, required this.answer});

  final String question;
  final String answer;

  @override
  State<_FaqCard> createState() => _FaqCardState();
}

class _FaqCardState extends State<_FaqCard> {
  final _expansion = ExpansibleController();

  @override
  void dispose() {
    _expansion.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      color: ThemeConfig.cardBg,
      borderRadius: BorderRadius.circular(ThemeConfig.radiusBase),
      clipBehavior: Clip.antiAlias,
      child: Expansible(
        controller: _expansion,
        maintainState: false,
        animationStyle: MediaQuery.disableAnimationsOf(context)
            ? AnimationStyle.noAnimation
            : const AnimationStyle(duration: Duration(milliseconds: 200)),
        headerBuilder: (context, animation) {
          return InkWell(
            onTap: _expansion.isExpanded
                ? _expansion.collapse
                : _expansion.expand,
            child: Semantics(
              expanded: _expansion.isExpanded,
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 11,
                ),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(minHeight: 26),
                  child: Row(
                    spacing: 10,
                    children: [
                      Expanded(
                        child: Text(widget.question, style: _strong(14)),
                      ),
                      Icon(
                        _expansion.isExpanded ? Icons.remove : Icons.add,
                        size: 16,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        },
        bodyBuilder: (context, animation) => Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
          child: SizedBox(
            width: double.infinity,
            child: Text(widget.answer, style: _body(14)),
          ),
        ),
      ),
    );
  }
}

class _Footer extends StatelessWidget {
  const _Footer({
    required this.onEligibility,
    required this.onTerms,
    required this.onPrivacy,
  });

  final VoidCallback onEligibility;
  final VoidCallback onTerms;
  final VoidCallback onPrivacy;

  @override
  Widget build(BuildContext context) {
    final linkStyle = TextButton.styleFrom(
      foregroundColor: ThemeConfig.bodyText,
      minimumSize: const Size(48, 44),
      padding: const EdgeInsets.symmetric(horizontal: 4),
      textStyle: _body(12).copyWith(decoration: TextDecoration.underline),
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'ETF Loans is a product of Epic TaasForce. Loan amounts, rates, timing and eligibility criteria are illustrative. This is a demonstration build, where credit checks are simulated and no money moves.',
          style: _body(12, color: ThemeConfig.mutedText),
        ),
        Wrap(
          spacing: 8,
          children: [
            TextButton(
              onPressed: onTerms,
              style: linkStyle,
              child: const Text('Terms of Service'),
            ),
            TextButton(
              onPressed: onPrivacy,
              style: linkStyle,
              child: const Text('Privacy Policy'),
            ),
          ],
        ),
        const SizedBox(height: 14),
        PrimaryButton(title: 'Check my eligibility', onPressed: onEligibility),
        Center(
          child: TextButton(
            onPressed: onEligibility,
            style: linkStyle,
            child: const Text(
              'Already a customer? Sign in',
              textAlign: TextAlign.center,
            ),
          ),
        ),
      ],
    );
  }
}
