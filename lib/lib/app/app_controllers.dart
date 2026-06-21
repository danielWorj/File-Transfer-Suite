/// app/app_controllers.dart
///
/// Fournit les controllers partagés (`PairingController`,
/// `TransferController`, `BundleController`) à tout l'arbre de widgets, sur
/// le même principe que `FtsToastHost.of(context)` déjà utilisé dans l'app.
///
/// - `FtsControllersProvider` crée, possède et libère les controllers.
/// - `FtsControllers.of(context)` permet à n'importe quelle vue (y compris
///   `ScanView`, poussée via `Navigator`) d'y accéder sans les recevoir en
///   paramètre de constructeur.
///
/// Câblage (voir `main.dart`) :
/// ```dart
/// runApp(const FtsControllersProvider(child: FtsApp()));
/// // puis, n'importe où :
/// final c = FtsControllers.of(context);
/// c.transfer.refreshFiles();
/// ```
library;

import 'package:flutter/widgets.dart';

import '../controller/bundle_controller.dart';
import '../controller/controllers.dart';

/// Accès aux controllers partagés. Les références étant stables pendant
/// toute la vie de l'app, `updateShouldNotify` renvoie `false` : les vues
/// écoutent les changements via leurs propres `ListenableBuilder`.
class FtsControllers extends InheritedWidget {
  const FtsControllers({
    super.key,
    required this.pairing,
    required this.transfer,
    required this.bundle,
    required super.child,
  });

  final PairingController pairing;
  final TransferController transfer;
  final BundleController bundle;

  static FtsControllers of(BuildContext context) {
    final widget =
        context.dependOnInheritedWidgetOfExactType<FtsControllers>();
    assert(
      widget != null,
      'FtsControllers introuvable. Enveloppez l\'app dans FtsControllersProvider.',
    );
    return widget!;
  }

  @override
  bool updateShouldNotify(FtsControllers oldWidget) => false;
}

/// Crée et possède les controllers, les met à disposition via
/// [FtsControllers], et les libère proprement à la destruction.
class FtsControllersProvider extends StatefulWidget {
  const FtsControllersProvider({super.key, required this.child});

  final Widget child;

  @override
  State<FtsControllersProvider> createState() => _FtsControllersProviderState();
}

class _FtsControllersProviderState extends State<FtsControllersProvider> {
  late final PairingController _pairing = PairingController();
  late final TransferController _transfer =
      TransferController(repository: _pairing.repository);
  late final BundleController _bundle = BundleController(transfer: _transfer);

  @override
  void dispose() {
    // Ordre inverse de la création. PairingController.dispose() libère le
    // repository partagé ; on dispose donc TransferController avant lui.
    _bundle.dispose();
    _transfer.dispose();
    _pairing.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FtsControllers(
      pairing: _pairing,
      transfer: _transfer,
      bundle: _bundle,
      child: widget.child,
    );
  }
}
