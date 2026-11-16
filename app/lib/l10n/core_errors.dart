/// Testi degli errori del core nella lingua dell'app (tappa «Lingua», L6, scelta 2a).
///
/// Il core manda, oltre al suo testo italiano, un **tipo** (il titolo: «Non connesso», «Non trovato»…) e un **codice** con
/// i suoi valori (il dettaglio). Qui codici e tipi diventano testi tradotti; un codice che l'app non conosce (core più nuovo,
/// errore non ancora convertito) lascia il testo del core.
library;

import 'app_localizations.dart';
import 'core_error_codes.dart';
import 'formats.dart';

/// Titolo per il tipo di errore; null se il tipo non è noto.
String? coreKindText(String? kind, [AppLocalizations? l10n]) {
  final l = l10n ?? formatL10n;
  return switch (kind) {
    'invalidRequest' => l.coreKindInvalidRequest,
    'notFound' => l.coreKindNotFound,
    'offline' => l.coreKindOffline,
    'server' => l.coreKindServer,
    'conflict' => l.coreKindConflict,
    'notSupported' => l.coreKindNotSupported,
    'certificate' => l.coreKindCertificate,
    'oauth' => l.coreKindOAuth,
    'auth' => l.coreKindAuth,
    'config' => l.coreKindConfig,
    'internal' => l.coreKindInternal,
    _ => null,
  };
}

/// Problemi del certificato (codici separati da virgola) nella lingua dell'app, separati da virgola.
String certificateProblemsText(String codes, String host, [AppLocalizations? l10n]) =>
    [for (final c in codes.split(',')) if (c.isNotEmpty) certificateProblemText(c, host, l10n) ?? c].join(', ');

String? certificateProblemText(String code, String host, [AppLocalizations? l10n]) {
  final l = l10n ?? formatL10n;
  return switch (code) {
    'nameMismatch' => l.certNameMismatch(host),
    'untrustedRoot' => l.certUntrustedRoot,
    'notTimeValid' => l.certNotTimeValid,
    'revoked' => l.certRevoked,
    'chainInvalid' => l.certChainInvalid,
    'noCertificate' => l.certNoCertificate,
    _ => null,
  };
}

/// Testo per il codice [code] con i valori [args]; [fallback] (il testo del core) se il codice non è noto.
String? coreErrorText(String? code, Map<String, String> args, String? fallback, [AppLocalizations? l10n]) {
  final l = l10n ?? formatL10n;
  // I nomi dei server DAV arrivano dal core in italiano: nella lingua dell'app.
  String a(String name) => switch (args[name] ?? '') {
    'server dei contatti' => l.davContactsServerLabel,
    'server del calendario' => l.davCalendarServerLabel,
    final v => v,
  };
  String problems() => certificateProblemsText(a('problems'), a('host'), l);
  final text = switch (code) {
    'timeout' => l.coreTimeout,
    'authCheckCredentials' => l.coreAuthCheckCredentials,
    'internalUnexpected' => l.coreInternalUnexpected,
    'certificateChanged' => l.coreCertificateChanged(a('address'), problems()),
    'testCertificateInvalid' => l.coreTestCertificateInvalid(a('address'), problems()),
    'testNoStartTls' => l.coreTestNoStartTls(a('address')),
    'testAuthRejected' => l.coreTestAuthRejected,
    'testTlsFailed' => l.coreTestTlsFailed(a('address')),
    'testUnreachable' => l.coreTestUnreachable(a('address')),
    'testNoAnswer' => l.coreTestNoAnswer(a('address'), a('seconds')),
    'testUnexpectedAnswer' => l.coreTestUnexpectedAnswer(a('address')),
    'pop3NoUidl' => l.corePop3NoUidl(a('address')),
    'oauthServerUnreachable' => l.coreOAuthServerUnreachable(a('provider')),
    'oauthInvalidResponse' => l.coreOAuthInvalidResponse(a('provider'), a('status')),
    'oauthExpired' => l.coreOAuthExpired(a('provider')),
    'oauthClientInvalid' => l.coreOAuthClientInvalid(a('provider')),
    'oauthFailed' => l.coreOAuthFailed(a('provider'), a('error')),
    'oauthCancelled' => l.coreOAuthCancelled,
    'oauthNoCode' => l.coreOAuthNoCode,
    'oauthFlowFailed' => l.coreOAuthFlowFailed(a('error')),
    'oauthNoRefreshToken' => l.coreOAuthNoRefreshToken,
    'serverUnreachable' => l.coreServerUnreachable(a('reason')),
    'pop3NoAnswer' => l.corePop3NoAnswer(a('address')),
    'pop3Unreachable' => l.corePop3Unreachable(a('address'), a('reason')),
    'smtpNoAnswer' => l.coreSmtpNoAnswer(a('seconds')),
    'smtpUnreachable' => l.coreSmtpUnreachable(a('reason')),
    'contactsServerUnreachable' => l.coreContactsServerUnreachable,
    'calendarServerUnreachable' => l.coreCalendarServerUnreachable,
    'contactsServerNoAnswer' => l.coreContactsServerNoAnswer,
    'calendarServerNoAnswer' => l.coreCalendarServerNoAnswer,
    'davSignInRejectedContacts' => l.coreDavSignInRejectedContacts(a('provider')),
    'davSignInRejectedCalendar' => l.coreDavSignInRejectedCalendar(a('provider')),
    'davScopeMissingContacts' => l.coreDavScopeMissingContacts(a('provider')),
    'davScopeMissingCalendar' => l.coreDavScopeMissingCalendar(a('provider')),
    'accountScopeMissingContacts' => l.coreAccountScopeMissingContacts(a('provider')),
    'accountScopeMissingCalendar' => l.coreAccountScopeMissingCalendar(a('provider')),
    'notConnected' => l.coreNotConnected,
    null => null,
    final other => coreErrorTextL6c(l, other, a),
  };
  return text ?? fallback;
}

/// Codici che chiedono un nuovo accesso con il fornitore (striscia rossa «Accedi di nuovo» di Persone e Calendario).
const signInAgainCodes = {
  'oauthExpired',
  'davSignInRejectedContacts',
  'davSignInRejectedCalendar',
  'davScopeMissingContacts',
  'davScopeMissingCalendar',
  'accountScopeMissingContacts',
  'accountScopeMissingCalendar',
};

/// Valori di un errore dal JSON del core (oggetto di testi; altro = nessun valore).
Map<String, String> coreErrorArgs(Object? json) =>
    json is Map ? {for (final e in json.entries) '${e.key}': '${e.value}'} : const {};
