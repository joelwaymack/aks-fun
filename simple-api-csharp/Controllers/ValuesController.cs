using Microsoft.AspNetCore.Mvc;

namespace SimpleApi.Controllers;

[ApiController]
[Route("[controller]")]
public class ValuesController : ControllerBase
{
    [HttpGet]
    public string GetValue()
    {
        return "Hello World!";
    }

    [HttpGet("/")]
    public string GetHealth()
    {
        return "Healthy";
    }
}
