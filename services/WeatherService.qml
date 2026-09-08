pragma Singleton
import QtCore
import QtQuick
import Quickshell.Io
import "../core"

QtObject {
    id: root

    property bool loading: false
    property bool available: false
    property string errorMessage: ""
    property string responseBuffer: ""
    property string requestError: ""
    property date lastUpdated: new Date(0)
    property real temperature: 0
    property real apparentTemperature: 0
    property int weatherCode: -1
    property bool isDay: true
    property real highTemperature: 0
    property real lowTemperature: 0
    property int humidity: 0
    property real precipitation: 0
    property real windSpeed: 0
    property int windDirection: 0
    property real pressure: 0
    property real visibilityDistance: 0
    property int uvIndex: 0
    property int precipitationChance: 0
    property string sunrise: ""
    property string sunset: ""
    property var hourlyForecast: []
    property var forecast: []

    readonly property bool configured: Config.weather.enabled
        && Config.weather.locationName.length > 0
        && Number.isFinite(Config.weather.latitude)
        && Number.isFinite(Config.weather.longitude)
    readonly property string locationKey: Config.weather.locationName + "|"
        + Config.weather.latitude + "|" + Config.weather.longitude
    readonly property string unitSymbol:
        Config.weather.temperatureUnit === "fahrenheit" ? "°F" : "°C"
    readonly property int temperatureInt: Math.round(temperature)
    readonly property string temperatureLabel: temperatureInt + "°"
    readonly property string condition: conditionForCode(weatherCode)
    readonly property string icon: iconForCode(weatherCode, isDay)
    readonly property string highLowLabel: available
        ? "H " + Math.round(highTemperature) + "°  L "
            + Math.round(lowTemperature) + "°" : ""
    readonly property string feelsLikeLabel: available
        ? "Feels like " + Math.round(apparentTemperature) + "°" : ""
    readonly property string windLabel: Math.round(windSpeed) + " km/h "
        + compassDirection(windDirection)
    readonly property string pressureLabel: Math.round(pressure) + " hPa"
    readonly property string visibilityLabel: visibilityDistance > 0
        ? (visibilityDistance / 1000).toFixed(1) + " km" : "Unavailable"
    readonly property string statusLabel: !configured
        ? "Weather location is not configured"
        : loading ? "Updating forecast…"
        : errorMessage.length > 0 ? errorMessage : condition

    onLocationKeyChanged: {
        available = false
        loading = false
        errorMessage = ""
        if (configured)
            Qt.callLater(refresh)
    }

    function persistCache(): void {
        if (!available)
            return
        cacheFile.setText(JSON.stringify({
            location: Config.weather.locationName,
            latitude: Config.weather.latitude,
            longitude: Config.weather.longitude,
            temperature: temperature,
            apparentTemperature: apparentTemperature,
            weatherCode: weatherCode,
            highTemperature: highTemperature,
            lowTemperature: lowTemperature,
            temperatureLabel: temperatureLabel,
            condition: condition,
            icon: icon,
            isDay: isDay,
            updatedAt: lastUpdated.toISOString()
        }, null, 2))
    }

    function loadCache(raw): void {
        try {
            const cached = JSON.parse(raw)
            if (!configured || cached.location !== Config.weather.locationName
                    || Number(cached.latitude) !== Config.weather.latitude
                    || Number(cached.longitude) !== Config.weather.longitude)
                return
            const cachedTemperature = Number(cached.temperature)
            const cachedWeatherCode = Number(cached.weatherCode)
            const cachedHigh = Number(cached.highTemperature)
            const cachedLow = Number(cached.lowTemperature)
            if (!Number.isFinite(cachedTemperature)
                    || !Number.isFinite(cachedWeatherCode)
                    || !Number.isFinite(cachedHigh)
                    || !Number.isFinite(cachedLow))
                return
            temperature = cachedTemperature
            apparentTemperature = Number.isFinite(Number(cached.apparentTemperature))
                ? Number(cached.apparentTemperature) : cachedTemperature
            weatherCode = cachedWeatherCode
            isDay = cached.isDay !== false
            highTemperature = cachedHigh
            lowTemperature = cachedLow
            if (typeof cached.updatedAt === "string") {
                const cachedDate = new Date(cached.updatedAt)
                if (!isNaN(cachedDate.getTime()))
                    lastUpdated = cachedDate
            }
            available = true
        } catch (error) {
            console.warn("Odyssey WeatherService cache:", error)
        }
    }

    function requestUrl(): string {
        const current = "temperature_2m,apparent_temperature,relative_humidity_2m,"
            + "precipitation,is_day,weather_code,wind_speed_10m,wind_direction_10m,"
            + "surface_pressure,visibility"
        const hourly = "temperature_2m,precipitation_probability,weather_code,is_day"
        const daily = "weather_code,temperature_2m_max,temperature_2m_min,"
            + "precipitation_probability_max,sunrise,sunset,uv_index_max"
        return "https://api.open-meteo.com/v1/forecast?latitude="
            + Config.weather.latitude + "&longitude=" + Config.weather.longitude
            + "&current=" + current + "&hourly=" + hourly + "&daily=" + daily
            + "&temperature_unit=" + Config.weather.temperatureUnit
            + "&timezone=auto&forecast_days=7&forecast_hours=24"
    }

    function refresh(): void {
        if (!configured) {
            available = false
            loading = false
            return
        }
        if (weatherRequest.running)
            return
        loading = true
        errorMessage = ""
        requestError = ""
        responseBuffer = ""
        weatherRequest.command = ["curl", "--fail", "--silent", "--show-error",
            "--max-time", Config.weather.requestTimeout.toString(), requestUrl()]
        weatherRequest.running = true
    }

    function handleResponse(text): void {
        try {
            const payload = JSON.parse(text)
            if (payload.error || !payload.current || !payload.daily)
                throw new Error(payload.reason || "Incomplete weather response")

            const current = payload.current
            const daily = payload.daily
            temperature = Number(current.temperature_2m)
            apparentTemperature = Number(current.apparent_temperature)
            weatherCode = Number(current.weather_code)
            isDay = Number(current.is_day) === 1
            humidity = Math.round(Number(current.relative_humidity_2m))
            precipitation = Number(current.precipitation)
            windSpeed = Number(current.wind_speed_10m)
            windDirection = Math.round(Number(current.wind_direction_10m))
            pressure = Number(current.surface_pressure)
            visibilityDistance = Number(current.visibility)
            highTemperature = Number(daily.temperature_2m_max?.[0])
            lowTemperature = Number(daily.temperature_2m_min?.[0])
            precipitationChance = Math.round(Number(
                daily.precipitation_probability_max?.[0]))
            uvIndex = Math.round(Number(daily.uv_index_max?.[0]))
            sunrise = formatClock(daily.sunrise?.[0])
            sunset = formatClock(daily.sunset?.[0])

            const hourly = payload.hourly || {}
            const hours = []
            const hourTimes = hourly.time || []
            for (let index = 0; index < Math.min(hourTimes.length, 24); index++) {
                const date = new Date(hourTimes[index])
                hours.push({
                    time: index === 0 ? "Now" : Qt.formatTime(date, "HH:mm"),
                    temperature: Math.round(Number(hourly.temperature_2m?.[index])),
                    precipitation: Math.round(Number(
                        hourly.precipitation_probability?.[index]) || 0),
                    code: Number(hourly.weather_code?.[index]),
                    icon: iconForCode(Number(hourly.weather_code?.[index]),
                        Number(hourly.is_day?.[index]) === 1)
                })
            }
            hourlyForecast = hours

            const dates = daily.time || []
            const codes = daily.weather_code || []
            const highs = daily.temperature_2m_max || []
            const lows = daily.temperature_2m_min || []
            const days = []
            for (let index = 0; index < Math.min(dates.length, 7); index++) {
                const date = new Date(dates[index] + "T12:00:00")
                days.push({
                    date: dates[index],
                    day: index === 0 ? "Today" : Qt.formatDate(date, "ddd"),
                    code: Number(codes[index]),
                    icon: iconForCode(Number(codes[index]), true),
                    high: Math.round(Number(highs[index])),
                    low: Math.round(Number(lows[index])),
                    precipitation: Math.round(Number(
                        daily.precipitation_probability_max?.[index]) || 0)
                })
            }
            forecast = days
            available = Number.isFinite(temperature)
                && Number.isFinite(highTemperature) && Number.isFinite(lowTemperature)
            if (!available)
                throw new Error("Weather values were unavailable")
            lastUpdated = new Date()
            errorMessage = ""
            persistCache()
        } catch (error) {
            console.warn("Odyssey WeatherService:", error)
            errorMessage = "Forecast unavailable"
        }
        loading = false
    }

    function requestFailed(detail): void {
        loading = false
        errorMessage = detail && detail.length > 0
            ? "Weather service unavailable" : "Forecast unavailable"
    }

    function formatClock(value): string {
        if (!value)
            return "Unavailable"
        return Qt.formatTime(new Date(value), "HH:mm")
    }

    function compassDirection(degrees): string {
        if (!Number.isFinite(degrees))
            return ""
        const directions = ["N", "NE", "E", "SE", "S", "SW", "W", "NW"]
        return directions[Math.round(degrees / 45) % 8]
    }

    function conditionForCode(code): string {
        if (code === 0) return "Clear"
        if (code === 1) return "Mostly clear"
        if (code === 2) return "Partly cloudy"
        if (code === 3) return "Overcast"
        if (code === 45 || code === 48) return "Fog"
        if (code >= 51 && code <= 57) return "Drizzle"
        if (code >= 61 && code <= 67) return "Rain"
        if (code >= 71 && code <= 77) return "Snow"
        if (code >= 80 && code <= 82) return "Showers"
        if (code === 85 || code === 86) return "Snow showers"
        if (code >= 95) return "Thunderstorm"
        return "Conditions unavailable"
    }

    function iconForCode(code, daylight): string {
        if (code === 0) return daylight ? "󰖙" : "󰖔"
        if (code === 1) return daylight ? "󰖕" : "󰼱"
        if (code === 2) return "󰖐"
        if (code === 3) return "󰖐"
        if (code === 45 || code === 48) return "󰖑"
        if (code >= 51 && code <= 67) return "󰖗"
        if (code >= 71 && code <= 77) return "󰼶"
        if (code >= 80 && code <= 82) return "󰖖"
        if (code === 85 || code === 86) return "󰼶"
        if (code >= 95) return "󰙾"
        return "󰖐"
    }

    property Process weatherRequest: Process {
        id: weatherRequest
        running: false

        stdout: StdioCollector {
            onStreamFinished: {
                root.responseBuffer = text
                if (text.length > 0)
                    root.handleResponse(text)
            }
        }
        stderr: StdioCollector {
            onStreamFinished: root.requestError = text.trim()
        }
        onExited: (exitCode, exitStatus) => {
            if (exitCode !== 0)
                root.requestFailed(root.requestError)
            else if (root.loading && root.responseBuffer.length === 0)
                root.requestFailed("")
        }
    }

    property FileView cacheFile: FileView {
        path: StandardPaths.writableLocation(StandardPaths.GenericStateLocation)
            + "/odyssey/weather.json"
        blockLoading: true
        blockWrites: true
        atomicWrites: true
        printErrors: false
        onLoaded: root.loadCache(text())
    }

    property Timer startupRefresh: Timer {
        interval: 1200
        running: root.configured
        onTriggered: root.refresh()
    }

    property Timer refreshTimer: Timer {
        interval: Config.weather.refreshInterval
        running: root.configured
        repeat: true
        onTriggered: root.refresh()
    }
}
