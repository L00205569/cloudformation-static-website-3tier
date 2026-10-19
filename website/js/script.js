// Small progressive enhancement: show a localised load time for a useful demo interaction.
const status = document.querySelector("#status");

if (status) {
  const loadedAt = new Intl.DateTimeFormat(undefined, {
    hour: "2-digit",
    minute: "2-digit",
  }).format(new Date());
  status.textContent = `Page loaded successfully at ${loadedAt}.`;
}
