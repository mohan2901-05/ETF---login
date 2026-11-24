import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import 'package:etf_loans/shared/loans/emi_estimate.dart';
import 'package:etf_loans/shared/widgets/brand_card.dart';
import 'package:etf_loans/theme/theme_config.dart';

class EmiCalculator extends StatefulWidget {
  const EmiCalculator({super.key, this.initialPrincipal = 50000});

  final int initialPrincipal;

  @override
  State<EmiCalculator> createState() => _EmiCalculatorState();
}

class _EmiCalculatorState extends State<EmiCalculator> {
  static final _wholeRupees = NumberFormat.currency(
    locale: 'en_IN',
    symbol: '₹',
    decimalDigits: 0,
  );
  static final _fractionalRupees = NumberFormat.currency(
    locale: 'en_IN',
    symbol: '₹',
    decimalDigits: 2,
  );
  static final _indianNumber = NumberFormat.decimalPattern('en_IN');

  static const _sliderStep = 1000;
  late int _principal = widget.initialPrincipal;
  EmiTenure _tenure = EmiTenure.six;

  String _money(int paise) => paise % 100 == 0
      ? _wholeRupees.format(paise ~/ 100)
      : _fractionalRupees.format(paise / 100);

  @override
  Widget build(BuildContext context) {
    final estimate = EmiEstimate.calculate(
      principalRupees: _principal,
      tenure: _tenure,
    );
    const minimum = EmiEstimate.minPrincipalRupees;
    const maximum = EmiEstimate.maxPrincipalRupees;
    final share = estimate.interestPaise / estimate.totalPaise;
    final rate = _tenure.monthlyFlatRatePercent;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text('Loan amount', style: _label),
        const SizedBox(height: 11),
        Text(
          _wholeRupees.format(_principal),
          style: _amount.copyWith(fontSize: 40),
        ),
        const Divider(height: 12, color: ThemeConfig.ruleStrong),
        Semantics(
          label: 'Loan amount',
          child: SliderTheme(
            data: SliderTheme.of(context).copyWith(
              activeTrackColor: ThemeConfig.primaryGreen,
              inactiveTrackColor: ThemeConfig.ruleStrong,
              thumbColor: ThemeConfig.cardBg,
              overlayColor: ThemeConfig.primaryGreen.withValues(alpha: 0.12),
              trackHeight: 6,
              trackShape: const RoundedRectSliderTrackShape(),
              thumbShape: const RoundSliderThumbShape(
                enabledThumbRadius: 11,
                elevation: 3,
              ),
              tickMarkShape: SliderTickMarkShape.noTickMark,
            ),
            child: Slider(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              value: _principal.toDouble(),
              min: minimum.toDouble(),
              max: maximum.toDouble(),
              divisions: (maximum - minimum) ~/ _sliderStep,
              label: _wholeRupees.format(_principal),
              semanticFormatterCallback: (value) =>
                  '${_indianNumber.format(value)} Indian rupees',
              onChanged: (value) => setState(() => _principal = value.round()),
            ),
          ),
        ),
        Row(
          children: [
            Expanded(child: Text(_wholeRupees.format(minimum), style: _muted)),
            Expanded(
              child: Text(
                _wholeRupees.format(maximum),
                style: _muted,
                textAlign: TextAlign.end,
              ),
            ),
          ],
        ),
        const SizedBox(height: 19),
        const Text('For how long?', style: _label),
        const SizedBox(height: 8),
        LayoutBuilder(
          builder: (context, constraints) {
            const gap = 8.0;
            final scaledSize = MediaQuery.textScalerOf(context).scale(14);
            final columns = (constraints.maxWidth / (scaledSize * 7 + gap))
                .floor()
                .clamp(1, 3);
            final width =
                (constraints.maxWidth - (columns - 1) * gap) / columns;
            return Wrap(
              spacing: gap,
              runSpacing: gap,
              children: [
                for (final tenure in EmiTenure.values)
                  SizedBox(
                    width: width,
                    child: _TenureOption(
                      tenure: tenure,
                      selected: _tenure == tenure,
                      onSelected: () => setState(() => _tenure = tenure),
                    ),
                  ),
              ],
            );
          },
        ),
        const SizedBox(height: 18),
        BrandCard(
          padding: const EdgeInsets.all(17),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text('Monthly EMI', style: _muted),
              const SizedBox(height: 3),
              Wrap(
                alignment: WrapAlignment.spaceBetween,
                crossAxisAlignment: WrapCrossAlignment.center,
                runSpacing: 8,
                spacing: 8,
                children: [
                  Wrap(
                    crossAxisAlignment: WrapCrossAlignment.center,
                    spacing: 4,
                    children: [
                      Text(
                        _wholeRupees.format(estimate.regularEmiRupees),
                        style: _amount,
                      ),
                      Text('× ${_tenure.months}', style: _muted),
                    ],
                  ),
                  DecoratedBox(
                    decoration: BoxDecoration(
                      color: ThemeConfig.tintGreen,
                      borderRadius: BorderRadius.circular(
                        ThemeConfig.radiusPill,
                      ),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 9,
                        vertical: 5,
                      ),
                      child: Text(
                        '$rate% A MONTH',
                        style: _label.copyWith(
                          fontSize: 10,
                          letterSpacing: 0.6,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Semantics(
                label:
                    'Amount ${((1 - share) * 100).round()} percent, interest ${(share * 100).round()} percent',
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(ThemeConfig.radiusPill),
                  child: SizedBox(
                    height: 7,
                    child: LayoutBuilder(
                      builder: (context, constraints) => Row(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Expanded(
                            child: ColoredBox(color: ThemeConfig.primaryGreen),
                          ),
                          SizedBox(
                            width: constraints.maxWidth * share,
                            child: const ColoredBox(
                              color: ThemeConfig.accentLime,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 7),
              const Wrap(
                spacing: 14,
                runSpacing: 6,
                children: [
                  _Legend('Amount', ThemeConfig.primaryGreen),
                  _Legend('Interest', ThemeConfig.accentLime),
                ],
              ),
              const SizedBox(height: 9),
              _EstimateRow('Interest rate', '$rate% a month, flat'),
              const Divider(height: 1, color: ThemeConfig.ruleLight),
              _EstimateRow('Total interest', _money(estimate.interestPaise)),
              const Divider(height: 1, color: ThemeConfig.ruleLight),
              _EstimateRow('Final EMI', _money(estimate.finalEmiPaise)),
              const Divider(height: 1, color: ThemeConfig.ruleLight),
              _EstimateRow(
                'Total you repay',
                _money(estimate.totalPaise),
                total: true,
              ),
            ],
          ),
        ),
        const SizedBox(height: 9),
        const Text(
          'Illustrative estimate only. An approved loan quote provides your actual rate, fees, APR and repayment schedule.',
          style: _muted,
        ),
      ],
    );
  }
}

const _label = TextStyle(
  fontFamily: ThemeConfig.bodyFontFamily,
  fontSize: 14,
  fontWeight: FontWeight.w700,
  fontVariations: [FontVariation.weight(700)],
  color: ThemeConfig.ink,
  height: 1.2,
  letterSpacing: 0,
);
const _muted = TextStyle(
  fontFamily: ThemeConfig.bodyFontFamily,
  fontSize: 12,
  color: ThemeConfig.mutedText,
  height: 1.35,
  letterSpacing: 0,
);
const _amount = TextStyle(
  fontFamily: ThemeConfig.headingFontFamily,
  fontSize: 31,
  fontWeight: FontWeight.w800,
  fontVariations: [FontVariation.weight(800)],
  color: ThemeConfig.ink,
  letterSpacing: -0.9,
  height: 1.1,
);

class _TenureOption extends StatelessWidget {
  const _TenureOption({
    required this.tenure,
    required this.selected,
    required this.onSelected,
  });

  final EmiTenure tenure;
  final bool selected;
  final VoidCallback onSelected;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      selected: selected,
      label: '${tenure.months} months',
      child: OutlinedButton(
        onPressed: onSelected,
        style: OutlinedButton.styleFrom(
          foregroundColor: ThemeConfig.ink,
          backgroundColor: selected
              ? ThemeConfig.tintGreen
              : ThemeConfig.cardBg,
          minimumSize: const Size(0, 62),
          padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 10),
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          side: BorderSide(
            color: selected ? ThemeConfig.primaryGreen : ThemeConfig.ruleStrong,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(ThemeConfig.radiusBase),
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          spacing: 4,
          children: [
            ExcludeSemantics(
              child: Text(
                '${tenure.months} mo',
                style: _label,
                textAlign: TextAlign.center,
              ),
            ),
            Text(
              '${tenure.monthlyFlatRatePercent}% / month',
              style: _muted,
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

class _Legend extends StatelessWidget {
  const _Legend(this.label, this.color);

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      spacing: 5,
      children: [
        SizedBox(width: 7, height: 7, child: ColoredBox(color: color)),
        Text(label, style: _muted),
      ],
    );
  }
}

class _EstimateRow extends StatelessWidget {
  const _EstimateRow(this.label, this.value, {this.total = false});

  final String label;
  final String value;
  final bool total;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 9),
      child: Row(
        spacing: 8,
        children: [
          Expanded(child: Text(label, style: _muted.copyWith(fontSize: 13))),
          Expanded(
            child: Text(
              value,
              textAlign: TextAlign.end,
              style: total ? _amount.copyWith(fontSize: 19) : _label,
            ),
          ),
        ],
      ),
    );
  }
}
