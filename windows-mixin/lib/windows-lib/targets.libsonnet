local g = import './g.libsonnet';
local prometheusQuery = g.query.prometheus;
local lokiQuery = g.query.loki;

{
  new(this): {
    local variables = this.variables,
    local config = this.config,
    uptimeQuery:: 'windows_system_system_up_time',

    reboot:
      prometheusQuery.new(
        '${' + this.variables.datasources.prometheus.name + '}',
        self.uptimeQuery + '{%(queriesSelector)s}*1000 > $__from < $__to' % variables,
      ),
    serviceFailed:
      lokiQuery.new(
        '${' + this.variables.datasources.loki.name + '}',
        '{%(queriesSelector)s, source="Service Control Manager", level="Error"} |= "terminated" | json' % variables
      ),
    // those events should be rare, so can be shown as annotations
    criticalEvents:
      lokiQuery.new(
        '${' + this.variables.datasources.loki.name + '}',
        '{%(queriesSelector)s, channel="System", level="Critical"} | json' % variables
      ),
    alertsCritical:
      prometheusQuery.new(
        '${' + this.variables.datasources.prometheus.name + '}',
        'count by (%(instanceLabels)s) (max_over_time(ALERTS{%(queriesSelector)s, alertstate="firing", severity="critical"}[1m])) * group by (%(instanceLabels)s) (windows_os_info{%(queriesSelector)s})' % variables { instanceLabels: std.join(',', this.config.instanceLabels) },
      ),
    alertsWarning:
      prometheusQuery.new(
        '${' + this.variables.datasources.prometheus.name + '}',
        'count by (%(instanceLabels)s) (max_over_time(ALERTS{%(queriesSelector)s, alertstate="firing", severity="warning"}[1m])) * group by (%(instanceLabels)s) (windows_os_info{%(queriesSelector)s})' % variables { instanceLabels: std.join(',', this.config.instanceLabels) },
      ),

    uptime:
      prometheusQuery.new(
        '${' + this.variables.datasources.prometheus.name + '}',
        'time() - ' + self.uptimeQuery + '{%(queriesSelector)s}' % variables
      ),
    cpuCount:
      prometheusQuery.new(
        '${' + this.variables.datasources.prometheus.name + '}',
        'windows_cs_logical_processors{%(queriesSelector)s}' % variables
      ),
    cpuUsage:
      prometheusQuery.new(
        '${' + this.variables.datasources.prometheus.name + '}',
        '100 - (avg by (instance) (rate(windows_cpu_time_total{mode="idle", %(queriesSelector)s}[$__rate_interval])*100))' % variables
      )
      + prometheusQuery.withLegendFormat('CPU usage'),
    cpuUsageByMode:
      prometheusQuery.new(
        '${' + this.variables.datasources.prometheus.name + '}',
        |||
          sum by(instance, mode) (irate(windows_cpu_time_total{%(queriesSelector)s}[$__rate_interval])) 
          / on(instance) 
          group_left sum by (instance)((irate(windows_cpu_time_total{%(queriesSelector)s}[$__rate_interval]))) * 100
        ||| % variables
      )
      + prometheusQuery.withLegendFormat('{{ mode }}'),

    // https://learn.microsoft.com/en-us/previous-versions/windows/it-pro/windows-2000-server/cc940375(v=technet.10)?redirectedfrom=MSDN
    cpuQueue:
      prometheusQuery.new(
        '${' + this.variables.datasources.prometheus.name + '}',
        |||
          windows_system_processor_queue_length{%(queriesSelector)s}
        ||| % variables
      )
      + prometheusQuery.withLegendFormat('CPU average queue'),

    memoryTotalBytes:
      prometheusQuery.new(
        '${' + this.variables.datasources.prometheus.name + '}',
        'windows_cs_physical_memory_bytes{%(queriesSelector)s}' % variables
      )
      + prometheusQuery.withLegendFormat('Memory total'),
    memoryFreeBytes:
      prometheusQuery.new(
        '${' + this.variables.datasources.prometheus.name + '}',
        'windows_os_physical_memory_free_bytes{%(queriesSelector)s}' % variables
      )
      + prometheusQuery.withLegendFormat('Memory free'),
    memoryUsedBytes:
      prometheusQuery.new(
        '${' + this.variables.datasources.prometheus.name + '}',
        'windows_cs_physical_memory_bytes{%(queriesSelector)s} - windows_os_physical_memory_free_bytes{%(queriesSelector)s}' % variables
      )
      + prometheusQuery.withLegendFormat('Memory used'),
    memoryUsagePercent:
      prometheusQuery.new(
        '${' + this.variables.datasources.prometheus.name + '}',
        '100 - windows_os_physical_memory_free_bytes{%(queriesSelector)s} / windows_cs_physical_memory_bytes{%(queriesSelector)s} * 100' % variables
      ),
    memoryPageTotalBytes:
      prometheusQuery.new(
        '${' + this.variables.datasources.prometheus.name + '}',
        'windows_os_paging_limit_bytes{%(queriesSelector)s}' % variables
      ),
    diskTotal:
      prometheusQuery.new(
        '${' + this.variables.datasources.prometheus.name + '}',
        'windows_logical_disk_size_bytes{volume!~"%(ignoreVolumes)s", %(queriesSelector)s}' % variables { ignoreVolumes: config.ignoreVolumes }
      ),
    diskTotalC:
      prometheusQuery.new(
        '${' + this.variables.datasources.prometheus.name + '}',
        'windows_logical_disk_size_bytes{volume="C:", %(queriesSelector)s}' % variables
      ),
    diskUsageC:
      prometheusQuery.new(
        '${' + this.variables.datasources.prometheus.name + '}',
        'windows_logical_disk_size_bytes{volume="C:", %(queriesSelector)s}-windows_logical_disk_free_bytes{volume="C:", %(queriesSelector)s}' % variables
      ),
    diskUsageCPercent:
      prometheusQuery.new(
        '${' + this.variables.datasources.prometheus.name + '}',
        '100 - windows_logical_disk_free_bytes{volume="C:", %(queriesSelector)s}/windows_logical_disk_size_bytes{volume="C:", %(queriesSelector)s}*100' % variables
      ),
    diskUsage:
      prometheusQuery.new(
        '${' + this.variables.datasources.prometheus.name + '}',
        'windows_logical_disk_size_bytes{volume!~"%(ignoreVolumes)s", %(queriesSelector)s}-windows_logical_disk_free_bytes{volume!~"%(ignoreVolumes)s", %(queriesSelector)s}' % variables { ignoreVolumes: config.ignoreVolumes }
      ),
    diskUsagePercent:
      prometheusQuery.new(
        '${' + this.variables.datasources.prometheus.name + '}',
        '100 - windows_logical_disk_free_bytes{volume!~"%(ignoreVolumes)s", %(queriesSelector)s}/windows_logical_disk_size_bytes{volume!~"%(ignoreVolumes)s", %(queriesSelector)s}*100' % variables { ignoreVolumes: config.ignoreVolumes }
      ),
    diskIOreadBytesPerSec:
      prometheusQuery.new(
        '${' + this.variables.datasources.prometheus.name + '}',
        'irate(windows_logical_disk_read_bytes_total{volume!~"%(ignoreVolumes)s", %(queriesSelector)s}[$__rate_interval])' % variables { ignoreVolumes: config.ignoreVolumes }
      )
      + prometheusQuery.withLegendFormat('{{ volume }} read'),
    diskIOwriteBytesPerSec:
      prometheusQuery.new(
        '${' + this.variables.datasources.prometheus.name + '}',
        'irate(windows_logical_disk_write_bytes_total{volume!~"%(ignoreVolumes)s", %(queriesSelector)s}[$__rate_interval])' % variables { ignoreVolumes: config.ignoreVolumes }
      )
      + prometheusQuery.withLegendFormat('{{ volume }} written'),
    diskIOutilization:
      prometheusQuery.new(
        '${' + this.variables.datasources.prometheus.name + '}',
        '(1-clamp_max(irate(windows_logical_disk_idle_seconds_total{volume!~"%(ignoreVolumes)s", %(queriesSelector)s}[$__rate_interval]),1)) * 100' % variables { ignoreVolumes: config.ignoreVolumes }
      )
      + prometheusQuery.withLegendFormat('{{ volume }} io util'),
    osInfo:
      prometheusQuery.new(
        '${' + this.variables.datasources.prometheus.name + '}',
        'windows_os_info{%(queriesSelector)s}' % variables,
      )
      + prometheusQuery.withFormat('table'),

    osTimezone:  //timezone label
      prometheusQuery.new(
        '${' + this.variables.datasources.prometheus.name + '}',
        'windows_os_timezone{%(queriesSelector)s}' % variables,
      )
      + prometheusQuery.withFormat('table'),
    systemContextSwitches:
      prometheusQuery.new(
        '${' + this.variables.datasources.prometheus.name + '}',
        'irate(windows_system_context_switches_total{%(queriesSelector)s}[$__rate_interval])' % variables,
      )
      + prometheusQuery.withLegendFormat('Context switches'),
    systemInterrupts:
      prometheusQuery.new(
        '${' + this.variables.datasources.prometheus.name + '}',
        'sum without (core) (irate(windows_cpu_interrupts_total{%(queriesSelector)s}[$__rate_interval]))' % variables,
      )
      + prometheusQuery.withLegendFormat('Interrupts'),

    timeNtpStatus:
      prometheusQuery.new(
        '${' + this.variables.datasources.prometheus.name + '}',
        'clamp_max(windows_time_ntp_client_time_sources{%(queriesSelector)s}, 1)' % variables,
      )
      + prometheusQuery.withLegendFormat('NTP status'),


    networkOutBitPerSec:
      prometheusQuery.new(
        '${' + this.variables.datasources.prometheus.name + '}',
        'irate(windows_net_bytes_sent_total{%(queriesSelector)s}[$__rate_interval])*8' % variables
      )
      + prometheusQuery.withLegendFormat('{{ nic }} transmitted'),
    networkInBitPerSec:
      prometheusQuery.new(
        '${' + this.variables.datasources.prometheus.name + '}',
        'irate(windows_net_bytes_received_total{%(queriesSelector)s}[$__rate_interval])*8' % variables
      )
      + prometheusQuery.withLegendFormat('{{ nic }} received'),
    networkOutErrorsPerSec:
      prometheusQuery.new(
        '${' + this.variables.datasources.prometheus.name + '}',
        'irate(windows_net_packets_outbound_errors_total{%(queriesSelector)s}[$__rate_interval])' % variables
      )
      + prometheusQuery.withLegendFormat('{{ nic }} transmitted'),
    networkInErrorsPerSec:
      prometheusQuery.new(
        '${' + this.variables.datasources.prometheus.name + '}',
        'irate(windows_net_packets_received_errors_total{%(queriesSelector)s}[$__rate_interval])' % variables
      )
      + prometheusQuery.withLegendFormat('{{ nic }} received'),
    networkInUknownPerSec:
      prometheusQuery.new(
        '${' + this.variables.datasources.prometheus.name + '}',
        'irate(windows_net_packets_received_unknown_total{%(queriesSelector)s}[$__rate_interval])' % variables
      )
      + prometheusQuery.withLegendFormat('{{ nic }} received (unknown)'),
    networkOutDroppedPerSec:
      prometheusQuery.new(
        '${' + this.variables.datasources.prometheus.name + '}',
        'irate(windows_net_packets_outbound_discarded_total{%(queriesSelector)s}[$__rate_interval])' % variables
      )
      + prometheusQuery.withLegendFormat('{{ nic }} transmitted packets dropped'),
    networkInDroppedPerSec:
      prometheusQuery.new(
        '${' + this.variables.datasources.prometheus.name + '}',
        'irate(windows_net_packets_received_discarded_total{%(queriesSelector)s}[$__rate_interval])' % variables
      )
      + prometheusQuery.withLegendFormat('{{ nic }} received packets dropped'),

    networkInPacketsPerSec:
      prometheusQuery.new(
        '${' + this.variables.datasources.prometheus.name + '}',
        'irate(windows_net_packets_received_total{%(queriesSelector)s}[$__rate_interval])' % variables
      )
      + prometheusQuery.withLegendFormat('{{ nic }} received'),
    networkOutPacketsPerSec:
      prometheusQuery.new(
        '${' + this.variables.datasources.prometheus.name + '}',
        'irate(windows_net_packets_sent_total{%(queriesSelector)s}[$__rate_interval])' % variables
      )
      + prometheusQuery.withLegendFormat('{{ nic }} transmitted'),
    // TODO remove
    networkMulticast:
      prometheusQuery.new(
        '${' + this.variables.datasources.prometheus.name + '}',
        'x{%(queriesSelector)s}' % variables
      ),
  },
}
