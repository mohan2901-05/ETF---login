import 'package:flutter/material.dart';

import 'legal_document.dart';

class TermsScreen extends StatelessWidget {
  const TermsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const LegalDocument(
      title: 'Terms of Service',
      introduction: 'These terms apply when you use ETF Loans, a service of Epic TaasForce ("we", "us"). By creating an account you agree to them.',
      sections: [
        (
          title: '1. Who can use ETF Loans',
          paragraphs: [
            'You must be an Indian resident aged 21 to 60, apply in your own name and give accurate information. We may ask for documents to confirm what you tell us.',
          ],
          bullets: false,
        ),
        (
          title: '2. Your account',
          paragraphs: [
            'You sign in with a one-time code sent to your mobile number. Keep your phone and codes to yourself. Tell us at once if you think someone else has used your account.',
          ],
          bullets: false,
        ),
        (
          title: '3. Eligibility and credit checks',
          paragraphs: [
            'With your consent we obtain your credit report from a credit bureau and assess your income and existing EMIs. An eligibility result is an estimate of what we can lend and may change if your circumstances change.',
          ],
          bullets: false,
        ),
        (
          title: '4. Loans, interest and repayment',
          paragraphs: [
            'Interest is flat on the amount borrowed: 2% a month for loans of 6 months or less, and 3% a month for longer loans.',
            'There is no processing fee. The total you repay is shown before you accept and does not change afterwards.',
            'EMIs fall due monthly on the dates in your repayment schedule. You may repay early at any time.',
            'The loan agreement and Key Facts Statement you accept for each loan form part of these terms. If they differ, the loan agreement applies.',
          ],
          bullets: true,
        ),
        (
          title: '5. Missed payments',
          paragraphs: [
            'If an EMI is missed we will remind you and may report the delay to credit bureaus, which can lower your credit score. Contact us early if you expect difficulty paying.',
          ],
          bullets: false,
        ),
        (
          title: '6. Acceptable use',
          paragraphs: [
            "Do not apply using someone else's identity, give false information, or interfere with the service. We may suspend an account where we suspect fraud.",
          ],
          bullets: false,
        ),
        (
          title: '7. Changes and closure',
          paragraphs: [
            'We may update these terms and will tell you in the app before a change takes effect. You can close your account once all loans are repaid.',
          ],
          bullets: false,
        ),
        (
          title: '8. Complaints',
          paragraphs: [
            'Write to support@epictaasforce.com. We aim to reply within two working days.',
          ],
          bullets: false,
        ),
        (
          title: '9. Governing law',
          paragraphs: ['These terms are governed by the laws of India.'],
          bullets: false,
        ),
      ],
    );
  }
}
