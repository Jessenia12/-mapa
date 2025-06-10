import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../database/driver_dao.dart';

class QRScannerScreen extends StatefulWidget {
  const QRScannerScreen({Key? key}) : super(key: key);

  @override
  State<QRScannerScreen> createState() => _QRScannerScreenState();
}

class _QRScannerScreenState extends State<QRScannerScreen> {
  late MobileScannerController controller;
  bool scanned = false;
  bool isProcessing = false;
  bool flashOn = false;

  @override
  void initState() {
    super.initState();
    controller = MobileScannerController();
  }

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  void _onDetect(BarcodeCapture capture) async {
    if (scanned || isProcessing) return;
    
    final List<Barcode> barcodes = capture.barcodes;
    if (barcodes.isEmpty) return;

    setState(() {
      isProcessing = true;
    });

    await _processScanData(barcodes.first);
  }

  Future<void> _processScanData(Barcode barcode) async {
    try {
      String scannedCode = barcode.rawValue ?? "";
      
      // Validar que el código no esté vacío
      if (scannedCode.isEmpty) {
        _showError("Código QR inválido");
        return;
      }

      // Si el código tiene el formato "DRIVER:xxxxx", extraer solo el código
      String driverCode = scannedCode;
      if (scannedCode.startsWith('DRIVER:')) {
        driverCode = scannedCode.substring(7); // Remover "DRIVER:"
      }

      // Buscar el conductor por código
      DriverDao driverDao = DriverDao();
      Map<String, dynamic>? driverData = await driverDao.getDriverByCode(driverCode);

      if (driverData != null) {
        // Extraer datos del Map
        String driverName = driverData['name'] ?? 'Sin nombre';
        String plateNumber = driverData['plate_number'] ?? 'Sin placa';
        
        // Vincular el conductor
        SharedPreferences prefs = await SharedPreferences.getInstance();
        await prefs.setString('linked_driver_code', driverCode);
        await prefs.setString('linked_driver_name', driverName);
        await prefs.setString('linked_driver_plate', plateNumber);

        _showSuccess("Conductor vinculado: $driverName ($plateNumber)");
        
        // Cerrar la pantalla después de un breve retraso
        await Future.delayed(const Duration(milliseconds: 1500));
        if (mounted) {
          Navigator.pop(context, driverData); // Devolver los datos del conductor
        }
      } else {
        _showError("Conductor no encontrado con código: $driverCode");
      }
    } catch (e) {
      print('Error processing scan data: $e');
      _showError("Error procesando código QR: $e");
    } finally {
      if (mounted) {
        setState(() {
          isProcessing = false;
          scanned = false; // Permitir escanear de nuevo si hubo error
        });
      }
    }
  }

  void _showSuccess(String message) {
    if (mounted) {
      setState(() {
        scanned = true;
      });
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: Colors.green,
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  void _showError(String message) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 3),
        ),
      );
    }
  }

  void _resetScanner() {
    setState(() {
      scanned = false;
      isProcessing = false;
    });
  }

  void _toggleFlash() async {
    setState(() {
      flashOn = !flashOn;
    });
    await controller.toggleTorch();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Escanear QR del Conductor'),
        backgroundColor: Colors.blue.shade800,
        foregroundColor: Colors.white,
        actions: [
          if (scanned || isProcessing)
            IconButton(
              icon: const Icon(Icons.refresh),
              onPressed: _resetScanner,
              tooltip: 'Escanear de nuevo',
            ),
        ],
      ),
      body: Stack(
        children: [
          // Vista del escáner QR
          MobileScanner(
            controller: controller,
            onDetect: _onDetect,
            overlay: Container(
              decoration: BoxDecoration(
                border: Border.all(
                  color: scanned ? Colors.green : Colors.blue,
                  width: 4,
                ),
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
          
          // Marco de escaneo personalizado
          Center(
            child: Container(
              width: 250,
              height: 250,
              decoration: BoxDecoration(
                border: Border.all(
                  color: scanned ? Colors.green : Colors.blue,
                  width: 4,
                ),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Stack(
                children: [
                  // Esquinas del marco
                  Positioned(
                    top: -2,
                    left: -2,
                    child: Container(
                      width: 30,
                      height: 30,
                      decoration: BoxDecoration(
                        border: Border(
                          top: BorderSide(color: scanned ? Colors.green : Colors.blue, width: 6),
                          left: BorderSide(color: scanned ? Colors.green : Colors.blue, width: 6),
                        ),
                      ),
                    ),
                  ),
                  Positioned(
                    top: -2,
                    right: -2,
                    child: Container(
                      width: 30,
                      height: 30,
                      decoration: BoxDecoration(
                        border: Border(
                          top: BorderSide(color: scanned ? Colors.green : Colors.blue, width: 6),
                          right: BorderSide(color: scanned ? Colors.green : Colors.blue, width: 6),
                        ),
                      ),
                    ),
                  ),
                  Positioned(
                    bottom: -2,
                    left: -2,
                    child: Container(
                      width: 30,
                      height: 30,
                      decoration: BoxDecoration(
                        border: Border(
                          bottom: BorderSide(color: scanned ? Colors.green : Colors.blue, width: 6),
                          left: BorderSide(color: scanned ? Colors.green : Colors.blue, width: 6),
                        ),
                      ),
                    ),
                  ),
                  Positioned(
                    bottom: -2,
                    right: -2,
                    child: Container(
                      width: 30,
                      height: 30,
                      decoration: BoxDecoration(
                        border: Border(
                          bottom: BorderSide(color: scanned ? Colors.green : Colors.blue, width: 6),
                          right: BorderSide(color: scanned ? Colors.green : Colors.blue, width: 6),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          
          // Instrucciones en la parte superior
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.7),
                borderRadius: const BorderRadius.only(
                  bottomLeft: Radius.circular(12),
                  bottomRight: Radius.circular(12),
                ),
              ),
              child: Column(
                children: [
                  const Text(
                    'Apunta la cámara al código QR',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'El código se escaneará automáticamente',
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.8),
                      fontSize: 12,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          ),
          
          // Indicador de procesamiento
          if (isProcessing)
            Container(
              color: Colors.black.withOpacity(0.5),
              child: const Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    CircularProgressIndicator(
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                    ),
                    SizedBox(height: 16),
                    Text(
                      'Procesando código QR...',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          
          // Indicador de éxito
          if (scanned && !isProcessing)
            Container(
              color: Colors.green.withOpacity(0.8),
              child: const Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.check_circle,
                      size: 80,
                      color: Colors.white,
                    ),
                    SizedBox(height: 16),
                    Text(
                      '¡Código escaneado exitosamente!',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
      
      // Botones de acción en la parte inferior
      bottomNavigationBar: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 4,
              offset: const Offset(0, -2),
            ),
          ],
        ),
        child: SafeArea(
          child: Row(
            children: [
              // Botón de linterna
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: _toggleFlash,
                  icon: Icon(flashOn ? Icons.flash_off : Icons.flash_on),
                  label: Text(flashOn ? 'Apagar' : 'Linterna'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: flashOn ? Colors.amber.shade600 : Colors.grey.shade600,
                    foregroundColor: Colors.white,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              
              // Botón de reiniciar
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: scanned || isProcessing ? _resetScanner : null,
                  icon: const Icon(Icons.refresh),
                  label: const Text('Reiniciar'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue.shade600,
                    foregroundColor: Colors.white,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}