-- all parameters of the module:
CONF=
{
ssn =
  {ACCOUNT = 3},
app =
    {
    LOGLEVEL = "DEBUG",
    name = "Test application",
    MQTT_PORT = 1883,            --   # MQTT broker TCP port
    MQTT_HOST = "192.168.1.105", --   # host name for client connections
    MQTT_BROKER_USER = "mosquitto",
    MQTT_BROKER_PASS = "test",
    MQTT_BROKER_CLIENT_ID = "lua_client_mqtt_test2",
    WIFI_SSID = "lir",
    WIFI_PASSWORD = "password"
    },
sensors =
  {obj = 129, -- object id (mandatory attribute)
    -- bmp180 =
    --   {
    --   id = "pressure-1",
    --   period = 55000, -- timer (ms)
    --   pin_sda = 1,
    --   pin_scl = 4,
    --   oss = 2 -- oversampling setting (0-3)
    --   },
    bme280 =
    {
      id = "pressure-2",
      period = 30000, -- timer (ms)
      pin_sda = 8,
      pin_scl = 7,
      altitude = 180,
      oss = 2 -- oversampling setting (0-3)
    },
    gpio =
      {
        id = "gpio-mcu1",
        pins = {
          {
              comment = "test-led-1",
              gpiochip = 0,
              type = "out"
          },
          {
              comment = "test-button-1",
              gpiochip = 1,
              type = "int" -- generate interrupt
          },
          {
              comment = "test-in-2",
              gpiochip = 2,
              type = "in"
          }
        }
      },
    -- ds18b20 =
    --   {
    --     period = 55000, -- timer (ms)
    --     devices =
    --       {
    --         id = "floor2-201",
    --         name = "28-031551597aff",
    --         resolution = 9
    --       },
    --       {
    --         id = "floor2-202",
    --         name = "28-000004f9988f",
    --         resolution = 12
    --       }
    --   },
    -- watchdog_tcp =
    --   {destinations =
    --     {
    --       id = "ping_tcp_8.8.8.8",
    --       period = 120000, -- timer (ms)
    --       address = "8.8.8.8"
    --     },
    --     {
    --       id = "ping_tcp_router",
    --       period = 30000, -- timer (ms)
    --       address = "192.168.1.1"
    --     }
    --   }
  }
}