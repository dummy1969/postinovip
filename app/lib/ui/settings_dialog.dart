import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../account/accounts_page.dart';
import '../api/api_client.dart';
import '../notify/system_notifier.dart';
import '../models/calendar.dart';
import '../settings/app_settings.dart';
import '../state/calendar_model.dart';
import '../state/mailbox_model.dart';
import 'signatures_dialog.dart';

/// Una pagina delle Opzioni: nome nell'elenco, icona e contenuto.
enum SettingsPage {
  general('Generale', Icons.tune),
  mail('Posta', Icons.mail_outline),
  notifications('Notifiche', Icons.notifications_none),
  calendar('Calendario', Icons.calendar_month_outlined);

  const SettingsPage(this.label, this.icon);

  final String label;
  final IconData icon;
}

/// Opzioni dell'app (File → Opzioni), come «Opzioni di Outlook» (scelta 1a del 10/11/2026): le categorie in un
/// elenco a sinistra e la pagina a destra (con la finestra minima di 640×480 c'è sempre posto per l'elenco).
/// Grandezza fissa (4a): cambiando pagina la finestra non salta. Le modifiche valgono e si salvano subito.
class SettingsDialog extends StatefulWidget {
  const SettingsDialog({super.key, this.initialPage = SettingsPage.general});

  final SettingsPage initialPage;

  @override
  State<SettingsDialog> createState() => _SettingsDialogState();
}

class _SettingsDialogState extends State<SettingsDialog> {
  late SettingsPage _page = widget.initialPage;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final screen = MediaQuery.sizeOf(context);
    final width = (screen.width - 48).clamp(280.0, 760.0);
    final height = (screen.height - 48).clamp(300.0, 540.0);
    final page = SingleChildScrollView(
      key: ValueKey('settings-page-${_page.name}'),
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: switch (_page) {
          SettingsPage.general => _general(context),
          SettingsPage.mail => _mail(context),
          SettingsPage.notifications => _notifications(context),
          SettingsPage.calendar => const [CalendarOptions()],
        },
      ),
    );
    return Dialog(
      key: const Key('settings-dialog'),
      insetPadding: const EdgeInsets.all(24),
      child: SizedBox(
        width: width,
        height: height,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
              child: Text('Opzioni', style: theme.textTheme.titleLarge),
            ),
            Expanded(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  SizedBox(
                    width: 170,
                    child: ListView(
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      children: [
                        for (final p in SettingsPage.values)
                          ListTile(
                            key: Key('settings-tab-${p.name}'),
                            dense: true,
                            leading: Icon(p.icon, size: 20),
                            title: Text(p.label),
                            selected: p == _page,
                            selectedTileColor: theme.colorScheme.primary.withValues(alpha: 0.12),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                            onTap: () => setState(() => _page = p),
                          ),
                      ],
                    ),
                  ),
                  const VerticalDivider(width: 1),
                  Expanded(child: page),
                ],
              ),
            ),
            const Divider(height: 1),
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 8, 16, 12),
              child: Align(
                alignment: Alignment.centerRight,
                child: TextButton(onPressed: () => Navigator.pop(context), child: const Text('Chiudi')),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Generale: account, tema di Office e posizione della barra dei moduli.
  List<Widget> _general(BuildContext context) {
    final settings = context.watch<AppSettings>();
    return [
      if (context.read<AccountsEditing?>() case final editing?) ...[
        Text('Account', style: Theme.of(context).textTheme.titleSmall),
        ListTile(
          contentPadding: EdgeInsets.zero,
          leading: const Icon(Icons.manage_accounts),
          title: Text(
            editing.accounts.isNotEmpty
                ? editing.accounts.map((a) => a.displayName).join(', ')
                : editing.coreAddress.isEmpty
                ? '(non configurato)'
                : editing.coreAddress,
          ),
          subtitle: Text(
            editing.accounts.isEmpty
                ? 'Dati da user-secrets (sviluppo)'
                : editing.accounts.length == 1
                ? '1 account'
                : '${editing.accounts.length} account',
          ),
          trailing: TextButton(
            child: const Text('Gestisci…'),
            // La finestra Account si apre sopra le Opzioni: «Annulla» riporta qui (richieste dell'utente del
            // 10/11/2026). Con «OK» e delle modifiche il core riparte e l'app viene ricreata, finestre comprese.
            onPressed: () => AccountsPage.show(context, api: context.read<ApiClient>(), editing: editing),
          ),
        ),
        const Divider(),
      ],
      Text('Aspetto', style: Theme.of(context).textTheme.titleSmall),
      Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: DropdownButtonFormField<AppTheme>(
          key: const ValueKey('theme-choice'),
          isExpanded: true,
          initialValue: settings.theme,
          decoration: const InputDecoration(
            labelText: 'Tema',
            helperText: 'Il testo delle mail resta su fondo bianco anche con i temi scuri',
            border: OutlineInputBorder(),
          ),
          items: [for (final t in AppTheme.values) DropdownMenuItem(value: t, child: Text(t.label))],
          onChanged: (t) {
            if (t != null) settings.setTheme(t);
          },
        ),
      ),
      Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: DropdownButtonFormField<ModuleBarPosition>(
          key: const ValueKey('module-bar-choice'),
          isExpanded: true,
          initialValue: settings.moduleBar,
          decoration: const InputDecoration(
            labelText: 'Barra dei moduli (Posta, Calendario, Persone)',
            border: OutlineInputBorder(),
          ),
          items: [for (final p in ModuleBarPosition.values) DropdownMenuItem(value: p, child: Text(p.label))],
          onChanged: (p) {
            if (p != null) settings.setModuleBar(p);
          },
        ),
      ),
    ];
  }

  /// Posta: firme, Segna come letto, conferme di lettura, conferme di Ignora conversazione.
  List<Widget> _mail(BuildContext context) {
    final settings = context.watch<AppSettings>();
    return [
      Text('Firme', style: Theme.of(context).textTheme.titleSmall),
      ListTile(
        contentPadding: EdgeInsets.zero,
        leading: const Icon(Icons.draw_outlined),
        title: Text(switch (settings.signatures.length) {
          0 => 'Nessuna firma',
          1 => '1 firma',
          final n => '$n firme',
        }),
        subtitle: const Text('Aggiunte da sole ai nuovi messaggi e alle risposte, per account'),
        trailing: TextButton(
          child: const Text('Firme…'),
          onPressed: () => showSignaturesDialog(context, accounts: context.read<MailboxModel>().accounts),
        ),
      ),
      const Divider(height: 32),
      Text('Segna come letto', style: Theme.of(context).textTheme.titleSmall),
      RadioGroup<ReadMode>(
        groupValue: settings.readMode,
        onChanged: (mode) {
          if (mode != null) settings.setReadMode(mode);
        },
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (final mode in ReadMode.values)
              RadioListTile<ReadMode>(value: mode, title: Text(mode.label), contentPadding: EdgeInsets.zero),
          ],
        ),
      ),
      if (settings.readMode == ReadMode.afterDelay)
        Row(
          children: [
            Expanded(
              child: Slider(
                value: settings.readDelaySeconds.toDouble(),
                min: AppSettings.minReadDelay.toDouble(),
                max: AppSettings.maxReadDelay.toDouble(),
                divisions: AppSettings.maxReadDelay - AppSettings.minReadDelay,
                label: '${settings.readDelaySeconds} s',
                // Durante il trascinamento si aggiorna solo il valore mostrato; si salva al rilascio.
                onChanged: (v) => settings.setReadDelay(v.round(), save: false),
                onChangeEnd: (v) => settings.setReadDelay(v.round()),
              ),
            ),
            SizedBox(width: 56, child: Text('${settings.readDelaySeconds} s', textAlign: TextAlign.end)),
          ],
        ),
      const Divider(height: 32),
      // Conferme di lettura (R2), come Outlook: File → Opzioni → Posta → Rilevamento.
      Text('Conferme di lettura', style: Theme.of(context).textTheme.titleSmall),
      CheckboxListTile(
        key: const Key('settings-request-receipt'),
        value: settings.requestReadReceipt,
        onChanged: (v) => settings.setRequestReadReceipt(v ?? false),
        title: const Text('Chiedi sempre la conferma di lettura nei nuovi messaggi'),
        controlAffinity: ListTileControlAffinity.leading,
        contentPadding: EdgeInsets.zero,
      ),
      Text('Per i messaggi ricevuti che chiedono una conferma:', style: Theme.of(context).textTheme.bodyMedium),
      RadioGroup<ReceiptMode>(
        groupValue: settings.receiptMode,
        onChanged: (mode) {
          if (mode != null) settings.setReceiptMode(mode);
        },
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (final mode in ReceiptMode.values)
              RadioListTile<ReceiptMode>(
                key: Key('settings-receipt-${mode.name}'),
                value: mode,
                title: Text(mode.label),
                contentPadding: EdgeInsets.zero,
              ),
          ],
        ),
      ),
      const Divider(height: 32),
      // Ignora conversazione (C2, 3a del 10/11/2026): riattivare le domande tolte con «Non visualizzare più».
      Text('Ignora conversazione', style: Theme.of(context).textTheme.titleSmall),
      CheckboxListTile(
        key: const Key('settings-confirm-ignore'),
        value: settings.confirmIgnore,
        onChanged: (v) => settings.setConfirmIgnore(v ?? true),
        title: const Text('Chiedi conferma prima di Ignora conversazione'),
        controlAffinity: ListTileControlAffinity.leading,
        contentPadding: EdgeInsets.zero,
      ),
      CheckboxListTile(
        key: const Key('settings-confirm-stop-ignoring'),
        value: settings.confirmStopIgnoring,
        onChanged: (v) => settings.setConfirmStopIgnoring(v ?? true),
        title: const Text('Chiedi conferma prima di Interrompi Ignora conversazione'),
        controlAffinity: ListTileControlAffinity.leading,
        contentPadding: EdgeInsets.zero,
      ),
    ];
  }

  /// Notifiche di nuova posta.
  List<Widget> _notifications(BuildContext context) {
    final settings = context.watch<AppSettings>();
    return [
      Text('Notifiche di nuova posta', style: Theme.of(context).textTheme.titleSmall),
      RadioGroup<NotifyMode>(
        groupValue: settings.notifyMode,
        onChanged: (mode) {
          if (mode != null) settings.setNotifyMode(mode);
        },
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (final mode in NotifyMode.values)
              RadioListTile<NotifyMode>(value: mode, title: Text(mode.label), contentPadding: EdgeInsets.zero),
          ],
        ),
      ),
      const SizedBox(height: 8),
      Builder(
        builder: (context) {
          final notifier = context.read<MailNotifier?>();
          if (notifier == null) {
            return Text(
              'Notifiche di sistema non disponibili: il motivo è nel terminale ("[notifiche]").',
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            );
          }
          return OutlinedButton.icon(
            icon: const Icon(Icons.notifications_active),
            label: const Text('Prova notifica'),
            onPressed: () => notifier
                .show('PostinoVip', 'Notifica di prova: se la vedi, le notifiche funzionano.')
                .catchError((Object _) {}), // l'errore è già nel terminale
          );
        },
      ),
    ];
  }
}

/// Opzioni del calendario (K3, scelta 2b): primo giorno della settimana, giorni e orario lavorativi.
class CalendarOptions extends StatelessWidget {
  const CalendarOptions({super.key});

  static String _time(int minutes) =>
      '${(minutes ~/ 60).toString().padLeft(2, '0')}:${(minutes % 60).toString().padLeft(2, '0')}';

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<AppSettings>();
    final prefs = settings.calendar;
    final theme = Theme.of(context);
    final halfHours = [for (var m = 0; m <= 24 * 60; m += 30) m];
    Future<void> save(CalendarPrefs p) async {
      await settings.setCalendar(p);
      if (context.mounted) await context.read<CalendarModel>().reloadEvents();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Calendario', style: theme.textTheme.titleSmall),
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: DropdownButtonFormField<int>(
            key: const ValueKey('calendar-first-day'),
            isExpanded: true,
            initialValue: prefs.firstDay,
            decoration: const InputDecoration(labelText: 'Primo giorno della settimana', border: OutlineInputBorder()),
            items: [for (var d = 1; d <= 7; d++) DropdownMenuItem(value: d, child: Text(CalendarModel.weekdayName(d)))],
            onChanged: (d) {
              if (d != null) save(prefs.copyWith(firstDay: d));
            },
          ),
        ),
        Text('Giorni lavorativi (Settimana lavorativa)', style: theme.textTheme.bodyMedium),
        Wrap(
          spacing: 6,
          children: [
            for (var d = 1; d <= 7; d++)
              FilterChip(
                key: ValueKey('calendar-work-day-$d'),
                label: Text(CalendarModel.weekdaysShort[d - 1]),
                selected: prefs.workDays.contains(d),
                onSelected: (on) {
                  final days = {...prefs.workDays};
                  on ? days.add(d) : days.remove(d);
                  if (days.isNotEmpty) save(prefs.copyWith(workDays: days)); // almeno un giorno
                },
              ),
          ],
        ),
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Row(
            children: [
              Expanded(
                child: DropdownButtonFormField<int>(
                  key: const ValueKey('calendar-work-start'),
                  isExpanded: true,
                  initialValue: prefs.workStart,
                  decoration: const InputDecoration(
                    labelText: 'Inizio orario lavorativo',
                    border: OutlineInputBorder(),
                  ),
                  items: [
                    for (final m in halfHours)
                      if (m < prefs.workEnd) DropdownMenuItem(value: m, child: Text(_time(m))),
                  ],
                  onChanged: (m) {
                    if (m != null) save(prefs.copyWith(workStart: m));
                  },
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: DropdownButtonFormField<int>(
                  key: const ValueKey('calendar-work-end'),
                  isExpanded: true,
                  initialValue: prefs.workEnd,
                  decoration: const InputDecoration(labelText: 'Fine orario lavorativo', border: OutlineInputBorder()),
                  items: [
                    for (final m in halfHours)
                      if (m > prefs.workStart) DropdownMenuItem(value: m, child: Text(_time(m))),
                  ],
                  onChanged: (m) {
                    if (m != null) save(prefs.copyWith(workEnd: m));
                  },
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
