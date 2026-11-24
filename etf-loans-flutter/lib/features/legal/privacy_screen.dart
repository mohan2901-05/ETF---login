import 'package:flutter/material.dart';

import 'legal_document.dart';

class PrivacyScreen extends StatelessWidget {
  const PrivacyScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const LegalDocument(
      title: 'Privacy Policy',
      introduction: 'This policy explains what ETF Loans, a service of Epic TaasForce, collects about you, why, and the choices you have.',
      sections: [
        (
          title: '1. What we collect',
          paragraphs: [
            'Contact: your mobile number.',
            'Identity: your name, PAN and date of birth, and a selfie if you complete the face check.',
            'Financial: how you earn, your monthly income, EMIs you already pay, your credit report and score, and the bank account you choose for disbursal.',
            'Usage: the loans you take and the payments you make.',
          ],
          bullets: true,
        ),
        (
          title: '2. Why we use it',
          paragraphs: [
            'To confirm who you are, decide whether and how much we can lend, pay out and collect loans, prevent fraud, and meet our legal obligations. We do not sell your data and we do not use your PAN, selfie or credit report for marketing.',
          ],
          bullets: false,
        ),
        (
          title: '3. Credit bureau checks',
          paragraphs: [
            'We fetch your credit report only after you tick the consent box. An eligibility check is a soft enquiry and does not affect your score. Loans you take and how you repay them may be reported to credit bureaus.',
          ],
          bullets: false,
        ),
        (
          title: '4. Who we share it with',
          paragraphs: [
            'Credit bureaus, identity and face verification providers, banks and payment partners that move money for your loan, and authorities where the law requires it. Each receives only what it needs.',
          ],
          bullets: false,
        ),
        (
          title: '5. How long we keep it',
          paragraphs: [
            'For as long as you have an account and afterwards for the period the law requires for lending records. Selfies used for verification are deleted once the check is complete unless the law requires otherwise.',
          ],
          bullets: false,
        ),
        (
          title: '6. Security',
          paragraphs: [
            'Data is encrypted in transit and at rest, and access is limited to staff who need it. Sensitive values such as your PAN and account number are masked on screen.',
          ],
          bullets: false,
        ),
        (
          title: '7. Your choices',
          paragraphs: [
            'You can see and correct your details in Profile, withdraw consent for future credit checks, and ask for a copy or deletion of your data where the law allows.',
          ],
          bullets: false,
        ),
        (
          title: '8. Contact',
          paragraphs: [
            'For privacy questions or requests, write to support@epictaasforce.com.',
          ],
          bullets: false,
        ),
      ],
    );
  }
}
