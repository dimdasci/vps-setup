# PDF and Image Processing Scripts

TypeScript/Bun examples for Windmill scripts using the custom worker tools.

## PDF Text Extraction

### Extract all text from PDF

```typescript
import { $ } from "bun";

export async function main(pdfPath: string): Promise<string> {
  // Extract text preserving layout
  const text = await $`pdftotext -layout ${pdfPath} -`.text();
  return text;
}
```

### Extract text with page numbers

```typescript
import { $ } from "bun";

export async function main(pdfPath: string): Promise<{ page: number; text: string }[]> {
  const info = await $`pdfinfo ${pdfPath}`.text();
  const pageMatch = info.match(/Pages:\s+(\d+)/);
  const totalPages = pageMatch ? parseInt(pageMatch[1]) : 1;

  const pages = [];
  for (let i = 1; i <= totalPages; i++) {
    const text = await $`pdftotext -f ${i} -l ${i} ${pdfPath} -`.text();
    pages.push({ page: i, text: text.trim() });
  }
  return pages;
}
```

## PDF Metadata

### Get PDF information

```typescript
import { $ } from "bun";

export async function main(pdfPath: string): Promise<Record<string, string>> {
  const info = await $`pdfinfo ${pdfPath}`.text();
  const result: Record<string, string> = {};

  for (const line of info.split('\n')) {
    const [key, ...valueParts] = line.split(':');
    if (key && valueParts.length) {
      result[key.trim()] = valueParts.join(':').trim();
    }
  }
  return result;
}
```

## PDF to Images

### Convert PDF pages to PNG

```typescript
import { $ } from "bun";

export async function main(
  pdfPath: string,
  dpi: number = 300
): Promise<string[]> {
  const outputDir = `/tmp/pdf_images_${Date.now()}`;
  await $`mkdir -p ${outputDir}`;

  // Convert all pages to PNG
  await $`pdftoppm -png -r ${dpi} ${pdfPath} ${outputDir}/page`;

  // List generated files
  const files = await $`ls ${outputDir}/*.png`.text();
  return files.trim().split('\n');
}
```

### High-quality PDF to JPEG

```typescript
import { $ } from "bun";

export async function main(pdfPath: string): Promise<string[]> {
  const outputDir = `/tmp/pdf_jpg_${Date.now()}`;
  await $`mkdir -p ${outputDir}`;

  // Use pdftocairo for high-quality output
  await $`pdftocairo -jpeg -jpegopt quality=95 ${pdfPath} ${outputDir}/page`;

  const files = await $`ls ${outputDir}/*.jpg`.text();
  return files.trim().split('\n');
}
```

## PDF Image Extraction

### Extract embedded images from PDF

```typescript
import { $ } from "bun";

export async function main(pdfPath: string): Promise<string[]> {
  const outputDir = `/tmp/extracted_${Date.now()}`;
  await $`mkdir -p ${outputDir}`;

  // Extract all images in original format
  await $`pdfimages -all ${pdfPath} ${outputDir}/img`;

  const files = await $`ls ${outputDir}/img*`.text();
  return files.trim().split('\n').filter(f => f);
}
```

## PDF Manipulation

### Merge PDFs

```typescript
import { $ } from "bun";

export async function main(
  pdfPaths: string[],
  outputPath: string
): Promise<string> {
  await $`pdfunite ${pdfPaths.join(' ')} ${outputPath}`;
  return outputPath;
}
```

### Split PDF by pages

```typescript
import { $ } from "bun";

export async function main(
  pdfPath: string,
  pages: string  // e.g., "1-5" or "1,3,5-7"
): Promise<string> {
  const outputDir = `/tmp/split_${Date.now()}`;
  await $`mkdir -p ${outputDir}`;

  await $`pdfcpu split -pages ${pages} ${pdfPath} ${outputDir}`;
  return outputDir;
}
```

### Add watermark

```typescript
import { $ } from "bun";

export async function main(
  pdfPath: string,
  watermarkText: string
): Promise<string> {
  const outputPath = pdfPath.replace('.pdf', '_watermarked.pdf');
  await $`pdfcpu watermark add -- "${watermarkText}" ${pdfPath} ${outputPath}`;
  return outputPath;
}
```

### Encrypt PDF

```typescript
import { $ } from "bun";

export async function main(
  pdfPath: string,
  password: string
): Promise<string> {
  const outputPath = pdfPath.replace('.pdf', '_encrypted.pdf');
  await $`pdfcpu encrypt -upw ${password} ${pdfPath} ${outputPath}`;
  return outputPath;
}
```

## Image Processing with libvips

### Resize image

```typescript
import { $ } from "bun";

export async function main(
  imagePath: string,
  width: number
): Promise<string> {
  const outputPath = imagePath.replace(/\.[^.]+$/, '_resized.jpg');
  await $`vipsthumbnail ${imagePath} -s ${width} -o ${outputPath}[Q=85]`;
  return outputPath;
}
```

### Generate thumbnail (fast)

```typescript
import { $ } from "bun";

export async function main(
  imagePath: string,
  size: string = "300x300"
): Promise<string> {
  const outputPath = `/tmp/thumb_${Date.now()}.jpg`;

  // Smart crop focuses on interesting parts
  await $`vipsthumbnail ${imagePath} -s ${size} --smartcrop attention -o ${outputPath}[Q=85]`;
  return outputPath;
}
```

### Convert image format

```typescript
import { $ } from "bun";

export async function main(
  imagePath: string,
  format: "webp" | "jpg" | "png"
): Promise<string> {
  const outputPath = imagePath.replace(/\.[^.]+$/, `.${format}`);

  switch (format) {
    case "webp":
      await $`vips copy ${imagePath} ${outputPath}[Q=85]`;
      break;
    case "jpg":
      await $`vips copy ${imagePath} ${outputPath}[Q=90,strip]`;
      break;
    case "png":
      await $`vips copy ${imagePath} ${outputPath}[compression=9]`;
      break;
  }
  return outputPath;
}
```

### Optimize image

```typescript
import { $ } from "bun";

export async function main(
  imagePath: string,
  quality: number = 85
): Promise<string> {
  const outputPath = imagePath.replace(/\.[^.]+$/, '_optimized.jpg');

  // Resize to max 2000px, optimize quality, strip metadata
  await $`vipsthumbnail ${imagePath} -s 2000 -o ${outputPath}[Q=${quality},strip]`;
  return outputPath;
}
```

### Get image dimensions

```typescript
import { $ } from "bun";

export async function main(imagePath: string): Promise<{ width: number; height: number }> {
  const width = parseInt(await $`vips header -f width ${imagePath}`.text());
  const height = parseInt(await $`vips header -f height ${imagePath}`.text());
  return { width, height };
}
```

### Batch process images

```typescript
import { $ } from "bun";
import { readdir } from "fs/promises";

export async function main(
  inputDir: string,
  outputDir: string,
  maxWidth: number = 1024
): Promise<string[]> {
  await $`mkdir -p ${outputDir}`;

  const files = await readdir(inputDir);
  const images = files.filter(f => /\.(jpg|jpeg|png|webp)$/i.test(f));

  const outputs: string[] = [];
  for (const file of images) {
    const input = `${inputDir}/${file}`;
    const output = `${outputDir}/${file.replace(/\.[^.]+$/, '.jpg')}`;
    await $`vipsthumbnail ${input} -s ${maxWidth} -o ${output}[Q=85,strip]`;
    outputs.push(output);
  }
  return outputs;
}
```

### Apply effects

```typescript
import { $ } from "bun";

export async function main(
  imagePath: string,
  effect: "blur" | "sharpen" | "grayscale"
): Promise<string> {
  const outputPath = imagePath.replace(/\.[^.]+$/, `_${effect}.jpg`);

  switch (effect) {
    case "blur":
      await $`vips gaussblur ${imagePath} ${outputPath} 5`;
      break;
    case "sharpen":
      await $`vips sharpen ${imagePath} ${outputPath}`;
      break;
    case "grayscale":
      await $`vips colourspace ${imagePath} ${outputPath} b-w`;
      break;
  }
  return outputPath;
}
```

## LLM Workflow Examples

### Prepare PDF for LLM

```typescript
import { $ } from "bun";

export async function main(pdfPath: string): Promise<{
  text: string;
  pageCount: number;
  metadata: Record<string, string>;
}> {
  // Extract text
  const text = await $`pdftotext -layout ${pdfPath} -`.text();

  // Get metadata
  const info = await $`pdfinfo ${pdfPath}`.text();
  const metadata: Record<string, string> = {};
  for (const line of info.split('\n')) {
    const [key, ...value] = line.split(':');
    if (key && value.length) {
      metadata[key.trim()] = value.join(':').trim();
    }
  }

  return {
    text,
    pageCount: parseInt(metadata['Pages'] || '0'),
    metadata
  };
}
```

### Process images for vision LLM

```typescript
import { $ } from "bun";
import { readFile } from "fs/promises";

export async function main(
  imagePath: string,
  maxSize: number = 1024
): Promise<string> {
  // Resize and optimize for LLM
  const outputPath = `/tmp/llm_ready_${Date.now()}.jpg`;
  await $`vipsthumbnail ${imagePath} -s ${maxSize} -o ${outputPath}[Q=85,strip]`;

  // Return base64 for API
  const buffer = await readFile(outputPath);
  return buffer.toString('base64');
}
```
