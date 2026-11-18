// Rewrites meshopt-compressed GLBs as plain GLBs so Blender can read them, using
// the decoder three.js already ships. Run from showcase/ so "three" resolves.
//   node ../studio/tools/character/unpack_meshopt.mjs <three root> <src dir> <out dir>
import fs from "node:fs";
import path from "node:path";
import { pathToFileURL } from "node:url";

const [threeRoot, srcDir, outDir] = process.argv.slice(2);
const decoderPath = path.join(threeRoot, "examples/jsm/libs/meshopt_decoder.module.js");
const { MeshoptDecoder } = await import(pathToFileURL(decoderPath).href);
await MeshoptDecoder.ready;
fs.mkdirSync(outDir, { recursive: true });

function chunkHeader(length, type) {
  const header = Buffer.alloc(8);
  header.writeUInt32LE(length, 0);
  header.writeUInt32LE(type, 4);
  return header;
}

for (const name of fs.readdirSync(srcDir).filter((f) => f.endsWith(".glb"))) {
  const file = fs.readFileSync(path.join(srcDir, name));
  const jsonLength = file.readUInt32LE(12);
  const json = JSON.parse(file.subarray(20, 20 + jsonLength).toString("utf8"));
  const binStart = 20 + jsonLength + 8;
  const bin = file.subarray(binStart, binStart + file.readUInt32LE(20 + jsonLength));
  const parts = [];
  let offset = 0;
  json.bufferViews = json.bufferViews.map((view) => {
    const ext = view.extensions?.EXT_meshopt_compression;
    let data;
    if (ext) {
      data = new Uint8Array(ext.count * ext.byteStride);
      const start = ext.byteOffset ?? 0;
      const source = bin.subarray(start, start + ext.byteLength);
      MeshoptDecoder.decodeGltfBuffer(data, ext.count, ext.byteStride, source, ext.mode, ext.filter ?? "NONE");
    } else {
      const start = view.byteOffset ?? 0;
      data = bin.subarray(start, start + view.byteLength);
    }
    const next = { buffer: 0, byteOffset: offset, byteLength: data.length };
    if (view.byteStride || ext?.mode === "ATTRIBUTES") next.byteStride = view.byteStride ?? ext.byteStride;
    if (view.target) next.target = view.target;
    parts.push(Buffer.from(data));
    const pad = (4 - (data.length % 4)) % 4;
    if (pad) parts.push(Buffer.alloc(pad));
    offset += data.length + pad;
    return next;
  });
  json.buffers = [{ byteLength: offset }];
  const strip = (list) => list?.filter((entry) => entry !== "EXT_meshopt_compression");
  json.extensionsUsed = strip(json.extensionsUsed);
  json.extensionsRequired = strip(json.extensionsRequired);

  let text = Buffer.from(JSON.stringify(json));
  text = Buffer.concat([text, Buffer.alloc((4 - (text.length % 4)) % 4, 0x20)]);
  const body = Buffer.concat(parts);
  const head = Buffer.alloc(12);
  head.write("glTF");
  head.writeUInt32LE(2, 4);
  head.writeUInt32LE(12 + 8 + text.length + 8 + body.length, 8);
  fs.writeFileSync(
    path.join(outDir, name),
    Buffer.concat([head, chunkHeader(text.length, 0x4e4f534a), text, chunkHeader(body.length, 0x004e4942), body]),
  );
  console.log(`unpacked ${name}`);
}
