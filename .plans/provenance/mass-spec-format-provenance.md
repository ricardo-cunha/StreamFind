# Mass-spectrometry format provenance

This page describes the technical provenance and support boundaries of the native
mass-spectrometry readers. It is an engineering record, not a legal opinion or
certification of reverse-engineering rights.

## Independence and scope

streamfind's C++ and Rust readers are independently implemented native readers.
They do not require vendor DLLs, vendor SDKs, ClearCore, ProteoWizard,
`msconvert`, `baf2sql`, or paired conversion files at runtime.

Vendor and product names identify the file formats and systems whose files may
be readable. They do not imply affiliation, sponsorship, endorsement, or
permission to redistribute vendor software or data.

## Format-family provenance

| Format family | Development knowledge sources | Native production dependency | Current public support boundary |
| --- | --- | --- | --- |
| Agilent MassHunter | Public documentation, legally obtained sample files, byte-level analysis, and differential comparison where available | None | Validated MassHunter acquisitions; additional instrument families and calibration variants remain subject to validation |
| Agilent ChemStation | Legacy file structures, legally obtained samples, and differential comparison where available | None | Validated `MSD1.MS`/`DATA.MS` and selected `.ch`/`.UV` behavior; this is not complete ChemStation/2D support |
| SCIEX WIFF/WIFF.SCAN | OLE/container inspection, legally obtained files, and differential comparison where available | None | Validated TOF and selected MRM/tagged grammars; unsupported layouts must fail explicitly |
| Bruker TSF/BAF | Native SQLite/container inspection, legally obtained files, and byte-level analysis | None | Validated TSF/BAF families; calibration and additional acquisition variants remain limited |
| Shimadzu LCD | Native TLM inspection, legally obtained files, and differential comparison where available | None | Validated `adc.lcd` and `karl.lcd` families; broader LCD coverage remains open |
| mzML/mzXML | Public specifications and project-owned/public test data | None | Native XML spectrum/chromatogram access, compressed arrays, metadata, and indexed reads |

The exact sample files used for development are not part of this public
provenance record unless their redistribution rights are documented.

## Development-only materials

Some native-reader investigations use material that is not a production
requirement. These categories must remain outside release archives:

- vendor SDK headers, DLLs, and proprietary runtimes;
- ClearCore, ProteoWizard, `msconvert`, `baf2sql`, or similar oracle tools;
- converted mzML files used only for differential comparison;
- debugger traces, decompiled output, and confidential reports;
- vendor sample files whose redistribution rights are unknown or restricted.

External fixtures are opt-in development inputs. A fixture may be used for
validation only after its owner, source category, permission status, and
redistribution status have been recorded. Do not commit passwords, tokens,
connection strings, private filesystem paths, or confidential traces.

## Decoder and calibration provenance

The readers use common data-format mechanisms including OLE traversal, SQLite
metadata, base64, zlib, Zstandard, LZF, and bit-packed/delta decoding. These
are implemented or consumed through ordinary independent/library interfaces;
this page does not claim that any vendor implementation was copied.

Where behavior is inferred from observed files, it is documented as inferred
behavior rather than a vendor specification. In particular:

- Bruker TSF calibration is an explicitly documented approximation for the
  validated sample set, not a claim of vendor-exact calibration;
- BAF calibration and additional profile/line variants remain under validation;
- unsupported or ambiguous binary grammars should produce an explicit error,
  not a fabricated interpretation.

## Validation policy

Reader validation compares the C++ and Rust public contract for logical
analyses, headers, arrays, chromatograms, persistence, and MCP responses.
Exact equality is required for counts, ordering, identifiers, and guaranteed
array lengths. Floating-point values use documented tolerances where the
format or calibration requires them.

Validation results for one sample or instrument family do not establish
complete support for the vendor's entire product line. Consult the
[availability and compatibility](status.md) page before relying on a format.

## Legal review boundary

This page records engineering provenance and limitations only. Before
redistributing native binaries or vendor-format datasets, review applicable
licences, NDAs, SDK agreements, reverse-engineering restrictions, sample-data
rights, trademark obligations, and the bundled third-party notices in
[`NOTICE.md`](https://github.com/odea-project/streamfind/blob/dev_refactoring/NOTICE.md).
