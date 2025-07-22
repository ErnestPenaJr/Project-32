using Microsoft.AspNetCore.Mvc;
using Project32.API.Services;
using Oracle.ManagedDataAccess.Client;

namespace Project32.API.Controllers
{
    [ApiController]
    [Route("api/[controller]")]
    public class TestController : ControllerBase
    {
        private readonly IDatabaseService _dbService;
        private readonly IConfiguration _configuration;
        private readonly ILogger<TestController> _logger;

        public TestController(
            IDatabaseService dbService,
            IConfiguration configuration,
            ILogger<TestController> logger)
        {
            _dbService = dbService;
            _configuration = configuration;
            _logger = logger;
        }

        [HttpGet("connection")]
        public async Task<IActionResult> TestConnection()
        {
            try
            {
                // Test basic connection
                var result = await _dbService.QuerySingleAsync<DateTime>(
                    "SELECT SYSDATE FROM DUAL"
                );

                return Ok(new
                {
                    Status = "Success",
                    Message = "Database connection successful",
                    ServerTime = result,
                    DatabaseVersion = await GetDatabaseVersion()
                });
            }
            catch (Exception ex)
            {
                _logger.LogError(ex, "Database connection test failed");
                return StatusCode(500, new
                {
                    Status = "Error",
                    Message = "Database connection failed",
                    Error = ex.Message,
                    Details = ex.ToString()
                });
            }
        }

        private async Task<string> GetDatabaseVersion()
        {
            try
            {
                return await _dbService.QuerySingleAsync<string>(
                    "SELECT version FROM product_component_version WHERE product LIKE 'Oracle%' AND ROWNUM = 1"
                );
            }
            catch
            {
                return "Version information unavailable";
            }
        }
    }
}
