import 'package:sembast_web/sembast_web.dart';

Future<Database> openPulseNotesDatabase() {
  return databaseFactoryWeb.openDatabase('pulsenotes.db');
}
