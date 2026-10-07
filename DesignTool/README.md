# DuoTouchDesigner

DuoTouchDesigner is a macOS design tool for generating DuoTouch electrode and wiring layouts and exporting them as SVG or DXF files.

## Requirements

- macOS 15.1 or later
- Xcode 16.2 or later

## Build and run

1. Open `DuoTouchDesigner.xcodeproj` in Xcode.
2. Select the `DuoTouchDesigner` scheme and the local Mac destination.
3. Build and run the project.

No prebuilt `.app` binary is included in this repository. Code signing for local execution is handled by each user's Xcode environment.

## File access

The application uses the App Sandbox. It requests read/write access to files selected by the user and to the Downloads folder so that generated SVG and DXF files can be exported.

## License

All source code and accompanying materials in this repository are licensed under the [Creative Commons Attribution 4.0 International License](https://creativecommons.org/licenses/by/4.0/) (CC BY 4.0), unless otherwise noted.

When reusing or adapting this work, please provide attribution as follows:

> DuoTouchDesigner by Kaori Ikematsu (LY Corporation) and Kunihiro Kato (Tokyo University of Technology / Japan Women’s University), licensed under CC BY 4.0.

See the repository-level [LICENSE](../LICENSE) for details.

## Citation

If you use DuoTouchDesigner or build upon this work, please cite the following paper:

> Kaori Ikematsu and Kunihiro Kato. 2026. DuoTouch: Passive Two-Footprint Attachments Using Binary Sequences to Extend Touch Interaction. In *Proceedings of the 2026 CHI Conference on Human Factors in Computing Systems* (CHI '26), Article 1118, 16 pages. Association for Computing Machinery. https://doi.org/10.1145/3772318.3790411

```bibtex
@inproceedings{10.1145/3772318.3790411,
  author = {Ikematsu, Kaori and Kato, Kunihiro},
  title = {DuoTouch: Passive Two-Footprint Attachments Using Binary Sequences to Extend Touch Interaction},
  year = {2026},
  isbn = {9798400722783},
  publisher = {Association for Computing Machinery},
  address = {New York, NY, USA},
  url = {https://doi.org/10.1145/3772318.3790411},
  doi = {10.1145/3772318.3790411},
  booktitle = {Proceedings of the 2026 CHI Conference on Human Factors in Computing Systems},
  articleno = {1118},
  numpages = {16},
  keywords = {Touch Interaction, Capacitive Touch Sensing, Passive Attachment, Mobile Interface.},
  location = {Barcelona, Spain},
  series = {CHI '26}
}
```
