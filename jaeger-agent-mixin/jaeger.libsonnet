local k = import 'ksonnet-util/kausal.libsonnet';

{
  _config+:: {
    cluster: error 'Must define a cluster',
    namespace: error 'Must define a namespace',
    jaeger_agent_host: null,
  },

  local container = k.core.v1.container,

  jaeger_env_map::
    if $._config.jaeger_agent_host == null then {}
    else {
      JAEGER_AGENT_HOST: $._config.jaeger_agent_host,
      JAEGER_TAGS: 'namespace=%s,cluster=%s' % [$._config.namespace, $._config.cluster],
      JAEGER_SAMPLER_MANAGER_HOST_PORT: 'http://%s:5778/sampling' % $._config.jaeger_agent_host,
    },

  jaeger_mixin::
    if std.length($.jaeger_env_map) > 0
    then container.withEnvMap($.jaeger_env_map)
    else {},
}
