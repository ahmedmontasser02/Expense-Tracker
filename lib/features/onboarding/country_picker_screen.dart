import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/countries.dart';
import '../../core/format.dart';
import '../../providers/providers.dart';

/// Searchable country list. On selection the country + derived currency are
/// persisted and [onSelected] fires (used to close sheets / show feedback).
class CountryPickerScreen extends ConsumerStatefulWidget {
  const CountryPickerScreen({super.key, this.onSelected});

  final ValueChanged<CountryCurrency>? onSelected;

  @override
  ConsumerState<CountryPickerScreen> createState() =>
      _CountryPickerScreenState();
}

class _CountryPickerScreenState extends ConsumerState<CountryPickerScreen> {
  String _query = '';

  Future<void> _choose(CountryCurrency c) async {
    await ref.read(settingsRepoProvider).applyCountry(c);
    MoneyFmt.symbol = c.symbol;
    widget.onSelected?.call(c);
  }

  @override
  Widget build(BuildContext context) {
    final results = searchCountries(_query);
    return Scaffold(
      appBar: AppBar(title: const Text('Choose your country')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
            child: TextField(
              autofocus: true,
              onChanged: (v) => setState(() => _query = v),
              decoration: InputDecoration(
                hintText: 'Search country or currency…',
                prefixIcon: const Icon(Icons.search),
                isDense: true,
                border:
                    OutlineInputBorder(borderRadius: BorderRadius.circular(24)),
              ),
            ),
          ),
          Expanded(
            child: results.isEmpty
                ? Center(
                    child: Text('No match for "$_query"',
                        style: Theme.of(context).textTheme.bodyMedium))
                : ListView.builder(
                    itemCount: results.length,
                    itemBuilder: (context, i) {
                      final c = results[i];
                      return ListTile(
                        leading:
                            Text(c.flag, style: const TextStyle(fontSize: 26)),
                        title: Text(c.name),
                        subtitle: Text(c.currencyCode,
                            style:
                                Theme.of(context).textTheme.bodySmall),
                        trailing: Text(c.symbol,
                            style: Theme.of(context)
                                .textTheme
                                .titleMedium
                                ?.copyWith(fontWeight: FontWeight.bold)),
                        onTap: () => _choose(c),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

/// First-run gate content shown until a country has been chosen.
class OnboardingScreen extends ConsumerWidget {
  const OnboardingScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            const SizedBox(height: 48),
            Icon(Icons.account_balance_wallet_outlined,
                size: 72, color: Theme.of(context).colorScheme.primary),
            const SizedBox(height: 12),
            Text('Welcome to Expense Tracker',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32),
              child: Text(
                'Pick your country so amounts use the right currency. '
                'You can change it later in Settings.',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            ),
            const SizedBox(height: 24),
            Expanded(child: _EmbeddedCountryList()),
          ],
        ),
      ),
    );
  }
}

/// Non-navigating variant of the picker list for embedding on onboarding.
class _EmbeddedCountryList extends ConsumerStatefulWidget {
  @override
  ConsumerState<_EmbeddedCountryList> createState() =>
      _EmbeddedCountryListState();
}

class _EmbeddedCountryListState extends ConsumerState<_EmbeddedCountryList> {
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final results = searchCountries(_query);
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
          child: TextField(
            onChanged: (v) => setState(() => _query = v),
            decoration: InputDecoration(
              hintText: 'Search country or currency…',
              prefixIcon: const Icon(Icons.search),
              isDense: true,
              border:
                  OutlineInputBorder(borderRadius: BorderRadius.circular(24)),
            ),
          ),
        ),
        Expanded(
          child: ListView.builder(
            itemCount: results.length,
            itemBuilder: (context, i) {
              final c = results[i];
              return ListTile(
                leading: Text(c.flag, style: const TextStyle(fontSize: 26)),
                title: Text(c.name),
                trailing: Text(c.currencyCode,
                    style: const TextStyle(fontWeight: FontWeight.w600)),
                onTap: () async {
                  await ref.read(settingsRepoProvider).applyCountry(c);
                  MoneyFmt.symbol = c.symbol;
                },
              );
            },
          ),
        ),
        Padding(
          padding: const EdgeInsets.only(bottom: 16),
          child: TextButton(
            onPressed: () async {
              await ref.read(settingsRepoProvider).applyCountry(findCountry('US')!);
              MoneyFmt.symbol = r'$';
            },
            child: const Text('Skip — use USD (\$)'),
          ),
        ),
      ],
    );
  }
}
