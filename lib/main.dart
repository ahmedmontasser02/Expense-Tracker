import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:sqlite3/open.dart';
import 'package:sqlcipher_flutter_libs/sqlcipher_flutter_libs.dart';

import 'core/constants.dart';
import 'core/format.dart';
import 'features/widgets/changelog_view.dart';
import 'core/theme.dart';
import 'data/database.dart';
import 'data/repositories/settings_repo.dart';
import 'features/onboarding/country_picker_screen.dart';
import 'features/shell/home_shell.dart';
import 'features/shell/transaction_editor_screen.dart';
import 'providers/providers.dart';
import 'services/diagnostic_logger.dart';
import 'services/encryption_key_manager.dart';
import 'services/notification_service.dart';
import 'services/share_intake.dart';

/// Root navigator key so services (notifications, share intake) can open
/// screens without a BuildContext.
final navigatorKey = GlobalKey<NavigatorState>();

/// Opens the transaction editor prefilled from an external trigger.
void openPrefilledEditor(int? amountMinor, String? note) {
  final context = navigatorKey.currentContext;
  if (context == null) return;
  Navigator.of(context).push(MaterialPageRoute(
    builder: (_) => TransactionEditorScreen(
      prefill: (amountMinor: amountMinor, note: note),
    ),
  ));
}

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

  void _handleNotificationPayload(String payload) {
    if (payload == 'quick_add') {
      openPrefilledEditor(null, null);
    }
  }

  Future<void> _handleSharedText(String text) async {
    final (amount, note) = MoneyFmt.parseSharedTransaction(text);
    openPrefilledEditor(amount, note);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Re-run engines when the user comes back so nothing is missed while
    // the app was backgrounded.
    if (state == AppLifecycleState.resumed) {
      _runEngines(scheduleSummary: false);
      ShareIntake.instance.consumeInitial().then((text) {
        if (text != null) _handleSharedText(text);
      });
    }
  }

  Future<void> _bootstrap() async {
    try {
      await NotificationService.instance.init();
      NotificationService.instance.onPayload = _handleNotificationPayload;
      // Notification tapped while the app was terminated.
      final launch = await NotificationService.instance.launchDetails();
      if (launch?.notificationResponse?.payload != null) {
        final payload = launch!.notificationResponse!.payload!;
        Future.delayed(const Duration(milliseconds: 600), () {
          if (mounted) _handleNotificationPayload(payload);
        });
      }
    } catch (e) {
      debugPrint('notification init unavailable: $e');
    }

    // Share-to-log intake.
    ShareIntake.instance.listen();
    ShareIntake.instance.stream.listen(_handleSharedText);
    ShareIntake.instance.consumeInitial().then((text) {
      if (text != null) _handleSharedText(text);
    });

    await _runEngines();
    unawaited(_maybeShowWhatsNew());
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
      title: isDevBuild ? 'Expense Tracker (dev)' : 'Expense Tracker',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      themeMode: themeMode,
      navigatorKey: navigatorKey,
      home: configured.when(
        loading: () => const _Splash(),
        error: (_, _) => const HomeShell(), // fail open on read errors
        data: (ok) => ok ? const HomeShell() : const OnboardingScreen(),
      ),
    );
  }

  /// Shows the changelog once per app version (after country setup).
  Future<void> _maybeShowWhatsNew() async {
    // Wait until onboarding is done.
    final configured = await ref.read(countryConfiguredProvider.future);
    if (!configured) return;

    final settings = ref.read(settingsRepoProvider);
    final info = await PackageInfo.fromPlatform();
    final seen = await settings.getString(SettingsRepo.whatsNewSeenVersion);
    if (seen == info.version) return;
    await settings.set(SettingsRepo.whatsNewSeenVersion, info.version);

    String changelog;
    try {
      changelog = await rootBundle.loadString('assets/CHANGELOG.md');
    } catch (_) {
      return;
    }
    if (!mounted) return;
    final dialogContext = navigatorKey.currentContext;
    if (dialogContext == null || !dialogContext.mounted) return;
    showDialog<void>(
      context: dialogContext,
      builder: (ctx) => AlertDialog(
        icon: const Icon(Icons.celebration_outlined),
        title: Text("What's new in v${info.version}"),
        content: SizedBox(
          width: 360,
          child: SingleChildScrollView(
            child: ChangelogView(
                markdown: changelog, onlyVersion: info.version),
          ),
        ),
        actions: [
          FilledButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Nice!')),
        ],
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





