import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sqlite3/open.dart';
import 'package:sqlcipher_flutter_libs/sqlcipher_flutter_libs.dart';

import 'core/format.dart';
import 'core/theme.dart';
import 'data/database.dart';
import 'data/repositories/settings_repo.dart';
import 'features/onboarding/country_picker_screen.dart';
import 'features/shell/home_shell.dart';
import 'providers/providers.dart';
import 'services/diagnostic_logger.dart';
import 'services/encryption_key_manager.dart';
import 'services/notification_service.dart';

Future<void> main() async {
  await runZonedGuarded<Future<void>>(
    () async {
      WidgetsFlutterBinding.ensureInitialized();

      // Graceful failure: capture errors to diagnostics, log them, and
      // never show the red error screen — render a friendly view instead.
      FlutterError.onError = (details) {
        FlutterError.presentError(details);
        DiagnosticLogger.instance
            .record('flutter', details.exception, details.stack);
      };
      PlatformDispatcher.instance.onError = (error, stack) {
        DiagnosticLogger.instance.record('platform', error, stack);
        return true;
      };
      ErrorWidget.builder = (details) {
        DiagnosticLogger.instance
            .record('build', details.exception, details.stack);
        return const _GracefulError();
      };

      await DiagnosticLogger.instance.init();

      // SQLCipher: route the sqlite3 package to the bundled cipher library
      // (libsqlcipher.so) before anything touches the database.
      await applyWorkaroundToOpenSqlCipherOnOldAndroidVersions();
      open.overrideFor(OperatingSystem.android, openCipherOnAndroid);

      final encryptionKey = await EncryptionKeyManager.instance.getOrCreate();
      final db = AppDatabase(encryptionKey: encryptionKey);
      runApp(
        ProviderScope(
          overrides: [
            databaseProvider.overrideWithValue(db),
            encryptionKeyProvider.overrideWithValue(encryptionKey),
          ],
          child: const ExpenseTrackerApp(),
        ),
      );
    },
    (error, stack) {
      DiagnosticLogger.instance.record('zone', error, stack);
      debugPrint('Uncaught error: $error');
    },
  );
}

class ExpenseTrackerApp extends ConsumerStatefulWidget {
  const ExpenseTrackerApp({super.key});

  @override
  ConsumerState<ExpenseTrackerApp> createState() => _ExpenseTrackerAppState();
}

class _ExpenseTrackerAppState extends ConsumerState<ExpenseTrackerApp>
    with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _bootstrap();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Re-run engines when the user comes back so nothing is missed while
    // the app was backgrounded.
    if (state == AppLifecycleState.resumed) {
      _runEngines(scheduleSummary: false);
    }
  }

  Future<void> _bootstrap() async {
    try {
      await NotificationService.instance.init();
    } catch (e) {
      debugPrint('notification init unavailable: $e');
    }
    await _runEngines();
  }

  Future<void> _runEngines({bool scheduleSummary = true}) async {
    try {
      // 1. Materialize any due recurring transactions.
      final generated = await ref.read(recurringRepoProvider).processDue();

      // 2. Evaluate alert rules and fire deduped notifications.
      await ref.read(alertServiceProvider).runChecks();

      // 2b. Daily automatic backup when due and enabled.
      await ref.read(backupServiceProvider).autoBackupIfDue();

      // 3. Refresh the daily summary slot if enabled.
      if (scheduleSummary) {
        await _refreshDailySummary();
      }

      if (generated > 0 && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('$generated recurring transaction(s) were added'),
        ));
      }
    } catch (e) {
      debugPrint('engine run failed: $e');
    }
  }

  Future<void> _refreshDailySummary() async {
    final settings = ref.read(settingsRepoProvider);
    if (!await settings.getBool(SettingsRepo.dailySummaryEnabled)) return;
    final hour = await settings.getInt(SettingsRepo.dailySummaryHour);
    final balance = await ref.read(transactionsRepoProvider).currentBalance();
    final pot = await ref.read(transactionsRepoProvider).savingsPot();
    final sym = MoneyFmt.symbol;
    await NotificationService.instance.scheduleDailySummary(
      hour.clamp(0, 23),
      'Daily money check-in',
      'Balance: ${MoneyFmt.withSymbol(sym, balance)} • '
          'Savings: ${MoneyFmt.withSymbol(sym, pot)}',
    );
  }

  @override
  Widget build(BuildContext context) {
    // Keep the static formatter symbol in sync with settings changes
    // (covers first-run country pick and later edits in Settings).
    ref.listen(settingsMapProvider, (_, next) {
      final sym = next.value?[SettingsRepo.currencySymbol];
      if (sym != null && sym.isNotEmpty) MoneyFmt.symbol = sym;
    });

    final configured = ref.watch(countryConfiguredProvider);
    final themeMode =
        ref.watch(themeModeProvider).value ?? ThemeMode.system;

    return MaterialApp(
      title: 'Expense Tracker',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      themeMode: themeMode,
      home: configured.when(
        loading: () => const _Splash(),
        error: (_, _) => const HomeShell(), // fail open on read errors
        data: (ok) => ok ? const HomeShell() : const OnboardingScreen(),
      ),
    );
  }
}

/// Shown instead of the red/grey error screen whenever a widget build fails.
/// Self-sufficient: renders outside MaterialApp, so no Theme/Directionality
/// inherited widgets can be assumed.
class _GracefulError extends StatelessWidget {
  const _GracefulError();

  @override
  Widget build(BuildContext context) {
    final dark = WidgetsBinding
            .instance.platformDispatcher.platformBrightness ==
        Brightness.dark;
    final fg = dark ? const Color(0xFFC9D6D2) : const Color(0xFF33544C);
    final bg = dark ? const Color(0xFF10201C) : const Color(0xFFF4F8F7);
    return Directionality(
      textDirection: TextDirection.ltr,
      child: ColoredBox(
        color: bg,
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.error_outline, size: 56, color: fg),
                const SizedBox(height: 16),
                Text('Something went wrong',
                    style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: fg)),
                const SizedBox(height: 8),
                Text(
                  'This view hit an unexpected problem. '
                  'Please go back and try again.',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 13, color: fg),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Splash extends StatelessWidget {
  const _Splash();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.account_balance_wallet_outlined,
                size: 64, color: Theme.of(context).colorScheme.primary),
            const SizedBox(height: 16),
            const CircularProgressIndicator(),
          ],
        ),
      ),
    );
  }
}


