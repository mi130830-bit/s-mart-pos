// ignore_for_file: avoid_print
import 'package:mysql_client_plus/mysql_client_plus.dart';

void main() async {
  print("Starting Fuel Cost DB Migration...");
  try {
    final conn = await MySQLConnection.createConnection(
      host: '127.0.0.1',
      port: 3306,
      userName: 'admin',
      password: '1234',
      databaseName: 'sorborikan',
    );
    await conn.connect();
    
    try {
      await conn.execute('ALTER TABLE customer ADD COLUMN distanceKm DECIMAL(8,2) DEFAULT 0');
      print("Added distanceKm to customer");
    } catch(e) {
      print("customer distanceKm might already exist: $e");
    }
    
    try {
      await conn.execute('ALTER TABLE delivery_history ADD COLUMN distanceKm DECIMAL(8,2) DEFAULT 0');
      await conn.execute('ALTER TABLE delivery_history ADD COLUMN fuelCostEstimate DECIMAL(10,2) DEFAULT 0');
      print("Added distanceKm and fuelCostEstimate to delivery_history");
    } catch(e) {
      print("delivery_history columns might already exist: $e");
    }
    
    // Add default system settings for fuel
    try {
      await conn.execute('''
        INSERT IGNORE INTO system_settings (setting_key, setting_value) 
        VALUES ('fuel_cost_per_km', '3.0')
      ''');
      print("Inserted default fuel_cost_per_km");
    } catch(e) {
      print("Error inserting system settings: $e");
    }

    await conn.close();
    print("Migration finished.");
  } catch (e) {
    print("DB Connection Error: $e");
  }
}
