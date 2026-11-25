import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/config/env.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/async_value_view.dart';

/// A question and answer on the Help page. The admin writes them in the
/// admin web under Help and legal (`faqs/{id}` with `app: delivery`).
@immutable
class Faq {
  const Faq({required this.question, required this.answer});

  final String question;
  final String answer;
}

/// The delivery partner terms or privacy policy, written by the admin in
/// the admin web under Help and legal (`pages/{id}`).
abstract final class LegalPages {
  static const termsId = 'delivery_terms';
  static const privacyId = 'delivery_privacy';

  static String titleOf(String id) =>
      id == privacyId ? 'Privacy policy' : 'Terms and conditions';
}

abstract interface class HelpRepository {
  /// The delivery app's questions, in the admin's order.
  Future<List<Faq>> fetchFaqs();

  /// The text of a legal page; null when the admin has not published it.
  Future<String?> fetchPage(String id);
}

class FakeHelpRepository implements HelpRepository {
  @override
  Future<List<Faq>> fetchFaqs() async => const [
        Faq(
          question: 'How do I go offline?',
          answer: 'Switch off "Available for orders" on the Profile page.',
        ),
        Faq(
          question: 'How do I collect payment for a cash order?',
          answer: 'The order shows the amount to collect. Take the cash, or '
              'show the store QR if the customer wants to scan.',
        ),
      ];

  @override
  Future<String?> fetchPage(String id) async =>
      'Sample ${LegalPages.titleOf(id).toLowerCase()} text.';
}

class FirestoreHelpRepository implements HelpRepository {
  FirestoreHelpRepository(this._db);

  final FirebaseFirestore _db;

  @override
  Future<List<Faq>> fetchFaqs() async {
    final snap = await _db.collection('faqs').orderBy('sortOrder').get();
    return [
      for (final d in snap.docs)
        if (d.data()['app'] == 'delivery')
          Faq(
            question: d.data()['question'] as String? ?? '',
            answer: d.data()['answer'] as String? ?? '',
          ),
    ];
  }

  @override
  Future<String?> fetchPage(String id) async {
    final data = (await _db.collection('pages').doc(id).get()).data();
    final body = (data?['body'] as String? ?? '').trim();
    return body.isEmpty ? null : body;
  }
}

final helpRepositoryProvider = Provider<HelpRepository>(
  (ref) => Env.useFirebase
      ? FirestoreHelpRepository(FirebaseFirestore.instance)
      : FakeHelpRepository(),
);

final faqsProvider = FutureProvider.autoDispose<List<Faq>>(
  (ref) => ref.watch(helpRepositoryProvider).fetchFaqs(),
);

/// Help: the store's answers to delivery partners' common questions.
class HelpScreen extends ConsumerWidget {
  const HelpScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final faqs = ref.watch(faqsProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Help')),
      body: AsyncValueView(
        value: faqs,
        onRetry: () => ref.invalidate(faqsProvider),
        data: (items) => items.isEmpty
            ? const EmptyState(
                icon: Icons.help_outline_rounded,
                title: 'No questions yet',
                message: 'Answers to common questions will appear here. '
                    'For anything urgent, call the store.',
              )
            : ListView(
                key: const ValueKey('help-list'),
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                children: [
                  const Padding(
                    padding: EdgeInsets.fromLTRB(4, 8, 4, 12),
                    child: Text(
                      'Common questions',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                        color: AppColors.textDark,
                      ),
                    ),
                  ),
                  for (final faq in items)
                    Card(
                      margin: const EdgeInsets.only(bottom: 8),
                      clipBehavior: Clip.antiAlias,
                      child: Theme(
                        // No divider lines inside the rounded card.
                        data: Theme.of(context).copyWith(
                          dividerColor: Colors.transparent,
                        ),
                        child: ExpansionTile(
                          title: Text(
                            faq.question,
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          childrenPadding:
                              const EdgeInsets.fromLTRB(16, 0, 16, 16),
                          expandedAlignment: Alignment.centerLeft,
                          children: [
                            Text(
                              faq.answer,
                              style: const TextStyle(
                                fontSize: 14,
                                height: 1.5,
                                color: AppColors.textMuted,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
      ),
    );
  }
}

final legalPageProvider = FutureProvider.autoDispose.family<String?, String>(
  (ref, id) => ref.watch(helpRepositoryProvider).fetchPage(id),
);

/// The delivery partner terms or privacy policy, exactly as the admin
/// wrote it.
class LegalScreen extends ConsumerWidget {
  const LegalScreen({super.key, required this.pageId});

  final String pageId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final page = ref.watch(legalPageProvider(pageId));
    return Scaffold(
      appBar: AppBar(title: Text(LegalPages.titleOf(pageId))),
      body: AsyncValueView(
        value: page,
        onRetry: () => ref.invalidate(legalPageProvider(pageId)),
        data: (body) => body == null
            ? const EmptyState(
                icon: Icons.description_outlined,
                title: 'Not available yet',
                message: 'The store has not published this page.',
              )
            : SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
                child: SelectableText(
                  body,
                  key: const ValueKey('legal-body'),
                  style: const TextStyle(
                    fontSize: 14,
                    height: 1.6,
                    color: AppColors.textDark,
                  ),
                ),
              ),
      ),
    );
  }
}
