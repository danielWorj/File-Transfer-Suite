import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import '../app/app_controllers.dart';
import '../composants/composants.dart';
import '../controller/controllers.dart';
import '../theme/fts_theme.dart';

/// Écran de scan de code QR (plein écran, thème sombre). La caméra lit le
/// QR imprimé par le serveur PC (`print_pairing_qr_code`) ; à la détection,
/// l'appairage est lancé via `PairingController.pairFromScannedUrl`.
class ScanView extends StatefulWidget {
  const ScanView({super.key, required this.onClose, this.onPaired});

  final VoidCallback onClose;

  /// Appelé après un appairage réussi (scan ou saisie manuelle).
  final VoidCallback? onPaired;

  @override
  State<ScanView> createState() => _ScanViewState();
}

class _ScanViewState extends State<ScanView> {
  final MobileScannerController _scanner = MobileScannerController(
    detectionSpeed: DetectionSpeed.noDuplicates,
  );

  bool _flashOn = false;
  bool _handling = false; // évite de traiter plusieurs détections d'affilée

  @override
  void dispose() {
    _scanner.dispose();
    super.dispose();
  }

  Future<void> _onDetect(BarcodeCapture capture) async {
    if (_handling) return;
    final barcodes = capture.barcodes;
    if (barcodes.isEmpty) return;
    final raw = barcodes.first.rawValue;
    if (raw == null || raw.isEmpty) return;

    setState(() => _handling = true);
    await _pair(() =>
        FtsControllers.of(context).pairing.pairFromScannedUrl(raw));
    if (mounted && !FtsControllers.of(context).pairing.isPaired) {
      // Échec : on autorise un nouvel essai après un court délai.
      Future.delayed(const Duration(milliseconds: 1200), () {
        if (mounted) setState(() => _handling = false);
      });
    }
  }

  Future<void> _pair(Future<bool> Function() action) async {
    final pairing = FtsControllers.of(context).pairing;
    final ok = await action();
    if (!mounted) return;
    if (ok) {
      FtsToastHost.of(context)
          ?.show('Appareil connecté avec succès.', type: FtsToastType.success);
      widget.onPaired?.call();
    } else {
      FtsToastHost.of(context)?.show(
        pairing.errorMessage.isNotEmpty
            ? pairing.errorMessage
            : 'Appairage impossible.',
        type: FtsToastType.error,
      );
    }
  }

  Future<void> _toggleFlash() async {
    await _scanner.toggleTorch();
    if (mounted) setState(() => _flashOn = !_flashOn);
  }

  Future<void> _openManualEntry() async {
    final result = await showModalBottomSheet<({String host, String token})>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const _ManualEntrySheet(),
    );
    if (result == null || !mounted) return;
    setState(() => _handling = true);
    await _pair(() => FtsControllers.of(context)
        .pairing
        .pairManually(host: result.host, token: result.token));
    if (mounted && !FtsControllers.of(context).pairing.isPaired) {
      setState(() => _handling = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final topInset = MediaQuery.of(context).padding.top;
    final bottomInset = MediaQuery.of(context).padding.bottom;
    final pairing = FtsControllers.of(context).pairing;

    return Scaffold(
      backgroundColor: const Color(0xFF0B1020),
      body: Column(
        children: [
          // --- Barre supérieure ---
          Padding(
            padding: EdgeInsets.fromLTRB(12, topInset + 10, 12, 10),
            child: Row(
              children: [
                _RoundIconButton(
                  icon: Icons.arrow_back_rounded,
                  onTap: widget.onClose,
                ),
                const Spacer(),
                Text(
                  'Scanner un code',
                  style: GoogleFonts.sora(
                    fontWeight: FontWeight.w600,
                    fontSize: 14.5,
                    color: Colors.white,
                  ),
                ),
                const Spacer(),
                _RoundIconButton(
                  icon: _flashOn
                      ? Icons.flash_on_rounded
                      : Icons.flash_off_rounded,
                  onTap: _toggleFlash,
                ),
              ],
            ),
          ),

          // --- Viseur caméra réel ---
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _ScanFrame(scanner: _scanner, onDetect: _onDetect),
                  const SizedBox(height: 24),
                  Text(
                    'Placez le code QR affiché sur l\'écran de l\'ordinateur '
                    'à l\'intérieur du cadre. L\'adresse du PC est détectée '
                    'automatiquement (même réseau Wi-Fi requis).',
                    textAlign: TextAlign.center,
                    style: GoogleFonts.inter(
                      fontSize: 12.5,
                      height: 1.5,
                      color: Colors.white.withValues(alpha: 0.65),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // --- Panneau inférieur ---
          Container(
            width: double.infinity,
            padding: EdgeInsets.fromLTRB(20, 20, 20, 24 + bottomInset),
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(20),
                topRight: Radius.circular(20),
              ),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    FtsStatusDot(
                      status: pairing.status == PairingStatus.pairing
                          ? FtsStatus.info
                          : FtsStatus.pending,
                      pulse: true,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      pairing.status == PairingStatus.pairing
                          ? 'Appairage en cours…'
                          : 'Recherche d\'un code QR…',
                      style: GoogleFonts.ibmPlexMono(
                        fontSize: 12,
                        color: FtsColors.muted,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                FtsButton(
                  label: 'Saisir le code manuellement',
                  icon: Icons.keyboard_alt_outlined,
                  variant: FtsButtonVariant.outline,
                  expand: true,
                  onPressed: _openManualEntry,
                ),
                const SizedBox(height: 12),
                const Text(
                  'En cas de souci avec la caméra, saisissez juste '
                  'l\'adresse du PC : le jeton de connexion est récupéré '
                  'automatiquement, à condition que les deux appareils '
                  'soient sur le même réseau Wi-Fi.',
                  textAlign: TextAlign.center,
                  style:
                      TextStyle(fontSize: 11, color: FtsColors.muted, height: 1.5),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Feuille de saisie manuelle : adresse du serveur + jeton.
class _ManualEntrySheet extends StatefulWidget {
  const _ManualEntrySheet();

  @override
  State<_ManualEntrySheet> createState() => _ManualEntrySheetState();
}

class _ManualEntrySheetState extends State<_ManualEntrySheet> {
  final _hostController = TextEditingController(text: 'http://');
  final _tokenController = TextEditingController();

  @override
  void dispose() {
    _hostController.dispose();
    _tokenController.dispose();
    super.dispose();
  }

  void _submit() {
    var host = _hostController.text.trim();
    final token = _tokenController.text.trim();
    if (host.isEmpty || host == 'http://') {
      FtsToastHost.of(context)?.show(
        'Renseignez l\'adresse du serveur.',
        type: FtsToastType.warning,
      );
      return;
    }
    if (!host.startsWith('http://') && !host.startsWith('https://')) {
      host = 'http://$host';
    }
    Navigator.of(context).pop((host: host, token: token));
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    return Padding(
      padding: EdgeInsets.only(bottom: bottomInset),
      child: Container(
        padding: const EdgeInsets.fromLTRB(20, 18, 20, 28),
        decoration: const BoxDecoration(
          color: FtsColors.surface,
          borderRadius: BorderRadius.only(
            topLeft: Radius.circular(20),
            topRight: Radius.circular(20),
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: FtsColors.border,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 18),
            Text('Connexion manuelle', style: FtsText.cardTitle),
            const SizedBox(height: 4),
            Text(
              'Saisissez l\'adresse affichée sur l\'ordinateur (PC et '
              'téléphone doivent être sur le même réseau Wi-Fi).',
              style: FtsText.subtitle,
            ),
            const SizedBox(height: 16),
            Text('ADRESSE DU SERVEUR',
                style: FtsText.eyebrow.copyWith(color: FtsColors.muted)),
            const SizedBox(height: 6),
            FtsTextField(
              hint: 'http://10.50.1.158:8443',
              icon: Icons.dns_outlined,
              controller: _hostController,
            ),
            const SizedBox(height: 14),
            Text('JETON (OPTIONNEL)',
                style: FtsText.eyebrow.copyWith(color: FtsColors.muted)),
            const SizedBox(height: 6),
            FtsTextField(
              hint: 'Jeton de pairing',
              icon: Icons.vpn_key_outlined,
              controller: _tokenController,
            ),
            const SizedBox(height: 20),
            FtsButton(
              label: 'Se connecter',
              icon: Icons.login_rounded,
              expand: true,
              onPressed: _submit,
            ),
          ],
        ),
      ),
    );
  }
}

class _RoundIconButton extends StatelessWidget {
  const _RoundIconButton({required this.icon, required this.onTap});

  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white.withValues(alpha: 0.1),
      shape: const CircleBorder(),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: Container(
          width: 38,
          height: 38,
          alignment: Alignment.center,
          child: Icon(icon, size: 18, color: Colors.white),
        ),
      ),
    );
  }
}

/// Cadre de visée contenant l'aperçu caméra (MobileScanner), avec coins
/// lumineux et laser animé décoratif par-dessus.
class _ScanFrame extends StatefulWidget {
  const _ScanFrame({required this.scanner, required this.onDetect});

  final MobileScannerController scanner;
  final void Function(BarcodeCapture) onDetect;

  @override
  State<_ScanFrame> createState() => _ScanFrameState();
}

class _ScanFrameState extends State<_ScanFrame>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 2200),
  )..repeat(reverse: true);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size.width * 0.72;
    final clampedSize = size.clamp(0, 250).toDouble();

    return SizedBox(
      width: clampedSize,
      height: clampedSize,
      child: Stack(
        fit: StackFit.expand,
        children: [
          // Aperçu caméra clippé dans le cadre.
          ClipRRect(
            borderRadius: BorderRadius.circular(18),
            child: MobileScanner(
              controller: widget.scanner,
              onDetect: widget.onDetect,
              fit: BoxFit.cover,
            ),
          ),
          ..._corners(clampedSize),
          AnimatedBuilder(
            animation: _controller,
            builder: (context, child) {
              final top = 8 + (clampedSize - 16) * _controller.value;
              return Positioned(
                left: clampedSize * 0.06,
                right: clampedSize * 0.06,
                top: top,
                child: Container(
                  height: 2,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        FtsColors.blue500.withValues(alpha: 0),
                        FtsColors.blue500,
                        FtsColors.blue500.withValues(alpha: 0),
                      ],
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: FtsColors.blue500.withValues(alpha: 0.7),
                        blurRadius: 8,
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  List<Widget> _corners(double size) {
    const length = 30.0;
    const thickness = 3.0;
    const radius = 14.0;
    final color = FtsColors.blue500;

    BoxDecoration corner({
      required bool top,
      required bool left,
    }) {
      return BoxDecoration(
        border: Border(
          top: top
              ? BorderSide(color: color, width: thickness)
              : BorderSide.none,
          bottom: !top
              ? BorderSide(color: color, width: thickness)
              : BorderSide.none,
          left: left
              ? BorderSide(color: color, width: thickness)
              : BorderSide.none,
          right: !left
              ? BorderSide(color: color, width: thickness)
              : BorderSide.none,
        ),
        borderRadius: BorderRadius.only(
          topLeft: top && left ? const Radius.circular(radius) : Radius.zero,
          topRight: top && !left ? const Radius.circular(radius) : Radius.zero,
          bottomLeft:
              !top && left ? const Radius.circular(radius) : Radius.zero,
          bottomRight:
              !top && !left ? const Radius.circular(radius) : Radius.zero,
        ),
      );
    }

    return [
      Positioned(
          top: 0,
          left: 0,
          child: Container(
              width: length,
              height: length,
              decoration: corner(top: true, left: true))),
      Positioned(
          top: 0,
          right: 0,
          child: Container(
              width: length,
              height: length,
              decoration: corner(top: true, left: false))),
      Positioned(
          bottom: 0,
          left: 0,
          child: Container(
              width: length,
              height: length,
              decoration: corner(top: false, left: true))),
      Positioned(
          bottom: 0,
          right: 0,
          child: Container(
              width: length,
              height: length,
              decoration: corner(top: false, left: false))),
    ];
  }
}
