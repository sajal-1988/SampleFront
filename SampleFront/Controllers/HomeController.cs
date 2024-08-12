using Microsoft.AspNetCore.Mvc;
using Microsoft.Build.Tasks.Deployment.Bootstrapper;
using Microsoft.Extensions.Configuration;
using Newtonsoft.Json;
using SampleFront.Models;
using System.Diagnostics;

namespace SampleFront.Controllers
{
    public class HomeController : Controller
    {
        private readonly ILogger<HomeController> _logger;
        private IConfiguration iconfig;
        static HttpClient client = new HttpClient();


        public HomeController(ILogger<HomeController> logger, IConfiguration iconfig)
        {
            _logger = logger;
            this.iconfig = iconfig;
        }

        public IActionResult Index()
        {
            List<WeatherForecast> weatherForecasts = new List<WeatherForecast>();
            try
            {
                string apiurl = iconfig.GetSection("SajalSettings").GetSection("ApiUrl").Value;
                apiurl = apiurl + "weatherforecast";

                weatherForecasts = GetWeatherForecastAsync(apiurl).GetAwaiter().GetResult();
            }
            catch (Exception ex)
            {
                weatherForecasts.Add(new WeatherForecast()
                {
                    Date = DateOnly.MinValue,
                    Summary = ex.Message,
                    TemperatureC = 32,
                    TemperatureF = 39
                });
            }


            return View(weatherForecasts);
        }


        public IActionResult Privacy()
        {
            return View();
        }

        [ResponseCache(Duration = 0, Location = ResponseCacheLocation.None, NoStore = true)]
        public IActionResult Error()
        {
            return View(new ErrorViewModel { RequestId = Activity.Current?.Id ?? HttpContext.TraceIdentifier });
        }

        private async Task<List<WeatherForecast>> GetWeatherForecastAsync(string path)
        {
            List<WeatherForecast> forecast = new List<WeatherForecast>();
            HttpResponseMessage response = await client.GetAsync(path);
            if (response.IsSuccessStatusCode)
            {
                var result = await response.Content.ReadAsStringAsync();
                forecast = JsonConvert.DeserializeObject<List<WeatherForecast>>(result);
            }

            return forecast;
        }
    }
}
