using System.Reflection;
using System.Runtime.InteropServices;
using Microsoft.AspNetCore.Mvc;
using PostinoVip.Api.Contracts;

namespace PostinoVip.Api.Controllers;

[ApiController]
[Route("version")]
public sealed class VersionController : ControllerBase
{
    /// <summary>GET /version — versione del core e ambiente di esecuzione (finestra "Informazioni" dell'app).</summary>
    [HttpGet]
    public ActionResult<VersionResponse> Get() => Ok(new VersionResponse(
        typeof(Program).Assembly.GetCustomAttribute<AssemblyInformationalVersionAttribute>()?.InformationalVersion ?? "?",
        RuntimeInformation.FrameworkDescription,
        RuntimeInformation.OSDescription));
}
