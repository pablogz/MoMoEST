{{flutter_js}}
{{flutter_build_config}}


var loading = document.querySelector('#loading');
var progressBar = document.querySelector('#progressBar');
var t = setInterval(function () {
    progressBar.value = progressBar.value < 100 ? progressBar.value + 1 : 1;
}, 100);

_flutter.loader.load({
  onEntrypointLoaded: async function(engineInitializer) {
    const appRunner = await engineInitializer.initializeEngine();
    clearInterval(t);
    progressBar.value = 100;
    await appRunner.runApp();
    progressBar.remove();
  }
});