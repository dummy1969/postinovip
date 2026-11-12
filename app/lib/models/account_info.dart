/// Una casella come la vede il core (GET /accounts). Mai la password.
class AccountInfo {
  const AccountInfo({
    required this.id,
    required this.name,
    required this.address,
    this.configured = true,
    this.online = true,
    this.isPop3 = false,
    this.needsLogin = false,
    this.cardDav = false,
    this.calDav = false,
  });

  final String id;

  /// Nome scelto dall'utente; il core restituisce l'indirizzo se non c'è.
  final String name;
  final String address;
  final bool configured;

  /// false se il server della casella non è raggiungibile: il core mostra la copia locale.
  final bool online;

  /// Account POP3 (4.2): mail solo sul computer, niente "Cerca anche sul server" né "Ricostruisci cache".
  final bool isPop3;

  /// OAuth2 (2a): il fornitore ha rifiutato il token di rinnovo (scaduto o revocato), serve «Accedi di nuovo».
  final bool needsLogin;

  /// Rubrica sincronizzata con un server CardDAV (C4c): Invia/ricevi la sincronizza anche.
  final bool cardDav;

  /// Calendari sincronizzati con un server CalDAV (K3): Invia/ricevi li sincronizza anche.
  final bool calDav;

  factory AccountInfo.fromJson(Map<String, dynamic> json) => AccountInfo(
    id: json['id'] as String,
    name: json['name'] as String,
    address: json['address'] as String,
    configured: json['configured'] as bool? ?? true,
    online: json['online'] as bool? ?? true,
    isPop3: json['type'] == 'Pop3',
    needsLogin: json['needsLogin'] as bool? ?? false,
    cardDav: json['cardDav'] as bool? ?? false,
    calDav: json['calDav'] as bool? ?? false,
  );
}
