[![Build Status](https://travis-ci.org/EasyMile/logger_logstash_backend.svg)](https://travis-ci.org/EasyMile/logger_logstash_backend)

LoggerLogstashBackend
=====================

## About
A backend for the [Elixir Logger](http://elixir-lang.org/docs/v1.0/logger/Logger.html)
that will send logs to the [Logstash UDP input](https://www.elastic.co/guide/en/logstash/current/plugins-inputs-udp.html).

## Supported options

 * **host**: String.t. The hostname or ip address where to send the logs.
 * **port**: Integer. The port number. Logstash should be listening with its UDP
 inputter.
 * **metadata**: Keyword.t. Extra fields to be added when sending the logs. These will
 be merged with the metadata sent in every log message.
 * **level**: Atom. Minimum level for this backend.
 * **type**: String.t. Type of logs. Useful to filter in logstash.
 * **version**: String.t. Version of logs. Useful to filter in logstash.

The host and port can be defined as environment variables as well using the ```{:system, "ENV_VAR_NAME"}``` convention

## Sample Logstash config
```
input {
  udp {
    codec => json
    port => 10001
    queue_size => 10000
    workers => 10
    type => default_log_type
  }
}
output {
  stdout {}
  elasticsearch {
    protocol => http
  }
}
```

## Using it with Mix

To use it in your Mix projects, first add it as a dependency:

```elixir
def deps do
  [{:logger_logstash_backend, "~> 3.0.0"}]
end
```
Then run mix deps.get to install it.

Add logger as applications:

```elixir
def application do
  [applications: [:logger]]
end
```

## Configuration Examples

### Runtime

```elixir
Logger.add_backend {LoggerLogstashBackend, :debug}
Logger.configure {LoggerLogstashBackend, :debug},
  host: "127.0.0.1",
  port: 10001,
  level: :debug,
  metadata: ...
```

### Application config

```elixir
config :logger,
  backends: [{LoggerLogstashBackend, :error_log}, :console]

config :logger, :error_log,
  host: "some.host.com",
  port: 10001,
  level: :error,
  type: "my_type_of_app_or_node",
  version: "my_version_of_app_or_node",
  metadata: [
    extra_fields: "go here"
  ]
```

or


```elixir
config :logger,
  backends: [{LoggerLogstashBackend, :error_log}, :console]

config :logger, :error_log,
  host: {:system, "LOGSTASH_BACKEND_HOST"},
  port: {:system, "LOGSTASH_BACKEND_PORT"},
  level: :error,
  type: "my_type_of_app_or_node",
  version: "my_version_of_app_or_node",
  metadata: [
    extra_fields: "go here"
  ]
```

