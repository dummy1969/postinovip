import 'package:flutter_test/flutter_test.dart';
import 'package:postinovip/models/attachment_info.dart';
import 'package:postinovip/models/mail_folder.dart';
import 'package:postinovip/models/message_page.dart';
import 'package:postinovip/ui/format.dart';

void main() {
  test('MessagePage.fromJson legge il JSON dell\'Api', () {
    final page = MessagePage.fromJson({
      'total': 120,
      'offset': 0,
      'limit': 50,
      'items': [
        {'uid': 7, 'subject': 'Ciao', 'from': 'Mario', 'date': '2026-10-29T10:00:00+00:00', 'seen': false},
        {'uid': 6, 'subject': 'x', 'from': 'Anna', 'date': null, 'seen': true},
      ],
    });

    expect(page.total, 120);
    expect(page.items, hasLength(2));
    expect(page.items[0].uid, 7);
    expect(page.items[0].date!.toUtc(), DateTime.utc(2026, 10, 29, 10));
    expect(page.items[0].seen, isFalse);
    expect(page.items[1].date, isNull);
  });

  test('MailFolder.depth con separatori diversi', () {
    expect(const MailFolder(fullName: 'INBOX', name: 'INBOX').depth, 0);
    expect(const MailFolder(fullName: 'INBOX.Sent', name: 'Sent').depth, 1);
    expect(const MailFolder(fullName: 'INBOX/Lavoro/2026', name: '2026').depth, 2);
  });

  test('formatListDate', () {
    final now = DateTime(2026, 10, 29, 15);
    expect(formatListDate(DateTime(2026, 10, 29, 9, 5), now: now), '09:05');
    expect(formatListDate(DateTime(2026, 10, 26, 8, 30), now: now), 'lun 08:30'); // ultimi sette giorni
    expect(formatListDate(DateTime(2026, 3, 1), now: now), '01/03');
    expect(formatListDate(DateTime(2025, 12, 31), now: now), '31/12/2025');
    expect(formatListDate(null, now: now), '');
  });

  test('gruppi per data come Outlook (settimana dal lunedì)', () {
    final now = DateTime(2026, 10, 29, 15); // giovedì
    String g(DateTime d) => listGroupLabel(d, now: now);
    expect(g(DateTime(2026, 10, 29, 8)), 'Oggi');
    expect(g(DateTime(2026, 10, 28, 23)), 'Ieri');
    expect(g(DateTime(2026, 10, 26, 9)), 'Lunedì');
    expect(g(DateTime(2026, 10, 25, 9)), 'Settimana scorsa'); // domenica
    expect(g(DateTime(2026, 10, 12, 9)), 'Due settimane fa');
    expect(g(DateTime(2026, 10, 5, 9)), 'Tre settimane fa');
    expect(g(DateTime(2026, 10, 2, 9)), 'Prima in questo mese');
    expect(g(DateTime(2026, 9, 1)), 'Mese scorso');
    expect(g(DateTime(2026, 8, 31)), 'Più vecchi');
    expect(listGroupLabel(null, now: now), 'Senza data');
  });

  test('AttachmentInfo: anteprima solo per formati decodificabili', () {
    AttachmentInfo a(String type) => AttachmentInfo(index: 0, fileName: 'x', contentType: type);
    expect(a('image/jpeg').isPreviewableImage, isTrue);
    expect(a('IMAGE/PNG').isPreviewableImage, isTrue);
    expect(a('image/heic').isPreviewableImage, isFalse);
    expect(a('application/pdf').isPreviewableImage, isFalse);
  });

  test('MailFolder.specialUse letto dal JSON', () {
    final f = MailFolder.fromJson({'fullName': 'Posta inviata', 'name': 'Posta inviata', 'count': 0, 'specialUse': 'sent'});
    expect(f.specialUse, 'sent');
    expect(MailFolder.fromJson({'fullName': 'X', 'name': 'X', 'count': 0}).specialUse, isNull);
  });
}
