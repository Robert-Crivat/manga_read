import 'package:connectivity_plus/connectivity_plus.dart';

void main() async {
  print('Test connectivity plugin...');
  
  try {
    final connectivity = Connectivity();
    final result = await connectivity.checkConnectivity();
    
    print('Connectivity check successful: $result');
    
    if (result.isNotEmpty) {
      print('Connection status: ${result.first}');
      print('Is connected: ${result.first != ConnectivityResult.none}');
    } else {
      print('No connectivity result');
    }
    
  } catch (e, stackTrace) {
    print('Connectivity check failed: $e');
    print('Stack trace: $stackTrace');
    print('Plugin potrebbe non essere disponibile sul simulatore');
  }
}