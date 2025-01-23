using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Project32.API.Services;
using Project32.API.Models;

namespace Project32.API.Controllers
{
    [ApiController]
    [Route("api/[controller]")]
    public class AmenityController : ControllerBase
    {
        private readonly IDatabaseService _dbService;
        private readonly ILogger<AmenityController> _logger;

        public AmenityController(IDatabaseService dbService, ILogger<AmenityController> logger)
        {
            _dbService = dbService;
            _logger = logger;
        }

        [HttpGet]
        public async Task<IActionResult> GetAmenities()
        {
            try
            {
                var amenities = await _dbService.QueryAsync<Amenity>(
                    "SELECT * FROM amenity_table WHERE is_active = 1 ORDER BY name"
                );
                return Ok(amenities);
            }
            catch (Exception ex)
            {
                _logger.LogError(ex, "Error retrieving amenities");
                return StatusCode(500, "Internal server error");
            }
        }

        [HttpGet("{id}")]
        public async Task<IActionResult> GetAmenity(int id)
        {
            try
            {
                var amenity = await _dbService.QuerySingleAsync<Amenity>(
                    "SELECT * FROM amenity_table WHERE amenity_id = :id",
                    new { id }
                );
                return amenity == null ? NotFound() : Ok(amenity);
            }
            catch (Exception ex)
            {
                _logger.LogError(ex, "Error retrieving amenity {AmenityId}", id);
                return StatusCode(500, "Internal server error");
            }
        }

        [HttpPost]
        [Authorize]
        public async Task<IActionResult> CreateAmenity([FromBody] Amenity amenity)
        {
            try
            {
                var sql = @"
                    INSERT INTO amenity_table (
                        name, description, is_active, created_date
                    ) VALUES (
                        :Name, :Description, :IsActive, SYSDATE
                    ) RETURNING amenity_id INTO :AmenityId";

                var parameters = new
                {
                    amenity.Name,
                    amenity.Description,
                    IsActive = true,
                    AmenityId = 0
                };

                await _dbService.ExecuteAsync(sql, parameters);
                return CreatedAtAction(nameof(GetAmenity), new { id = parameters.AmenityId }, amenity);
            }
            catch (Exception ex)
            {
                _logger.LogError(ex, "Error creating amenity");
                return StatusCode(500, "Internal server error");
            }
        }

        [HttpPut("{id}")]
        [Authorize]
        public async Task<IActionResult> UpdateAmenity(int id, [FromBody] Amenity amenity)
        {
            try
            {
                var sql = @"
                    UPDATE amenity_table 
                    SET name = :Name,
                        description = :Description,
                        modified_date = SYSDATE
                    WHERE amenity_id = :Id";

                var result = await _dbService.ExecuteAsync(sql, new
                {
                    amenity.Name,
                    amenity.Description,
                    Id = id
                });

                return result > 0 ? Ok() : NotFound();
            }
            catch (Exception ex)
            {
                _logger.LogError(ex, "Error updating amenity {AmenityId}", id);
                return StatusCode(500, "Internal server error");
            }
        }

        [HttpDelete("{id}")]
        [Authorize]
        public async Task<IActionResult> DeleteAmenity(int id)
        {
            try
            {
                var sql = "UPDATE amenity_table SET is_active = 0 WHERE amenity_id = :id";
                var result = await _dbService.ExecuteAsync(sql, new { id });
                return result > 0 ? Ok() : NotFound();
            }
            catch (Exception ex)
            {
                _logger.LogError(ex, "Error deleting amenity {AmenityId}", id);
                return StatusCode(500, "Internal server error");
            }
        }
    }
}
