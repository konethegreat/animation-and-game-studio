import { defineConfig } from "vite";

const entry = (name: string) =>
  decodeURIComponent(new URL(name, import.meta.url).pathname).replace(/^\/([A-Za-z]:\/)/, "$1");

export default defineConfig({
  base: "/animation-and-game-studio/",
  build: {
    rolldownOptions: {
      input: {
        main: entry("./index.html"),
        creator: entry("./creator-probe.html"),
      },
    },
  },
});
