import 'package:sembast/sembast_memory.dart';

Future<Database> openPulseNotesDatabase() {
  return databaseFactoryMemory.openDatabase('pulsenotes.db');
}
