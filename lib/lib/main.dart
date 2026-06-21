import 'package:flutter/material.dart';

import 'app/app_controllers.dart';
import 'composants/composants.dart';
import 'controller/controllers.dart';
import 'repository/repositories.dart';
import 'theme/fts_theme.dart';
import 'views/accueil_view.dart';
import 'views/envoi_view.dart';
import 'views/historique_view.dart';
import 'views/reception_view.dart';
import 'views/scan_view.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  // Les controllers (pairing / transfert / export ZIP) sont créés ici et
  // partagés à tout l'arbre via FtsControllers.of(context).
  runApp(const FtsControllersProvider(child: FtsApp()));
}

class FtsApp extends StatelessWidget {
  const FtsApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'FTS — File Transfer Suite',
      debugShowCheckedModeBanner: false,
      theme: FtsTheme.light,
      // FtsToastHost enveloppe toute l'app pour permettre l'affichage
      // de toasts depuis n'importe quelle vue via FtsToastHost.of(context).
      builder: (context, child) => FtsToastHost(child: child!),
      home: const FtsShell(),
    );
  }
}

/// Coquille principale : topbar fixe, contenu des onglets,
/// barre de navigation basse avec FAB de scan.
class FtsShell extends StatefulWidget {
  const FtsShell({super.key});

  @override
  State<FtsShell> createState() => _FtsShellState();
}

class _FtsShellState extends State<FtsShell> {
  FtsNavTab _tab = FtsNavTab.accueil;

  PairingController? _pairing;
  TransferController? _transfer;
  bool _wasPaired = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Abonnement au PairingController pour rafraîchir la liste des fichiers
    // dès qu'un appairage réussit (premier chargement via GET /api/files ;
    // ensuite les mises à jour arrivent en temps réel par WebSocket).
    final c = FtsControllers.of(context);
    _transfer = c.transfer;
    if (!identical(c.pairing, _pairing)) {
      _pairing?.removeListener(_onPairingChanged);
      _pairing = c.pairing..addListener(_onPairingChanged);
      _wasPaired = c.pairing.isPaired;
    }
  }

  void _onPairingChanged() {
    final pairing = _pairing;
    if (pairing == null || !mounted) return;
    final pairedNow = pairing.isPaired;
    if (pairedNow && !_wasPaired) {
      _transfer?.refreshFiles();
    }
    _wasPaired = pairedNow;
    setState(() {}); // met à jour l'indicateur « Connecté » de la topbar
  }

  @override
  void dispose() {
    _pairing?.removeListener(_onPairingChanged);
    super.dispose();
  }

  void _goTo(FtsNavTab tab) => setState(() => _tab = tab);

  void _openScan() {
    Navigator.of(context).push(
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (_) => ScanView(
          onClose: () => Navigator.of(context).pop(),
          onPaired: () {
            // Une fois connecté, on bascule sur l'onglet Réception.
            Navigator.of(context).pop();
            _goTo(FtsNavTab.reception);
          },
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final pairing = FtsControllers.of(context).pairing;
    final connected = pairing.isPaired &&
        pairing.realtimeStatus != RealtimeConnectionState.error;

    return Scaffold(
      backgroundColor: FtsColors.blue050,
      appBar: FtsTopbar(connected: connected),
      body: IndexedStack(
        index: _tab.index,
        children: [
          AccueilView(
            onNavigateToSend: () => _goTo(FtsNavTab.envoi),
            onNavigateToReceive: () => _goTo(FtsNavTab.reception),
            onNavigateToScan: _openScan,
            onNavigateToHistory: () => _goTo(FtsNavTab.historique),
          ),
          const EnvoiView(),
          ReceptionView(onOpenScan: _openScan),
          const HistoriqueView(),
        ],
      ),
      bottomNavigationBar: FtsBottomNav(
        current: _tab,
        onTabSelected: _goTo,
        onScanTap: _openScan,
      ),
    );
  }
}
