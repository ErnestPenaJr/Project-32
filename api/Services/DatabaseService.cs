using Oracle.ManagedDataAccess.Client;
using Dapper;
using System.Data;

namespace Project32.API.Services
{
    public interface IDatabaseService
    {
        Task<IEnumerable<T>> QueryAsync<T>(string sql, object param = null);
        Task<T> QuerySingleAsync<T>(string sql, object param = null);
        Task<int> ExecuteAsync(string sql, object param = null);
    }

    public class DatabaseService : IDatabaseService
    {
        private readonly string _connectionString;

        public DatabaseService(string connectionString)
        {
            _connectionString = connectionString;
        }

        private IDbConnection CreateConnection()
        {
            var connection = new OracleConnection(_connectionString);
            connection.Open();
            return connection;
        }

        public async Task<IEnumerable<T>> QueryAsync<T>(string sql, object param = null)
        {
            using var connection = CreateConnection();
            return await connection.QueryAsync<T>(sql, param);
        }

        public async Task<T> QuerySingleAsync<T>(string sql, object param = null)
        {
            using var connection = CreateConnection();
            return await connection.QuerySingleAsync<T>(sql, param);
        }

        public async Task<int> ExecuteAsync(string sql, object param = null)
        {
            using var connection = CreateConnection();
            return await connection.ExecuteAsync(sql, param);
        }
    }
}
