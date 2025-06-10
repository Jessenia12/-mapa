import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:qr_flutter/qr_flutter.dart'; // Comentado hasta que se agregue la dependencia
import '../models/driver.dart';
import '../database/driver_dao.dart';
import '../providers/gps_provider.dart';
import '../providers/fleet_provider.dart';
import 'map_screen.dart';

class DriverConnectScreen extends StatefulWidget {
  const DriverConnectScreen({Key? key}) : super(key: key);

  @override
  State<DriverConnectScreen> createState() => _DriverConnectScreenState();
}

class _DriverConnectScreenState extends State<DriverConnectScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  final _licenseController = TextEditingController();
  final _codeInputController = TextEditingController();
  final _idNumberController = TextEditingController();
  final _plateNumberController = TextEditingController();

  Driver? _registeredDriver;
  bool _isLoading = false;
  bool _showQRCode = false;

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _licenseController.dispose();
    _codeInputController.dispose();
    _idNumberController.dispose();
    _plateNumberController.dispose();
    super.dispose();
  }

  String _generateDriverCode() {
    // Generar código único de 8 caracteres
    const chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789';
    String code = '';
    final now = DateTime.now().millisecondsSinceEpoch;
    for (int i = 0; i < 8; i++) {
      code += chars[(now + i) % chars.length];
    }
    return code;
  }

  Future<void> _registerDriver() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
    });

    try {
      // Generar código único
      String driverCode;
      bool codeExists = true;
      
      do {
        driverCode = _generateDriverCode();
        codeExists = await DriverDao().driverCodeExists(driverCode);
      } while (codeExists);

      // Crear el driver usando el modelo Driver
      final newDriver = Driver(
        name: _nameController.text.trim(),
        idNumber: _idNumberController.text.trim().isNotEmpty 
            ? _idNumberController.text.trim() 
            : 'N/A',
        plateNumber: _plateNumberController.text.trim().isNotEmpty 
            ? _plateNumberController.text.trim() 
            : 'N/A',
        code: driverCode,
        email: _emailController.text.trim().isNotEmpty 
            ? _emailController.text.trim() 
            : null,
        phone: _phoneController.text.trim().isNotEmpty 
            ? _phoneController.text.trim() 
            : null,
        licenseNumber: _licenseController.text.trim().isNotEmpty 
            ? _licenseController.text.trim() 
            : null,
        isActive: true,
        currentStatus: 'inactive',
        lastConnection: DateTime.now(),
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      // Insertar usando toMap() del modelo Driver
      final driverId = await DriverDao().insertDriver(newDriver.toMap());
      
      // Obtener el driver insertado con el ID correcto
      final savedDriverData = await DriverDao().getDriverById(driverId);
      
      if (savedDriverData != null) {
        setState(() {
          _registeredDriver = Driver.fromMap(savedDriverData);
        });

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text("Conductor registrado correctamente"),
              backgroundColor: Colors.green,
              duration: Duration(seconds: 3),
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Error al registrar conductor: $e"),
            backgroundColor: Colors.red,
            duration: Duration(seconds: 4),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _connectWithCode() async {
    final code = _codeInputController.text.trim();
    if (code.isEmpty) {
      _showSnackBar("Por favor ingresa un código", Colors.orange);
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final driverData = await DriverDao().getDriverByCode(code);

      if (driverData != null) {
        // Crear el objeto Driver usando fromMap
        final driver = Driver.fromMap(driverData);
        
        // Actualizar el estado del conductor a activo
        final updatedDriver = driver.copyWith(
          currentStatus: 'active',
          lastConnection: DateTime.now(),
          isActive: true,
          updatedAt: DateTime.now(),
        );

        // Actualizar en la base de datos
        await DriverDao().updateDriver(updatedDriver.toMap());

        if (mounted) {
          final gpsProvider = Provider.of<GPSProvider>(context, listen: false);
          
          // Establecer el conductor en el GPS Provider
          gpsProvider.setDriver(updatedDriver);
          
          // Iniciar tracking GPS
          try {
            await gpsProvider.startTracking();
          } catch (e) {
            print('Error starting GPS tracking: $e');
            // Continue with navigation even if GPS fails
          }
          
          // Navegar al mapa con el parámetro correcto
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (context) => MapScreen(
                isDriver: true,
                focusDriver: updatedDriver, // Usar focusDriver en lugar de driver
              ),
            ),
          );
        }
      } else {
        _showSnackBar("Código inválido o conductor no encontrado", Colors.red);
      }
    } catch (e) {
      print('Error al conectar conductor: $e');
      _showSnackBar("Error al conectar: $e", Colors.red);
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  void _showSnackBar(String message, Color backgroundColor) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: backgroundColor,
          duration: Duration(seconds: 3),
        ),
      );
    }
  }

  void _copyCodeToClipboard() {
    if (_registeredDriver != null) {
      Clipboard.setData(ClipboardData(text: _registeredDriver!.code));
      _showSnackBar("Código copiado al portapapeles", Colors.green);
    }
  }

  void _clearForm() {
    _nameController.clear();
    _emailController.clear();
    _phoneController.clear();
    _licenseController.clear();
    _idNumberController.clear();
    _plateNumberController.clear();
    setState(() {
      _registeredDriver = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Conectar Conductor'),
        backgroundColor: Colors.blue.shade800,
        foregroundColor: Colors.white,
        elevation: 2,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Sección de registro
            Card(
              elevation: 4,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: Colors.blue.shade100,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Icon(Icons.person_add, color: Colors.blue.shade800),
                        ),
                        const SizedBox(width: 12),
                        const Expanded(
                          child: Text(
                            'Registrar nuevo conductor',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    Form(
                      key: _formKey,
                      child: Column(
                        children: [
                          TextFormField(
                            controller: _nameController,
                            decoration: InputDecoration(
                              labelText: 'Nombre completo',
                              prefixIcon: const Icon(Icons.person),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                              filled: true,
                              fillColor: Colors.grey.shade50,
                            ),
                            textCapitalization: TextCapitalization.words,
                            validator: (value) {
                              if (value == null || value.trim().isEmpty) {
                                return 'El nombre es requerido';
                              }
                              if (value.trim().length < 3) {
                                return 'El nombre debe tener al menos 3 caracteres';
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 16),
                          TextFormField(
                            controller: _idNumberController,
                            decoration: InputDecoration(
                              labelText: 'Número de identificación',
                              prefixIcon: const Icon(Icons.badge),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                              filled: true,
                              fillColor: Colors.grey.shade50,
                            ),
                            validator: (value) {
                              if (value == null || value.trim().isEmpty) {
                                return 'El número de identificación es requerido';
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 16),
                          TextFormField(
                            controller: _plateNumberController,
                            decoration: InputDecoration(
                              labelText: 'Placa del vehículo',
                              prefixIcon: const Icon(Icons.directions_car),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                              filled: true,
                              fillColor: Colors.grey.shade50,
                            ),
                            textCapitalization: TextCapitalization.characters,
                            validator: (value) {
                              if (value == null || value.trim().isEmpty) {
                                return 'La placa del vehículo es requerida';
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 16),
                          TextFormField(
                            controller: _emailController,
                            decoration: InputDecoration(
                              labelText: 'Email (opcional)',
                              prefixIcon: const Icon(Icons.email),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                              filled: true,
                              fillColor: Colors.grey.shade50,
                            ),
                            keyboardType: TextInputType.emailAddress,
                            validator: (value) {
                              if (value != null && value.trim().isNotEmpty) {
                                if (!RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(value.trim())) {
                                  return 'Ingresa un email válido';
                                }
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 16),
                          TextFormField(
                            controller: _phoneController,
                            decoration: InputDecoration(
                              labelText: 'Teléfono (opcional)',
                              prefixIcon: const Icon(Icons.phone),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                              filled: true,
                              fillColor: Colors.grey.shade50,
                            ),
                            keyboardType: TextInputType.phone,
                          ),
                          const SizedBox(height: 16),
                          TextFormField(
                            controller: _licenseController,
                            decoration: InputDecoration(
                              labelText: 'Número de licencia (opcional)',
                              prefixIcon: const Icon(Icons.credit_card),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                              filled: true,
                              fillColor: Colors.grey.shade50,
                            ),
                          ),
                          const SizedBox(height: 20),
                          Row(
                            children: [
                              Expanded(
                                child: ElevatedButton.icon(
                                  onPressed: _isLoading ? null : _registerDriver,
                                  icon: _isLoading
                                      ? const SizedBox(
                                          width: 20,
                                          height: 20,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2,
                                            color: Colors.white,
                                          ),
                                        )
                                      : const Icon(Icons.app_registration),
                                  label: const Text('Registrar conductor'),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.blue.shade800,
                                    foregroundColor: Colors.white,
                                    padding: const EdgeInsets.symmetric(vertical: 14),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                  ),
                                ),
                              ),
                              if (_registeredDriver != null) ...[
                                const SizedBox(width: 12),
                                ElevatedButton.icon(
                                  onPressed: _clearForm,
                                  icon: const Icon(Icons.clear),
                                  label: const Text('Nuevo'),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.grey.shade600,
                                    foregroundColor: Colors.white,
                                    padding: const EdgeInsets.symmetric(vertical: 14),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // Mostrar código generado
            if (_registeredDriver != null) ...[
              const SizedBox(height: 20),
              Card(
                elevation: 4,
                color: Colors.green.shade50,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: Colors.green.shade100,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Icon(Icons.check_circle, color: Colors.green.shade800),
                          ),
                          const SizedBox(width: 12),
                          const Expanded(
                            child: Text(
                              'Conductor registrado exitosamente',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),
                      
                      // Información del conductor
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.grey.shade300),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Nombre: ${_registeredDriver!.name}',
                                style: const TextStyle(fontWeight: FontWeight.w500)),
                            const SizedBox(height: 4),
                            Text('ID: ${_registeredDriver!.idNumber}',
                                style: const TextStyle(fontWeight: FontWeight.w500)),
                            const SizedBox(height: 4),
                            Text('Placa: ${_registeredDriver!.plateNumber}',
                                style: const TextStyle(fontWeight: FontWeight.w500)),
                            const SizedBox(height: 4),
                            if (_registeredDriver!.email != null) ...[
                              Text('Email: ${_registeredDriver!.email}',
                                  style: const TextStyle(fontWeight: FontWeight.w500)),
                              const SizedBox(height: 4),
                            ],
                            if (_registeredDriver!.phone != null) ...[
                              Text('Teléfono: ${_registeredDriver!.phone}',
                                  style: const TextStyle(fontWeight: FontWeight.w500)),
                              const SizedBox(height: 4),
                            ],
                            if (_registeredDriver!.licenseNumber != null) ...[
                              Text('Licencia: ${_registeredDriver!.licenseNumber}',
                                  style: const TextStyle(fontWeight: FontWeight.w500)),
                              const SizedBox(height: 4),
                            ],
                            const Divider(height: 20),
                            const Text('Código del conductor:',
                                style: TextStyle(fontWeight: FontWeight.bold)),
                            const SizedBox(height: 8),
                            Row(
                              children: [
                                Expanded(
                                  child: Container(
                                    padding: const EdgeInsets.all(12),
                                    decoration: BoxDecoration(
                                      color: Colors.grey.shade100,
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: Text(
                                      _registeredDriver!.code,
                                      style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 16,
                                        fontFamily: 'monospace',
                                      ),
                                      textAlign: TextAlign.center,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                IconButton(
                                  onPressed: _copyCodeToClipboard,
                                  icon: const Icon(Icons.copy),
                                  tooltip: 'Copiar código',
                                  style: IconButton.styleFrom(
                                    backgroundColor: Colors.blue.shade100,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      
                      const SizedBox(height: 16),
                      
                      // Sección QR Code (temporal hasta que se agregue la dependencia)
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.grey.shade300),
                        ),
                        child: Column(
                          children: [
                            const Icon(
                              Icons.qr_code,
                              size: 120,
                              color: Colors.grey,
                            ),
                            const SizedBox(height: 8),
                            const Text(
                              'Código QR',
                              style: TextStyle(fontWeight: FontWeight.bold),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Agrega la dependencia qr_flutter\npara mostrar el código QR',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey.shade600,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ],
                        ),
                      ),
                      
                      const SizedBox(height: 12),
                      Text(
                        'Comparte este código con el conductor para que pueda conectarse',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey.shade700,
                          fontStyle: FontStyle.italic,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
              ),
            ],

            const SizedBox(height: 24),
            const Divider(thickness: 2),
            const SizedBox(height: 24),

            // Sección de conexión
            Card(
              elevation: 4,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: Colors.green.shade100,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Icon(Icons.login, color: Colors.green.shade800),
                        ),
                        const SizedBox(width: 12),
                        const Expanded(
                          child: Text(
                            'Conectarse como conductor',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    TextFormField(
                      controller: _codeInputController,
                      decoration: InputDecoration(
                        labelText: 'Código del conductor',
                        prefixIcon: const Icon(Icons.qr_code),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                        filled: true,
                        fillColor: Colors.grey.shade50,
                        hintText: 'Ingresa tu código único',
                      ),
                      textCapitalization: TextCapitalization.characters,
                      onFieldSubmitted: (_) => _connectWithCode(),
                    ),
                    const SizedBox(height: 20),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: _isLoading ? null : _connectWithCode,
                        icon: _isLoading
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : const Icon(Icons.login),
                        label: const Text('Conectarse'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green.shade800,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
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