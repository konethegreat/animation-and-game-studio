import { copyFile, mkdir, readFile, writeFile } from "node:fs/promises";
import { join } from "node:path";

const shell = "dist/index.html";
const generated = await readFile("src/projects.generated.ts", "utf8");
const ids = [...generated.matchAll(/"id":\s*"([^"]+)"/g)].map((match) => match[1]);

const routes = new Set(["demo/three"]);
for (const id of ids) {
  routes.add(`project/${id}`);
  routes.add(`play/${id}`);
}

for (const route of routes) {
  const dir = join("dist", route);
  await mkdir(dir, { recursive: true });
  await copyFile(shell, join(dir, "index.html"));
}

await copyFile(shell, "dist/404.html");
await writeFile("dist/.nojekyll", "");
console.log(`wrote ${routes.size} route shells, 404.html and .nojekyll`);
