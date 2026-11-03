{{flutter_js}}
{{flutter_build_config}}

_flutter.loader.load({
  serviceWorkerSettings: {
    serviceWorkerVersion: {{flutter_service_worker_version}},
    // On a first visit, let the worker finish installing after startup.
    timeoutMillis: navigator.serviceWorker?.controller ? 4000 : 500,
  },
});
