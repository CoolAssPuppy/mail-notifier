# DMG assets

`scripts/build-dmg.sh` expects a background image at `dmg-assets/background.tiff`. It sets up a 660x400 point window with the `Mail Notifier.app` icon at (355, 200) and a drop-link to `/Applications` at (555, 200).

## Generate the TIFF from a 1320x800 PNG

1. Design `background.png` at 1320x800 (2x retina). Put your brand visuals in the background and clear drop-zone markers (brackets or arrows) at the two icon positions. The icons themselves get drawn on top by `create-dmg` at the coordinates listed in `build-dmg.sh`.
2. Generate the multi-resolution TIFF:

   ```bash
   cd dmg-assets
   sips --resampleHeightWidth 800 1320 background.png --out background-2x.png
   sips --resampleHeightWidth 400 660  background.png --out background-1x.png
   tiffutil -cathidpicheck background-1x.png background-2x.png -out background.tiff
   rm background-1x.png background-2x.png
   ```

3. Commit `background.png` and `background.tiff`.

If you change the icon positions in `build-dmg.sh`, update the background art so the drop zones line up.
