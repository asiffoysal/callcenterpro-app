import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'theme/app_theme.dart';
import 'theme/theme_controller.dart';
import 'core/api_client.dart';
import 'core/agent_store.dart';
import 'core/session.dart';
import 'core/server_config.dart';
import 'calling/sip_service.dart';
import 'realtime/realtime_client.dart';
import 'shell/home_shell.dart';
import 'screens/connect_screen.dart';

/// Shown on the sign-in screen when the app was sent back there.
String? gateNotice;

final GlobalKey<NavigatorState> navKey = GlobalKey<NavigatorState>();

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final theme = ThemeController();
  await theme.loadCached();      // instant brand colour, no flash
  await ServerConfig.load();     // which server this app is set to
  runApp(CallCenterProApp(theme: theme));
}

class CallCenterProApp extends StatelessWidget {
  const CallCenterProApp({super.key, required this.theme});
  final ThemeController theme;

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: theme),
        ChangeNotifierProvider(create: (_) => SipService()),
      ],
      child: Consumer<ThemeController>(
        builder: (context, tc, _) {
          final b = tc.theme;
          return MaterialApp(
            title: 'CallCenter Pro',
            navigatorKey: navKey,
            debugShowCheckedModeBanner: false,
            theme: b.light(),
            darkTheme: b.dark(),
            themeMode: b.themeMode,
            home: const Gate(),
          );
        },
      ),
    );
  }
}

/// Decides the first screen: Connect (no server saved) or Login.
class Gate extends StatefulWidget {
  const Gate({super.key});
  @override
  State<Gate> createState() => _GateState();
}

class _GateState extends State<Gate> {
  @override
  Widget build(BuildContext context) {
    if (!ServerConfig.isSet) {
      return ConnectScreen(onConnected: () => setState(() {}));
    }
    return LoginScreen(
      theme: context.read<ThemeController>(),
      onChangeServer: () async {
        await ServerConfig.clear();
        setState(() {});
      },
    );
  }
}

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key, required this.theme, required this.onChangeServer});
  final ThemeController theme;
  final VoidCallback onChangeServer;
  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final company = TextEditingController(text: 'Acme Telecom');
  final ext = TextEditingController();
  final pass = TextEditingController();
  String? error = gateNotice;
  bool busy = false;

  Future<void> _signIn() async {
    gateNotice = null;
    setState(() { busy = true; error = null; });
    try {
      final api = ApiClient(ServerConfig.baseUrl!);
      final res = await api.login(
        company: company.text.trim(),
        extension: ext.text.trim(),
        password: pass.text,
      );
      await widget.theme.apply(BrandTheme.fromJson(
          (res['theme'] as Map).cast<String, dynamic>()));
      final rt = RealtimeClient(hubUrl: ServerConfig.hubUrl, token: res['token'] as String);
      rt.on('theme.update', widget.theme.onRealtimeThemeUpdate);
      rt.connect();
      // Register the extension to the call engine so the app can make/receive calls.
      await Permission.microphone.request();
      final sip = context.read<SipService>();
      final host = Uri.parse(ServerConfig.baseUrl!).host;
      await sip.start(
        host: host,
        sipUser: res['sip_username'] as String? ?? '',
        password: res['sip_password'] as String? ?? '',
        displayName: res['extension'] as String?,
      );
      if (!mounted) return;
      final session = AppSession.fromLogin(res);
      AgentStore? store;
      void signOut() {
        gateNotice = 'You were signed out: ${store?.lastError ?? 'session ended'}. Please sign in again.';
        sip.stop();
        rt.close();
        navKey.currentState?.pushAndRemoveUntil(
            MaterialPageRoute(builder: (_) => const Gate()), (r) => false);
      }
      Navigator.of(context).pushReplacement(MaterialPageRoute(
        builder: (_) => ChangeNotifierProvider<AgentStore>(
          create: (_) => store = AgentStore(api, session,
              onSessionExpired: signOut,
              onTheme: (t) => widget.theme.apply(BrandTheme.fromJson(t)))
            ..start(),
          child: _StoreScope(child: HomeShell(session: session, onSignOut: signOut)),
        ),
      ));
    } on ApiError catch (e) {
      gateNotice = null;
      setState(() => error = e.message);
    } catch (_) {
      setState(() => error = 'Could not reach the server. Check the address.');
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
            CircleAvatar(radius: 28, backgroundColor: cs.primary,
                child: const Icon(Icons.phone_in_talk, color: Colors.white)),
            const SizedBox(height: 14),
            const Text('CallCenter Pro',
                style: TextStyle(fontSize: 26, fontWeight: FontWeight.w800)),
            const SizedBox(height: 4),
            Text(ServerConfig.baseUrl ?? '', style: TextStyle(color: cs.outline, fontSize: 12)),
            const SizedBox(height: 24),
            if (error != null)
              Padding(padding: const EdgeInsets.only(bottom: 12),
                  child: Text(error!, style: const TextStyle(color: Color(0xFFB91C1C)))),
            TextField(controller: company, decoration: const InputDecoration(labelText: 'Company name')),
            const SizedBox(height: 12),
            TextField(controller: ext, keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'Extension')),
            const SizedBox(height: 12),
            TextField(controller: pass, obscureText: true,
                decoration: const InputDecoration(labelText: 'Password')),
            const SizedBox(height: 20),
            FilledButton(onPressed: busy ? null : _signIn,
                child: Text(busy ? 'Signing in…' : 'Sign in')),
            const SizedBox(height: 8),
            TextButton(onPressed: widget.onChangeServer, child: const Text('Change server')),
          ]),
        ),
      ),
    );
  }
}


/// Stops presence heartbeats and marks the agent offline when the signed-in
/// area is torn down (sign out or session expiry).
class _StoreScope extends StatefulWidget {
  const _StoreScope({required this.child});
  final Widget child;
  @override
  State<_StoreScope> createState() => _StoreScopeState();
}

class _StoreScopeState extends State<_StoreScope> {
  late final AgentStore _store;
  @override
  void initState() {
    super.initState();
    _store = context.read<AgentStore>();
  }

  @override
  void dispose() {
    _store.stop();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
