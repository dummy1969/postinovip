using PostinoVip.Core.Imap;

namespace PostinoVip.Core.Tests;

public class ReconnectingSessionTests
{
    /// <summary>Sessione finta: può "morire" e conta i ping.</summary>
    private sealed class FakeSession(int id) : IAsyncDisposable
    {
        public int Id { get; } = id;
        public bool Alive { get; set; } = true;
        public bool PingFails { get; set; }
        public int Pings { get; set; }
        public bool Disposed { get; private set; }

        public ValueTask DisposeAsync()
        {
            Disposed = true;
            return ValueTask.CompletedTask;
        }
    }

    private sealed class ManualTime : TimeProvider
    {
        public DateTimeOffset Now { get; set; } = new(2026, 10, 29, 12, 0, 0, TimeSpan.Zero);
        public override DateTimeOffset GetUtcNow() => Now;
    }

    private readonly ManualTime _time = new();
    private readonly List<FakeSession> _created = [];

    private ReconnectingSession<FakeSession> Create() => new(
        connect: _ =>
        {
            var s = new FakeSession(_created.Count + 1);
            _created.Add(s);
            return Task.FromResult(s);
        },
        isAlive: s => s.Alive,
        ping: (s, _) =>
        {
            s.Pings++;
            return s.PingFails ? Task.FromException(new IOException("chiusa")) : Task.CompletedTask;
        },
        isConnectionError: ex => ex is IOException,
        pingAfter: TimeSpan.FromMinutes(2),
        time: _time);

    [Fact]
    public async Task RiusaLaStessaSessione()
    {
        await using var rs = Create();

        for (var i = 0; i < 5; i++)
            Assert.Equal(1, await rs.RunAsync(s => Task.FromResult(s.Id), retryOnConnectionError: true));

        Assert.Equal(1, rs.ConnectCount);
    }

    [Fact]
    public async Task SessioneCadutaVieneRiaperta()
    {
        await using var rs = Create();
        await rs.RunAsync(s => Task.FromResult(0), true);
        _created[0].Alive = false;

        Assert.Equal(2, await rs.RunAsync(s => Task.FromResult(s.Id), true));
        Assert.True(_created[0].Disposed);
    }

    [Fact]
    public async Task LetturaRipetutaUnaVoltaDopoErroreDiConnessione()
    {
        await using var rs = Create();
        var attempts = 0;

        var id = await rs.RunAsync(s =>
        {
            attempts++;
            return s.Id == 1 ? Task.FromException<int>(new IOException("reset")) : Task.FromResult(s.Id);
        }, retryOnConnectionError: true);

        Assert.Equal(2, id);
        Assert.Equal(2, attempts);
    }

    [Fact]
    public async Task ScritturaNonRipetuta()
    {
        await using var rs = Create();
        var attempts = 0;

        await Assert.ThrowsAsync<IOException>(() => rs.RunAsync<int>(_ =>
        {
            attempts++;
            throw new IOException("reset");
        }, retryOnConnectionError: false));

        Assert.Equal(1, attempts);
        // La sessione rotta è stata scartata: la chiamata successiva ne apre una nuova.
        Assert.Equal(2, await rs.RunAsync(s => Task.FromResult(s.Id), false));
    }

    [Fact]
    public async Task ErroreNonDiConnessioneMantieneLaSessione()
    {
        await using var rs = Create();

        await Assert.ThrowsAsync<InvalidOperationException>(() =>
            rs.RunAsync<int>(_ => throw new InvalidOperationException("NO dal server"), true));

        Assert.Equal(1, await rs.RunAsync(s => Task.FromResult(s.Id), true));
        Assert.Equal(1, rs.ConnectCount);
    }

    [Fact]
    public async Task DopoInattivitaPingEPoiRiuso()
    {
        await using var rs = Create();
        await rs.RunAsync(s => Task.FromResult(0), true);

        _time.Now += TimeSpan.FromMinutes(1);
        await rs.RunAsync(s => Task.FromResult(0), true);
        Assert.Equal(0, _created[0].Pings); // sotto la soglia: nessun ping

        _time.Now += TimeSpan.FromMinutes(5);
        Assert.Equal(1, await rs.RunAsync(s => Task.FromResult(s.Id), true));
        Assert.Equal(1, _created[0].Pings);
    }

    [Fact]
    public async Task PingFallitoRiapreSenzaErroriPerIlChiamante()
    {
        await using var rs = Create();
        await rs.RunAsync(s => Task.FromResult(0), true);
        _created[0].PingFails = true; // il server ha chiuso durante l'inattività
        _time.Now += TimeSpan.FromMinutes(30);

        // Anche per una scrittura: il problema emerge nel ping, prima di eseguire il comando.
        Assert.Equal(2, await rs.RunAsync(s => Task.FromResult(s.Id), retryOnConnectionError: false));
    }

    [Fact]
    public async Task UnComandoAllaVolta()
    {
        await using var rs = Create();
        var running = 0;
        var maxRunning = 0;

        await Task.WhenAll(Enumerable.Range(0, 20).Select(_ => rs.RunAsync(async s =>
        {
            maxRunning = Math.Max(maxRunning, Interlocked.Increment(ref running));
            await Task.Delay(5);
            Interlocked.Decrement(ref running);
            return 0;
        }, true)));

        Assert.Equal(1, maxRunning);
        Assert.Equal(1, rs.ConnectCount);
    }

    // ---------------------------------------------------------------------------------------------
    // Senza rete
    // ---------------------------------------------------------------------------------------------

    /// <summary>Server finto: collegamento riuscito, rifiutato (errore di rete) o senza risposta.</summary>
    private Exception? _connectError;
    private bool _connectHangs;
    private int _connectAttempts;
    private readonly List<bool> _changes = [];

    private ReconnectingSession<FakeSession> CreateOffline() => new(
        connect: async ct =>
        {
            _connectAttempts++;
            if (_connectHangs)
                await Task.Delay(Timeout.Infinite, ct);
            if (_connectError is { } error)
                throw error;
            var s = new FakeSession(_created.Count + 1);
            _created.Add(s);
            return s;
        },
        isAlive: s => s.Alive,
        ping: (_, _) => Task.CompletedTask,
        isConnectionError: ex => ex is IOException,
        pingAfter: TimeSpan.FromMinutes(2),
        time: _time,
        connectTimeout: TimeSpan.FromMilliseconds(50),
        offlineFor: TimeSpan.FromMinutes(1),
        onlineChanged: _changes.Add);

    [Fact]
    public async Task ServerNonRaggiungibilePoiPausaSenzaNuoviTentativi()
    {
        await using var rs = CreateOffline();
        _connectError = new IOException("rete assente");

        var first = await Assert.ThrowsAsync<MailOfflineException>(() => rs.RunAsync(s => Task.FromResult(0), true));
        Assert.Contains("rete assente", first.Message);
        Assert.False(rs.IsOnline);
        Assert.Equal([false], _changes);

        // Entro un minuto: errore subito, senza ritentare il collegamento.
        _time.Now += TimeSpan.FromSeconds(30);
        await Assert.ThrowsAsync<MailOfflineException>(() => rs.RunAsync(s => Task.FromResult(0), true));
        Assert.Equal(1, _connectAttempts);

        // Dopo la pausa si ritenta; la rete è tornata.
        _connectError = null;
        _time.Now += TimeSpan.FromSeconds(31);
        Assert.Equal(1, await rs.RunAsync(s => Task.FromResult(s.Id), true));
        Assert.True(rs.IsOnline);
        Assert.Equal([false, true], _changes);
    }

    [Fact]
    public async Task NessunaRispostaEntroIlTempoMassimo()
    {
        await using var rs = CreateOffline();
        _connectHangs = true;

        var ex = await Assert.ThrowsAsync<MailOfflineException>(() => rs.RunAsync(s => Task.FromResult(0), true));

        Assert.IsType<TimeoutException>(ex.InnerException);
        Assert.False(rs.IsOnline);
    }

    [Fact]
    public async Task ScadenzaSegnalataConUnAltroErroreEComunqueNessunaRisposta()
    {
        // Come MailKit durante la cifratura: l'annullamento arriva come errore di handshake.
        await using var rs = new ReconnectingSession<FakeSession>(
            connect: async ct =>
            {
                try
                {
                    await Task.Delay(Timeout.Infinite, ct);
                }
                catch (OperationCanceledException e)
                {
                    throw new InvalidOperationException("handshake interrotto", e);
                }
                return new FakeSession(1);
            },
            isAlive: _ => true, ping: (_, _) => Task.CompletedTask, isConnectionError: ex => ex is IOException,
            pingAfter: TimeSpan.FromMinutes(2), time: _time,
            connectTimeout: TimeSpan.FromMilliseconds(50), offlineFor: TimeSpan.FromMinutes(1));

        var ex = await Assert.ThrowsAsync<MailOfflineException>(() => rs.RunAsync(s => Task.FromResult(0), true));

        Assert.IsType<TimeoutException>(ex.InnerException);
        Assert.False(rs.IsOnline);
    }

    [Fact]
    public async Task ControlloPeriodicoRiprovaAncheDuranteLaPausa()
    {
        await using var rs = CreateOffline();
        _connectError = new IOException("rete assente");
        await Assert.ThrowsAsync<MailOfflineException>(() => rs.RunAsync(s => Task.FromResult(0), true));

        Assert.False(await rs.ProbeAsync());
        _connectError = null;
        Assert.True(await rs.ProbeAsync()); // ancora dentro il minuto di pausa

        Assert.True(rs.IsOnline);
        Assert.Equal([false, true], _changes);
        Assert.Equal(1, await rs.RunAsync(s => Task.FromResult(s.Id), true)); // usa la sessione appena aperta
    }

    [Fact]
    public async Task CredenzialiSbagliateNonSonoMancanzaDiRete()
    {
        await using var rs = CreateOffline();
        _connectError = new UnauthorizedAccessException("password errata");

        await Assert.ThrowsAsync<UnauthorizedAccessException>(() => rs.RunAsync(s => Task.FromResult(0), true));

        Assert.True(rs.IsOnline);
        Assert.Empty(_changes);
    }

    [Fact]
    public async Task ConnessioneCadutaERiconnessioneImpossibileDuranteUnaLettura()
    {
        await using var rs = CreateOffline();
        await rs.RunAsync(s => Task.FromResult(0), true);
        _connectError = new IOException("rete assente");

        // La lettura fallisce per la rete, il nuovo collegamento pure: "non connesso".
        await Assert.ThrowsAsync<MailOfflineException>(() =>
            rs.RunAsync<int>(_ => throw new IOException("connessione persa"), retryOnConnectionError: true));

        Assert.False(rs.IsOnline);
    }
}
