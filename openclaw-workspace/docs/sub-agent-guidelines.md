# Sub-Agent Content Requirements

**Some projects require images in all documents.** When spawning sub-agents for these projects, always include image instructions in the task prompt.

## Projects That Require Images

- **Dream House** (`~/projects/dream-house/`) — Every article needs real photos of materials, homes, systems, etc.

## Image Instructions (when applicable)

- **GENERATE images using Nano Banana Pro (Gemini)** — do NOT download from Unsplash/stock sites (sub-agents can't verify what they download, results are often wrong/irrelevant)
  ```bash
  uv run $HOME/.bun/install/global/node_modules/openclaw/skills/nano-banana-pro/scripts/generate_image.py \
    --prompt "Detailed description of the image" --filename "assets/name.png" --resolution 1K
  ```
- Write detailed prompts — include subject, style, environment, lighting, angle
- Output is PNG — use `.png` in filenames and markdown refs
- Use markdown image syntax: `![Descriptive alt text](assets/filename.png)` with an italic caption below
- Target: roughly 1 image per major section or concept discussed

## For Everything Else

Use judgment. Diagrams are great for architecture/flow docs. Stock photos aren't needed for technical research, API docs, or analysis.
