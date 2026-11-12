# Sicurezza / Security

## Segnalare un problema

Se trovi un problema di sicurezza in PostinoVip (per esempio un modo per far eseguire codice con una mail, leggere i dati
di un altro utente del computer, aggirare il controllo dei certificati o il token del core), **non aprire una issue
pubblica**: usa la segnalazione privata di GitHub, **Security → Report a vulnerability** in questo repository.

Indica la versione (menu ⋮ → Informazioni su PostinoVip), il sistema operativo e i passi per riprodurre il problema.
**Non allegare mail vere, password o token**: se serve una mail d'esempio, costruiscine una con dati inventati.

PostinoVip è un progetto personale: rispondo appena posso, di solito entro qualche giorno, e la correzione arriva con la
versione successiva. Non c'è un programma di ricompense.

## Versioni seguite

Solo l'ultima versione pubblicata. Il progetto è in **alpha**: aggiorna prima di segnalare.

## Cosa fa già PostinoVip

- Il core ascolta solo su `127.0.0.1`, con una porta casuale e un token generato a ogni avvio; il token passa solo per
  variabile d'ambiente, mai sulla riga di comando né nei log.
- Connessioni cifrate di serie (SSL/TLS o STARTTLS obbligatorio); la verifica dei certificati non si spegne mai (un
  certificato autofirmato si accetta solo dopo conferma, per impronta SHA-256).
- Le mail HTML sono ripulite nel core e mostrate senza JavaScript; immagini remote bloccate finché l'utente non le
  sblocca; nella posta indesiderata collegamenti disattivati.
- Password e token di rinnovo OAuth2 nell'archivio sicuro del sistema; mai password, token o contenuti delle mail nei log.

---

## Reporting a vulnerability

Please **do not open a public issue**. Use GitHub's private reporting (**Security → Report a vulnerability**) and
include the version (menu ⋮ → Informazioni su PostinoVip), your OS and the steps to reproduce. Do not attach real mail,
passwords or tokens. This is a personal project: I usually reply within a few days; only the latest release is
supported; there is no bug bounty.
