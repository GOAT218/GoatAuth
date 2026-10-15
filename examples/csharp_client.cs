// =============================================================================
// GoatAuth — C# example client (.NET 6+, System.Net.Http + System.Text.Json)
// =============================================================================
//
// This is an EXAMPLE showing how to authenticate YOUR OWN software against a
// GoatAuth server. Embed this kind of logic in the .NET app you distribute; it
// talks to the GoatAuth client API at /api/v1/*.
//
// Every endpoint is a POST with a JSON body that always includes your app_id
// and secret (from your app's dashboard page), plus endpoint-specific fields.
//
// Every response is JSON with a boolean "success" flag:
//   * On success  -> { "success": true, ...fields }
//   * On failure  -> { "success": false, "message": "...", "code": "..." }
//
// The important response fields:
//   token   : opaque session token; store it and pass it back to Verify()
//   user    : {
//               username:          string,
//               level:             number,          // subscription tier
//               expires_at:        number | null,   // epoch MILLISECONDS, null = lifetime
//               expires_iso:       string | null,   // ISO-8601 timestamp, null = lifetime
//               seconds_remaining: number | null,   // null = lifetime
//               lifetime:          boolean,
//               created_at:        number           // epoch MILLISECONDS
//             }
//   version : {
//               outdated:     boolean,              // true if your version != latest
//               latest:       string,               // newest published version
//               download_url: string | null         // where to grab the update
//             }
//
// NOTE: Anything you ship can be reverse-engineered, so do not treat the
// client-side "secret" as truly secret. GoatAuth's real protection is
// server-side (key consumption, HWID locking, bans, expiry). The secret lives
// in this file purely for a clear, self-contained example.
//
// Compile & run (single file):
//   dotnet run   (inside a console project containing this file)
// =============================================================================

using System;
using System.Net.Http;
using System.Security.Cryptography;
using System.Text;
using System.Text.Json;
using System.Text.Json.Serialization;
using System.Threading.Tasks;

namespace GoatAuthExample
{
    // --- Strongly-typed response models -------------------------------------
    // Only the fields we care about are declared; unknown fields are ignored.

    public sealed class VersionInfo
    {
        [JsonPropertyName("outdated")] public bool Outdated { get; set; }
        [JsonPropertyName("latest")] public string Latest { get; set; } = "";
        [JsonPropertyName("download_url")] public string? DownloadUrl { get; set; }
    }

    public sealed class UserInfo
    {
        [JsonPropertyName("username")] public string Username { get; set; } = "";
        [JsonPropertyName("level")] public int Level { get; set; }
        [JsonPropertyName("expires_at")] public long? ExpiresAt { get; set; }
        [JsonPropertyName("expires_iso")] public string? ExpiresIso { get; set; }
        [JsonPropertyName("seconds_remaining")] public long? SecondsRemaining { get; set; }
        [JsonPropertyName("lifetime")] public bool Lifetime { get; set; }
        [JsonPropertyName("created_at")] public long CreatedAt { get; set; }
    }

    public sealed class AuthResponse
    {
        [JsonPropertyName("success")] public bool Success { get; set; }
        [JsonPropertyName("message")] public string? Message { get; set; }
        [JsonPropertyName("code")] public string? Code { get; set; }

        [JsonPropertyName("token")] public string? Token { get; set; }
        [JsonPropertyName("session_id")] public string? SessionId { get; set; }
        [JsonPropertyName("user")] public UserInfo? User { get; set; }
        [JsonPropertyName("version")] public VersionInfo? Version { get; set; }
    }

    // --- The client ----------------------------------------------------------
    public static class GoatAuth
    {
        // Point this at your GoatAuth server. In production use https://your-domain.
        private const string BaseUrl = "http://localhost:3000";

        // Replace these with the values shown on your app's dashboard page.
        private const string AppId = "your-app-id-here";
        private const string Secret = "your-app-secret-here";

        // The version string of THIS build of your software.
        private const string AppVersion = "1.0";

        private static readonly HttpClient Http = new HttpClient();

        private static readonly JsonSerializerOptions JsonOpts = new JsonSerializerOptions
        {
            PropertyNameCaseInsensitive = true,
        };

        // --- Hardware ID -----------------------------------------------------
        /// <summary>
        /// Compute a stable-ish hardware identifier for this machine.
        /// We hash MachineName + UserName so raw machine details never leave the
        /// device. This is 'good enough' for a demo; production clients usually
        /// mix in more entropy (disk serials, MAC address, WMI machine GUID).
        /// </summary>
        public static string GetHwid()
        {
            string raw = string.Join(
                "|",
                Environment.MachineName,
                Environment.UserName,
                Environment.OSVersion.Platform.ToString());

            byte[] hash = SHA256.HashData(Encoding.UTF8.GetBytes(raw));
            return Convert.ToHexString(hash).ToLowerInvariant();
        }

        // --- Low-level HTTP helper ------------------------------------------
        /// <summary>
        /// POST a JSON body to /api/v1/{endpoint}. Always injects app_id + secret.
        /// Reads the response as JSON regardless of HTTP status (GoatAuth returns
        /// a JSON error envelope on failures too), so callers rely on the
        /// Success flag rather than catching HTTP exceptions.
        /// </summary>
        private static async Task<AuthResponse> PostAsync(string endpoint, object fields)
        {
            // Merge app identity with the endpoint-specific fields into one object.
            var payload = new System.Collections.Generic.Dictionary<string, object?>
            {
                ["app_id"] = AppId,
                ["secret"] = Secret,
            };
            foreach (var prop in fields.GetType().GetProperties())
            {
                payload[prop.Name] = prop.GetValue(fields);
            }

            string json = JsonSerializer.Serialize(payload);
            using var content = new StringContent(json, Encoding.UTF8, "application/json");

            try
            {
                using HttpResponseMessage resp =
                    await Http.PostAsync($"{BaseUrl}/api/v1/{endpoint}", content);
                string respBody = await resp.Content.ReadAsStringAsync();
                return JsonSerializer.Deserialize<AuthResponse>(respBody, JsonOpts)
                       ?? new AuthResponse { Success = false, Message = "Empty response" };
            }
            catch (Exception ex)
            {
                return new AuthResponse
                {
                    Success = false,
                    Message = $"Network error: {ex.Message}",
                    Code = "network_error",
                };
            }
        }

        // --- Public API ------------------------------------------------------

        /// <summary>Handshake + update check. Call this at startup.</summary>
        public static Task<AuthResponse> Init() =>
            PostAsync("init", new { version = AppVersion });

        /// <summary>Create a new user, consuming a license key.</summary>
        public static Task<AuthResponse> Register(
            string username, string password, string key, string hwid) =>
            PostAsync("register", new { username, password, key, hwid });

        /// <summary>Authenticate an existing username/password.</summary>
        public static Task<AuthResponse> Login(string username, string password, string hwid) =>
            PostAsync("login", new { username, password, hwid });

        /// <summary>License-only auth: the key itself is the credential.</summary>
        public static Task<AuthResponse> License(string key, string hwid) =>
            PostAsync("license", new { key, hwid });

        /// <summary>Re-check a previously issued token is still valid.</summary>
        public static Task<AuthResponse> Verify(string token, string hwid) =>
            PostAsync("verify", new { token, hwid });
    }

    // --- Demo ----------------------------------------------------------------
    public static class Program
    {
        private static void PrintUser(UserInfo? user)
        {
            if (user is null)
            {
                Console.WriteLine("  (no user attached to this session)");
                return;
            }
            Console.WriteLine($"  username          : {user.Username}");
            Console.WriteLine($"  level             : {user.Level}");
            if (user.Lifetime)
            {
                Console.WriteLine("  subscription      : LIFETIME (never expires)");
            }
            else
            {
                Console.WriteLine($"  expires (iso)     : {user.ExpiresIso}");
                Console.WriteLine($"  seconds remaining : {user.SecondsRemaining}");
            }
        }

        public static async Task Main()
        {
            string hwid = GoatAuth.GetHwid();
            Console.WriteLine($"HWID: {hwid}\n");

            // 1) Handshake + update check.
            Console.WriteLine("== init ==");
            AuthResponse res = await GoatAuth.Init();
            if (!res.Success)
            {
                Console.WriteLine($"init failed: {res.Message} (code={res.Code})");
                return;
            }
            VersionInfo version = res.Version!;
            Console.WriteLine($"  latest version    : {version.Latest}");
            Console.WriteLine($"  outdated          : {version.Outdated}");
            if (version.Outdated)
            {
                Console.WriteLine($"  download update   : {version.DownloadUrl}");
            }
            Console.WriteLine();

            // 2) Log in with sample credentials (swap for real ones / a UI prompt).
            Console.WriteLine("== login ==");
            res = await GoatAuth.Login("sample_user", "sample_password", hwid);
            if (!res.Success)
            {
                Console.WriteLine($"login failed: {res.Message} (code={res.Code})");
                return;
            }
            string token = res.Token!;
            Console.WriteLine("  login OK, subscription:");
            PrintUser(res.User);
            Console.WriteLine();

            // 3) Verify the token we just received.
            Console.WriteLine("== verify ==");
            res = await GoatAuth.Verify(token, hwid);
            if (!res.Success)
            {
                Console.WriteLine($"verify failed: {res.Message} (code={res.Code})");
                return;
            }
            Console.WriteLine("  token is valid, subscription:");
            PrintUser(res.User);
        }
    }
}
