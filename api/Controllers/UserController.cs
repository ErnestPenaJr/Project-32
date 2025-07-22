using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Project32.API.Services;

namespace Project32.API.Controllers
{
    [ApiController]
    [Route("api/[controller]")]
    public class UserController : ControllerBase
    {
        private readonly IDatabaseService _dbService;
        private readonly ILogger<UserController> _logger;

        public UserController(IDatabaseService dbService, ILogger<UserController> logger)
        {
            _dbService = dbService;
            _logger = logger;
        }

        [HttpGet]
        [Authorize]
        public async Task<IActionResult> GetUsers()
        {
            try
            {
                var users = await _dbService.QueryAsync<dynamic>(
                    "SELECT * FROM user_table"
                );
                return Ok(users);
            }
            catch (Exception ex)
            {
                _logger.LogError(ex, "Error retrieving users");
                return StatusCode(500, "Internal server error");
            }
        }

        [HttpGet("{id}")]
        [Authorize]
        public async Task<IActionResult> GetUser(int id)
        {
            try
            {
                var user = await _dbService.QuerySingleAsync<dynamic>(
                    "SELECT * FROM user_table WHERE user_id = :id",
                    new { id }
                );
                return user == null ? NotFound() : Ok(user);
            }
            catch (Exception ex)
            {
                _logger.LogError(ex, "Error retrieving user {UserId}", id);
                return StatusCode(500, "Internal server error");
            }
        }

        [HttpPost]
        [Authorize]
        public async Task<IActionResult> CreateUser([FromBody] dynamic userData)
        {
            try
            {
                var result = await _dbService.ExecuteAsync(
                    "INSERT INTO user_table (username, email) VALUES (:username, :email)",
                    userData
                );
                return Ok(new { affected_rows = result });
            }
            catch (Exception ex)
            {
                _logger.LogError(ex, "Error creating user");
                return StatusCode(500, "Internal server error");
            }
        }
    }
}
