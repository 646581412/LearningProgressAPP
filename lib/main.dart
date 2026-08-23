import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:provider/provider.dart';
import 'providers/app_provider.dart';
import 'pages/lock_screen_page.dart';
import 'services/notification_service.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  NotificationService.instance.init();
  runApp(const StudyProgressApp());
}

class StudyProgressApp extends StatelessWidget {
  const StudyProgressApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => AppProvider()..init(),
      child: Consumer<AppProvider>(
        builder: (context, provider, _) {
          return MaterialApp(
            title: '学习进度',
            debugShowCheckedModeBanner: false,
            localizationsDelegates: const [
              GlobalMaterialLocalizations.delegate,
              GlobalWidgetsLocalizations.delegate,
              GlobalCupertinoLocalizations.delegate,
            ],
            supportedLocales: const [
              Locale('zh', 'CN'),
              Locale('zh', 'TW'),
            ],
            locale: const Locale('zh', 'CN'),
            theme: ThemeData(
              useMaterial3: true,
              colorScheme: provider.lightColorScheme,
              appBarTheme: AppBarTheme(
                centerTitle: false,
                backgroundColor: provider.lightColorScheme.surface,
                foregroundColor: provider.lightColorScheme.onSurface,
                elevation: 0,
                scrolledUnderElevation: 2,
              ),
              cardTheme: CardThemeData(
                elevation: 1,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
              inputDecorationTheme: InputDecorationTheme(
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                filled: true,
              ),
              floatingActionButtonTheme: FloatingActionButtonThemeData(
                elevation: 3,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
              navigationDrawerTheme: NavigationDrawerThemeData(
                indicatorShape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(28),
                ),
              ),
            ),
            darkTheme: ThemeData(
              useMaterial3: true,
              colorScheme: provider.darkColorScheme,
              appBarTheme: AppBarTheme(
                centerTitle: false,
                backgroundColor: provider.darkColorScheme.surface,
                foregroundColor: provider.darkColorScheme.onSurface,
                elevation: 0,
                scrolledUnderElevation: 2,
              ),
              cardTheme: CardThemeData(
                elevation: 1,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
              inputDecorationTheme: InputDecorationTheme(
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                filled: true,
              ),
              floatingActionButtonTheme: FloatingActionButtonThemeData(
                elevation: 3,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
            ),
            themeMode: provider.themeMode,
            home: const LockScreenPage(),
          );
        },
      ),
    );
  }
}
