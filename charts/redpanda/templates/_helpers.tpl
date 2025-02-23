{{/*
Licensed to the Apache Software Foundation (ASF) under one or more
contributor license agreements.  See the NOTICE file distributed with
this work for additional information regarding copyright ownership.
The ASF licenses this file to You under the Apache License, Version 2.0
(the "License"); you may not use this file except in compliance with
the License.  You may obtain a copy of the License at

   http://www.apache.org/licenses/LICENSE-2.0

Unless required by applicable law or agreed to in writing, software
distributed under the License is distributed on an "AS IS" BASIS,
WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
See the License for the specific language governing permissions and
limitations under the License.
*/}}
{{/*
Expand the name of the chart.
*/}}
{{- define "redpanda.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Create a default fully qualified app name.
We truncate at 63 chars because some Kubernetes name fields are limited to this (by the DNS naming spec).
*/}}
{{- define "redpanda.fullname" -}}
{{- if .Values.fullnameOverride }}
{{- .Values.fullnameOverride | trunc 63 | trimSuffix "-" }}
{{- else }}
{{- printf "%s" .Release.Name | trunc 63 | trimSuffix "-" }}
{{- end }}
{{- end }}

{{/*
Create chart name and version as used by the chart label.
*/}}
{{- define "redpanda.chart" -}}
{{- printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Get the version of redpanda being used as an image
*/}}
{{- define "redpanda.semver" -}}
{{ include "redpanda.tag" . | trimPrefix "v" }}
{{- end }}

{{/*
Create the name of the service account to use
*/}}
{{- define "redpanda.serviceAccountName" -}}
{{- if .Values.serviceAccount.create }}
{{- default (include "redpanda.fullname" .) .Values.serviceAccount.name }}
{{- else }}
{{- default "default" .Values.serviceAccount.name }}
{{- end }}
{{- end }}

{{/*
Use AppVersion if image.tag is not set
*/}}
{{- define "redpanda.tag" -}}
{{- $tag := default .Chart.AppVersion .Values.image.tag -}}
{{- $matchString := "^v(0|[1-9]\\d*)\\.(0|[1-9]\\d*)\\.(0|[1-9]\\d*)(?:-((?:0|[1-9]\\d*|\\d*[a-zA-Z-][0-9a-zA-Z-]*)(?:\\.(?:0|[1-9]\\d*|\\d*[a-zA-Z-][0-9a-zA-Z-]*))*))?(?:\\+([0-9a-zA-Z-]+(?:\\.[0-9a-zA-Z-]+)*))?$" -}}
{{- $match := mustRegexMatch $matchString $tag -}}
{{- if not $match -}}
  {{/*
  This error message is for end users. This can also occur if
  AppVersion doesn't start with a 'v' in Chart.yaml.
  */}}
  {{ fail "image.tag must start with a 'v' and be valid semver" }}
{{- end -}}
{{- $tag -}}
{{- end -}}

{{/*
Generate configuration needed for rpk
*/}}

{{- define "redpanda.internal.domain" -}}
{{- $service := include "redpanda.fullname" . -}}
{{- $ns := .Release.Namespace -}}
{{- $domain := .Values.clusterDomain | trimSuffix "." -}}
{{- printf "%s.%s.svc.%s." $service $ns $domain -}}
{{- end -}}

{{/* ConfigMap variables */}}
{{- define "admin-internal-tls-enabled" -}}
{{- $listener := .Values.listeners.admin -}}
{{- toJson (dict "bool" (and (dig "tls" "enabled" .Values.tls.enabled $listener) (not (empty (dig "tls" "cert" "" $listener))))) -}}
{{- end -}}

{{- define "kafka-internal-tls-enabled" -}}
{{- $listener := .Values.listeners.kafka -}}
{{- toJson (dict "bool" (and (dig "tls" "enabled" .Values.tls.enabled $listener) (not (empty (dig "tls" "cert" "" $listener))))) -}}
{{- end -}}

{{- define "kafka-external-tls-enabled" -}}
{{- toJson (dict "bool" (and (dig "tls" "enabled" (include "kafka-internal-tls-enabled" . | fromJson).bool .listener) (not (empty (include "kafka-external-tls-cert" .))))) -}}
{{- end -}}

{{- define "kafka-external-tls-cert" -}}
{{- dig "tls" "cert" .Values.listeners.kafka.tls.cert .listener -}}
{{- end -}}

{{- define "http-internal-tls-enabled" -}}
{{- $listener := .Values.listeners.http -}}
{{- toJson (dict "bool" (and (dig "tls" "enabled" .Values.tls.enabled $listener) (not (empty (dig "tls" "cert" "" $listener))))) -}}
{{- end -}}

{{- define "http-external-tls-enabled" -}}
{{- $tlsEnabled := dig "tls" "enabled" (include "http-internal-tls-enabled" . | fromJson).bool .listener -}}
{{- toJson (dict "bool" (and $tlsEnabled (not (empty (include "http-external-tls-cert" .))))) -}}
{{- end -}}

{{- define "http-external-tls-cert" -}}
{{- dig "tls" "cert" .Values.listeners.http.tls.cert .listener -}}
{{- end -}}

{{- define "rpc-tls-enabled" -}}
{{- $listener := .Values.listeners.rpc -}}
{{- toJson (dict "bool" (and (dig "tls" "enabled" .Values.tls.enabled $listener) (not (empty (dig "tls" "cert" "" $listener))))) -}}
{{- end -}}

{{- define "schemaRegistry-internal-tls-enabled" -}}
{{- $listener := .Values.listeners.schemaRegistry -}}
{{- toJson (dict "bool" (and (dig "tls" "enabled" .Values.tls.enabled $listener) (not (empty (dig "tls" "cert" "" $listener))))) -}}
{{- end -}}

{{- define "schemaRegistry-external-tls-enabled" -}}
{{- $tlsEnabled := dig "tls" "enabled" (include "schemaRegistry-internal-tls-enabled" . | fromJson).bool .listener -}}
{{- toJson (dict "bool" (and $tlsEnabled (not (empty (include "schemaRegistry-external-tls-cert" .))))) -}}
{{- end -}}

{{- define "schemaRegistry-external-tls-cert" -}}
{{- dig "tls" "cert" .Values.listeners.schemaRegistry.tls.cert .listener -}}
{{- end -}}

{{- define "tls-enabled" -}}
{{- $tlsenabled := .Values.tls.enabled -}}
{{- if not $tlsenabled -}}
  {{- range $listener := .Values.listeners -}}
    {{- if and
        (dig "tls" "enabled" false $listener)
        (not (empty (dig "tls" "cert" "" $listener )))
    -}}
      {{- $tlsenabled = true -}}
    {{- end -}}
    {{- if not $tlsenabled -}}
      {{- range $external := $listener.external -}}
        {{- if and
            (dig "tls" "enabled" false $external)
            (not (empty (dig "tls" "cert" "" $external)))
          -}}
          {{- $tlsenabled = true -}}
        {{- end -}}
      {{- end -}}
    {{- end -}}
  {{- end -}}
{{- end -}}
{{- toJson (dict "bool" $tlsenabled) -}}
{{- end -}}

{{- define "sasl-enabled" -}}
{{- toJson (dict "bool" (dig "enabled" false .Values.auth.sasl)) -}}
{{- end -}}

{{- define "SI-to-bytes" -}}
  {{/*
  This template converts the incoming SI value to whole number bytes.
  Input can be: b | B | k | K | m | M | g | G | Ki | Mi | Gi
  */}}
  {{- $si := . -}}
  {{- $bytes := 0 -}}
  {{- if or (hasSuffix "B" $si) (hasSuffix "b" $si) -}}
    {{- $bytes = $si | trimSuffix "B" | trimSuffix "b" | float64 | floor -}}
  {{- else if or (hasSuffix "K" $si) (hasSuffix "k" $si) -}}
    {{- $raw := $si | trimSuffix "K" | trimSuffix "k" | float64 -}}
    {{- $bytes = mulf $raw (mul 1000) | floor -}}
  {{- else if or (hasSuffix "M" $si) (hasSuffix "m" $si) -}}
    {{- $raw := $si | trimSuffix "M" | trimSuffix "m" | float64 -}}
    {{- $bytes = mulf $raw (mul 1000 1000) | floor -}}
  {{- else if or (hasSuffix "G" $si) (hasSuffix "g" $si) -}}
    {{- $raw := $si | trimSuffix "G" | trimSuffix "g" | float64 -}}
    {{- $bytes = mulf $raw (mul 1000 1000 1000) | floor -}}
  {{- else if hasSuffix "Ki" $si -}}
    {{- $raw := $si | trimSuffix "Ki" | float64 -}}
    {{- $bytes = mulf $raw (mul 1024) | floor -}}
  {{- else if hasSuffix "Mi" $si -}}
    {{- $raw := $si | trimSuffix "Mi" | float64 -}}
    {{- $bytes = mulf $raw (mul 1024 1024) | floor -}}
  {{- else if hasSuffix "Gi" $si -}}
    {{- $raw := $si | trimSuffix "Gi" | float64 -}}
    {{- $bytes = mulf $raw (mul 1024 1024 1024) | floor -}}
  {{- else -}}
    {{- printf "\n%s is invalid SI quantity\nSuffixes can be: b | B | k | K | m | M | g | G | Ki | Mi | Gi" $si | fail -}}
  {{- end -}}
  {{- $bytes | int64 -}}
{{- end -}}

{{/* Resource variables */}}
{{- define "redpanda-memoryToMi" -}}
  {{/*
  This template converts the incoming memory value to whole number mebibytes.
  */}}
  {{- div (include "SI-to-bytes" .) (mul 1024 1024) -}}
{{- end -}}

{{- define "container-memory" -}}
  {{- $result := "" -}}
  {{- if (hasKey .Values.resources.memory.container "min") -}}
    {{- $result = .Values.resources.memory.container.min | include "redpanda-memoryToMi" -}}
  {{- else -}}
    {{- $result = .Values.resources.memory.container.max | include "redpanda-memoryToMi" -}}
  {{- end -}}
  {{- if eq $result "" -}}
    {{- "unable to get memory value" | fail -}}
  {{- end -}}
  {{- $result -}}
{{- end -}}

{{- define "external-nodeport-enabled" -}}
{{- $values := .Values -}}
{{- $enabled := and .Values.external.enabled (eq .Values.external.type "NodePort") -}}
{{- range $listener := .Values.listeners -}}
  {{- range $external := $listener.external -}}
    {{- if and (dig "enabled" false $external) (eq (dig "type" $values.external.type $external) "NodePort") -}}
      {{- $enabled = true -}}
    {{- end -}}
  {{- end -}}
{{- end -}}
{{- toJson (dict "bool" $enabled) -}}
{{- end -}}

{{- define "redpanda-reserve-memory" -}}
  {{/*
  Determines the value of --reserve-memory flag (in mebibytes with M suffix, per Seastar).
  This template looks at all locations where memory could be set.
  These locations, in order of priority, are:
  - .Values.resources.memory.redpanda.reserveMemory (commented out by default, users could uncomment)
  - .Values.resources.memory.container.min (commented out by default, users could uncomment and
    change to something lower than .Values.resources.memory.container.max)
  - .Values.resources.memory.container.max (set by default)
  */}}
  {{- $result := 0 -}}
  {{- if (hasKey .Values.resources.memory "redpanda") -}}
    {{- $result = .Values.resources.memory.redpanda.reserveMemory | include "redpanda-memoryToMi" | int64 -}}
  {{- else if (hasKey .Values.resources.memory.container "min") -}}
    {{- $result = add (mulf (include "container-memory" .) 0.002) 200 -}}
    {{- if gt $result 1000 -}}
      {{- $result = 1000 -}}
    {{- end -}}
  {{- else -}}
    {{- $result = add (mulf (include "container-memory" .) 0.002) 200 -}}
    {{- if gt $result 1000 -}}
      {{- $result = 1000 -}}
    {{- end -}}
  {{- end -}}
  {{- if eq $result 0 -}}
    {{- "unable to get memory value" | fail -}}
  {{- end -}}
  {{- $result -}}
{{- end -}}

{{- define "redpanda-memory" -}}
  {{/*
  Determines the value of --memory flag (in mebibytes with M suffix, per Seastar).
  This template looks at all locations where memory could be set.
  These locations, in order of priority, are:
  - .Values.resources.memory.redpanda.memory (commented out by default, users could uncomment)
  - .Values.resources.memory.container.min (commented out by default, users could uncomment and
    change to something lower than .Values.resources.memory.container.max)
  - .Values.resources.memory.container.max (set by default)
  */}}
  {{- $result := 0 -}}
  {{- if (hasKey .Values.resources.memory "redpanda") -}}
    {{- $result = .Values.resources.memory.redpanda.memory | include "redpanda-memoryToMi" | int64 -}}
  {{- else -}}
    {{- $result = mulf (include "container-memory" .) 0.8 | int64 -}}
  {{- end -}}
  {{- if eq $result 0 -}}
    {{- "unable to get memory value" | fail -}}
  {{- end -}}
  {{- if lt $result 2000 -}}
    {{- printf "\n%d is below the minimum recommended value for Redpanda" $result | fail -}}
  {{- end -}}
  {{- if gt (add $result (include "redpanda-reserve-memory" .)) (include "container-memory" . | int64) -}}
    {{- printf "\nNot enough container memory for Redpanda memory values\nredpanda: %d, reserve: %d, container: %d" $result (include "redpanda-reserve-memory" . | int64) (include "container-memory" . | int64) | fail -}}
  {{- end -}}
  {{- $result -}}
{{- end -}}

{{- define "api-urls" -}}
{{ template "redpanda.fullname" . }}-0.{{ include "redpanda.internal.domain" .}}:{{ .Values.listeners.admin.port }}
{{- end -}}

{{- define "sasl-mechanism" -}}
{{- dig "sasl" "mechanism" "SCRAM-SHA-512" .Values.auth -}}
{{- end -}}

{{- define "sasl-user-mechanism" -}}
{{- dig "mechanism" (include "sasl-mechanism" $) $.user -}}
{{- end -}}

{{- define "rpk-flags" -}}
  {{- $root := . -}}
  {{- $admin := list -}}
  {{- $admin = concat $admin (list "--api-urls" (include "api-urls" . )) -}}
  {{- if (include "admin-internal-tls-enabled" . | fromJson).bool -}}
    {{- $admin = concat $admin (list
      "--admin-api-tls-enabled"
      "--admin-api-tls-truststore"
      (printf "/etc/tls/certs/%s/ca.crt" .Values.listeners.admin.tls.cert))
    -}}
  {{- end -}}
  {{- $kafka := list -}}
  {{- if (include "kafka-internal-tls-enabled" . | fromJson).bool -}}
    {{- $kafka = concat $kafka (list
      "--tls-enabled"
      "--tls-truststore"
      (printf "/etc/tls/certs/%s/ca.crt" .Values.listeners.kafka.tls.cert))
    -}}
  {{- end -}}
  {{- $sasl := list -}}
  {{- if (include "sasl-enabled" . | fromJson).bool -}}
    {{- $root := . | toJson | fromJson -}}
    {{- $sasl = concat $sasl (list
      "--user" (dig "auth" "username" (first .Values.auth.sasl.users).name $root)
      "--password" (dig "auth" "password" (first .Values.auth.sasl.users).password $root)
      "--sasl-mechanism " (include "sasl-mechanism" .)
    )
    -}}
  {{- end -}}
  {{- $brokers := list -}}
  {{- range $i := untilStep 0 (.Values.statefulset.replicas|int) 1 -}}
    {{- $brokers = concat $brokers (list (printf "%s-%d.%s:%d"
      (include "redpanda.fullname" $root)
      $i
      (include "redpanda.internal.domain" $root)
      (int $root.Values.listeners.kafka.port)))
    -}}
  {{- end -}}
  {{- $brokersFlag := printf "--brokers %s" (join "," $brokers) -}}
{{- toJson (dict "admin" (join " " $admin) "kafka" (join " " $kafka) "sasl" (join " " $sasl) "brokers" $brokersFlag) -}}
{{- end -}}

{{- define "rpk-common-flags" -}}
{{- $flags := fromJson (include "rpk-flags" .) -}}
{{ join " " (list $flags.brokers $flags.admin $flags.sasl $flags.kafka)}}
{{- end -}}

{{- define "rpk-topic-flags" -}}
{{- $flags := fromJson (include "rpk-flags" .) -}}
{{ join " " (list $flags.brokers $flags.sasl $flags.kafka)}}
{{- end -}}

{{- define "storage-min-free-bytes" -}}
{{- $fiveGiB := 5368709120 -}}
{{- if dig "enabled" false .Values.storage.persistentVolume -}}
  {{- min $fiveGiB (mulf (include "SI-to-bytes" .Values.storage.persistentVolume.size) 0.05 | int64) -}}
{{- else -}}
{{- $fiveGiB -}}
{{- end -}}
{{- end -}}

{{- define "tunable" -}}
{{- $tunable := dig "tunable" dict .Values.config }}
{{- if (include "redpanda-atleast-22-3-0" . | fromJson).bool }}
{{- toYaml $tunable | nindent 4 }}
{{- else if (include "redpanda-atleast-22-2-0" . | fromJson).bool }}
{{- $tunable = unset $tunable "log_segment_size_min" }}
{{- $tunable = unset $tunable "log_segment_size_max" }}
{{- $tunable = unset $tunable "kafka_batch_max_bytes" }}
{{- toYaml $tunable | nindent 4 }}
{{- else if (include "redpanda-atleast-22-1-1" . | fromJson).bool }}
{{- $tunable = unset $tunable "log_segment_size_min" }}
{{- $tunable = unset $tunable "log_segment_size_max" }}
{{- $tunable = unset $tunable "kafka_batch_max_bytes" }}
{{- $tunable = unset $tunable "topic_partitions_per_shard" }}
{{- toYaml $tunable | nindent 4 }}
{{- end }}
{{- end }}

{{- define "redpanda-atleast-22-1-1" -}}
{{- toJson (dict "bool" (or (not (eq .Values.image.repository "vectorized/redpanda")) (include "redpanda.semver" . | semverCompare ">=22.1.1"))) -}}
{{- end -}}

{{- define "redpanda-atleast-22-2-0" -}}
{{- toJson (dict "bool" (or (not (eq .Values.image.repository "vectorized/redpanda")) (include "redpanda.semver" . | semverCompare ">=22.2.0"))) -}}
{{- end -}}

{{- define "redpanda-atleast-22-3-0" -}}
{{- toJson (dict "bool" (or (not (eq .Values.image.repository "vectorized/redpanda")) (include "redpanda.semver" . | semverCompare ">=22.3.0"))) -}}
{{- end -}}

# manage backward compatibility with renaming podSecurityContext to securityContext
{{- define "pod-security-context" -}}
fsGroup: {{ dig "podSecurityContext" "fsGroup" .Values.statefulset.securityContext.fsGroup .Values.statefulset }}
{{- end -}}

# for backward compatibility, force a default on releases that didn't
# set the podSecurityContext.runAsUser before
{{- define "container-security-context" -}}
runAsUser: {{ dig "podSecurityContext" "runAsUser" .Values.statefulset.securityContext.runAsUser .Values.statefulset }}
runAsGroup: {{ dig "podSecurityContext" "fsGroup" .Values.statefulset.securityContext.fsGroup .Values.statefulset }}
{{- end -}}

{{- define "tls-curl-flags" -}}
  {{- $result := "" -}}
  {{- if (include "tls-enabled" . | fromJson).bool -}}
    {{- $path := (printf "/etc/tls/certs/%s" .Values.listeners.admin.tls.cert) -}}
    {{- $result = (printf "--cacert %s/tls.crt" $path) -}}
    {{- if .Values.listeners.admin.tls.requireClientAuth -}}
      {{- $result = (printf "--cacert %s/ca.crt --cert %s/tls.crt --key %s/tls.key" $path $path $path) -}}
    {{- end -}}
  {{- end -}}
  {{- $result -}}
{{- end -}}

{{- define "http-protocol" -}}
  {{- $result := "http" -}}
  {{- if (include "tls-enabled" . | fromJson).bool -}}
    {{- $result = "https" -}}
  {{- end -}}
  {{- $result -}}
{{- end -}}

{{- /*
advertised-port returns either the only advertised port if only one is specified,
or the port specified for this pod ordinal when there is a full list provided.

This will return a string int or panic if there is more than one port provided,
but not enough ports for the number of replicas requested.
*/ -}}
{{- define "advertised-port" -}}
  {{- $port := dig "port" .listenerVals.port .externalVals -}}
  {{- if .externalVals.advertisedPorts -}}
    {{- if eq (len .externalVals.advertisedPorts) 1 -}}
      {{- $port = mustFirst .externalVals.advertisedPorts -}}
    {{- else -}}
      {{- $port = index .externalVals.advertisedPorts .replicaIndex -}}
    {{- end -}}
  {{- end -}}
  {{ $port }}
{{- end -}}

{{- /*
advertised-host returns a json sring with the data neded for configuring the advertised listener
*/ -}}
{{- define "advertised-host" -}}
  {{- $host := dict "name" .externalName "address" .externalAdvertiseAddress "port" .port -}}
  {{- if .values.external.addresses -}}
    {{- if .values.external.domain -}}
      {{- $host = dict "name" .externalName "address" (printf "%s.%s" (index .values.external.addresses .replicaIndex) .values.external.domain) "port" .port -}}
    {{- else -}}
      {{- $host = dict "name" .externalName  "address" (index .values.external.addresses .replicaIndex) "port" .port -}}
    {{- end -}}
  {{- end -}}
  {{- toJson $host -}}
{{- end -}}
