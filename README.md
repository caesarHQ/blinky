# Blink

Blink is a local screenshot search app for macOS. Press **Control–Space** and type what you remember, like `reset VPN token`, `blue chart`, or `#quote`. Use the arrow keys to pick a screenshot, then press **Return** to open it or **⌘C** to copy the image.

## What makes screenshots searchable?

Blink watches one folder. Apple Vision reads the text in each image, and Inkling 2 Mini, running locally through Ollama, looks at the screenshot and generates a short title, a description, labels, and phrases you might search for later. This also works for images without text. Blink stores the results in SQLite and searches that index as you type.

- **Search by label.** Try `#instructions vpn` or combine labels with `#substack #quote`.
- **Search by initials.** Blink uses Apple's Natural Language framework to recognize people and organizations. A screenshot mentioning Paul Graham can turn up for `pg`.
- **Keep Finder organized.** Eligible new CleanShot and macOS captures can get names like `instructions_reset_vpn_token_2026-11-20_17-04-25.png`. This renames the actual file. Toggle **Auto-rename new screenshots** in the menu bar.
- **Save a clipboard image.** Choose **Index clipboard image** from the menu bar to save it to the watched folder.

## Install

You need an Apple silicon Mac with **32 GB or more unified memory** for the recommended Inkling model, about **20 GB of disk space** for its weights, and Apple's Command Line Tools to compile Blink. Blink was tested on an M3 Pro with macOS 26.3. [Inkling 2 Mini model card](https://thinkingmachines.ai/model-card/inkling-2-mini/)

1. **Install the build tools.** Run the following if you don't already have Xcode or its Command Line Tools. Wait for installation to finish.

   ```sh
   xcode-select --install
   ```

2. **Start Ollama and download Inkling.** Use the macOS build recommended on the [Ollama model page](https://ollama.com/library/inkling-2-mini). Open Ollama, then run the command below. Leave Ollama running for background captioning.

   ```sh
   ollama pull inkling-2-mini
   ```

3. **Build and install Blink.** Clone or download this repository. From the directory containing this README, run:

   ```sh
   ./build.sh
   mkdir -p ~/Applications
   ditto build/Blink.app ~/Applications/Blink.app
   open ~/Applications/Blink.app
   ```

   The script builds and locally signs the app. To try it directly from the repository, use `open build/Blink.app` after building.

4. **Choose your screenshots folder.** Click the folder icon in the search panel or choose **Choose screenshot folder…** in Blink's menu bar menu. Select the folder where CleanShot or macOS saves your captures. Blink indexes existing images there and watches for new ones. Files in nested folders are outside the index.

## Try it

Take a screenshot containing a distinctive phrase. Press **Control–Space**, search for the phrase, and open the result. Once Inkling has described the image, try searching for a detail you can see or a label such as `#notes`. Hover over a thumbnail for a larger image preview.

OCR and filename search work while the model downloads. Visual descriptions and labels become available as the background queue runs. Search uses keyword matching over the generated phrases, OCR and filenames, so different wording can produce different results.

## Troubleshooting

- **Control–Space is already in use.** Choose **Search screenshots** from Blink's menu bar icon.
- **Images appear but have no labels yet.** Confirm Ollama is running and `ollama list` shows `inkling-2-mini`. Blink retries pending images automatically.
- **Ollama uses a custom port.** Blink connects to `127.0.0.1:11434` by default. For example, to use port 11517, quit Blink, run `defaults write local.blink.mac ollamaPort -int 11517`, then reopen it.
- **A capture is missing.** Check the watched folder and capture destination. For a clipboard-only capture, use **Index clipboard image**. Blink supports PNG, JPEG, HEIC, HEIF, WebP and TIFF.

## Local data and source

Screenshots stay in your chosen folder. The OCR text, descriptions and search index live in `~/Library/Application Support/Blink/index.sqlite`, outside this repository. Blink sends images only to the local Ollama endpoint.

`main.swift` implements the menu bar app, search panel, shortcuts and folder watcher. `Index.swift` handles OCR, model requests, renaming and SQLite search. The build uses macOS frameworks and system SQLite.

## License

Blink is available under the [MIT License](LICENSE).
