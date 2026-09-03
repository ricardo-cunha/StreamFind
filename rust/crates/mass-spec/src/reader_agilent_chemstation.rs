use std::fs;
use std::path::{Path, PathBuf};

#[derive(Debug, Clone, PartialEq)]
pub struct IndexEntry {
    pub offset: u64,
    pub retention_time_ms: i32,
    pub total_signal_raw: i32,
}

#[derive(Debug, Clone, Default, PartialEq)]
pub struct Spectrum {
    pub retention_time_ms: i32,
    pub status_word: i16,
    pub mz: Vec<f32>,
    pub intensity: Vec<f32>,
}

#[derive(Debug, Clone, PartialEq)]
pub struct DataFile {
    pub path: PathBuf,
    pub file_type: String,
    pub data_name: String,
    pub operator_name: String,
    pub acquisition_date: String,
    pub instrument_model: String,
    pub inlet: String,
    pub method_file: String,
    pub record_count: i32,
    pub retention_time_start_ms: i32,
    pub retention_time_end_ms: i32,
    pub index: Vec<IndexEntry>,
}

fn be16(bytes: &[u8], offset: usize) -> Result<u16, String> {
    bytes
        .get(offset..offset + 2)
        .and_then(|v| v.try_into().ok())
        .map(u16::from_be_bytes)
        .ok_or_else(|| "Agilent ChemStation 16-bit field is truncated".into())
}

fn be16s(bytes: &[u8], offset: usize) -> Result<i16, String> {
    Ok(be16(bytes, offset)? as i16)
}
fn be32s(bytes: &[u8], offset: usize) -> Result<i32, String> {
    bytes
        .get(offset..offset + 4)
        .and_then(|v| v.try_into().ok())
        .map(i32::from_be_bytes)
        .ok_or_else(|| "Agilent ChemStation 32-bit field is truncated".into())
}

fn text(
    bytes: &[u8],
    offset: &mut usize,
    length: usize,
    skip_extra: bool,
) -> Result<String, String> {
    let end = offset
        .checked_add(length + usize::from(skip_extra))
        .ok_or_else(|| "Agilent ChemStation header overflow".to_string())?;
    if end > bytes.len() {
        return Err("Agilent ChemStation header is truncated".into());
    }
    let value_end = bytes[*offset..*offset + length]
        .iter()
        .position(|value| *value == 0)
        .unwrap_or(length);
    let value = String::from_utf8_lossy(&bytes[*offset..*offset + value_end])
        .trim_end_matches([' ', '\t'])
        .to_string();
    *offset = end;
    Ok(value)
}

pub fn is_chemstation_directory(path: &Path) -> bool {
    path.is_dir()
        && fs::read_dir(path)
            .map(|entries| {
                entries.flatten().any(|entry| {
                    entry
                        .file_type()
                        .map(|kind| kind.is_file())
                        .unwrap_or(false)
                        && matches!(
                            entry
                                .file_name()
                                .to_string_lossy()
                                .to_ascii_uppercase()
                                .as_str(),
                            "DATA.MS" | "MSD1.MS" | "MSD2.MS"
                        )
                        || entry
                            .file_name()
                            .to_string_lossy()
                            .to_ascii_uppercase()
                            .ends_with(".CH")
                        || entry
                            .file_name()
                            .to_string_lossy()
                            .to_ascii_uppercase()
                            .ends_with(".UV")
                })
            })
            .unwrap_or(false)
}

pub fn has_ms_data_file(path: &Path) -> bool {
    path.is_dir()
        && fs::read_dir(path)
            .map(|entries| {
                entries.flatten().any(|entry| {
                    entry
                        .file_type()
                        .map(|kind| kind.is_file())
                        .unwrap_or(false)
                        && matches!(
                            entry
                                .file_name()
                                .to_string_lossy()
                                .to_ascii_uppercase()
                                .as_str(),
                            "DATA.MS" | "MSD1.MS"
                        )
                })
            })
            .unwrap_or(false)
}

pub fn read_data_file(path: impl AsRef<Path>) -> Result<DataFile, String> {
    let path = path.as_ref().to_path_buf();
    if !path.is_file() {
        return Err(format!(
            "Agilent ChemStation data file does not exist: {}",
            path.display()
        ));
    }
    let bytes = fs::read(&path).map_err(|error| error.to_string())?;
    if bytes.len() < 300 {
        return Err(format!(
            "Agilent ChemStation data file is too short: {}",
            path.display()
        ));
    }
    let mut offset = 1usize;
    let _file_number = text(&bytes, &mut offset, 3, true)?;
    let file_type = text(&bytes, &mut offset, 19, true)?;
    let data_name = text(&bytes, &mut offset, 61, true)?;
    let _misc_info = text(&bytes, &mut offset, 61, true)?;
    let operator_name = text(&bytes, &mut offset, 29, true)?;
    let acquisition_date = text(&bytes, &mut offset, 29, true)?;
    let instrument_model = text(&bytes, &mut offset, 9, true)?;
    let inlet = text(&bytes, &mut offset, 9, true)?;
    let method_file = text(&bytes, &mut offset, 19, false)?;
    let file_type_code = be32s(&bytes, offset)?;
    offset += 4;
    offset += 8;
    let directory_words = be32s(&bytes, offset)?;
    offset += 4;
    offset += 12;
    offset += 2;
    let record_count = be32s(&bytes, offset)?;
    offset += 4;
    let retention_time_start_ms = be32s(&bytes, offset)?;
    offset += 4;
    let retention_time_end_ms = be32s(&bytes, offset)?;
    if file_type_code < -1 || directory_words <= 0 || record_count < 0 {
        return Err(format!(
            "Invalid Agilent ChemStation data header: {}",
            path.display()
        ));
    }
    let directory_offset = (directory_words as u64 - 1)
        .checked_mul(2)
        .ok_or_else(|| "Agilent ChemStation directory offset overflow".to_string())?
        as usize;
    let directory_bytes = (record_count as usize)
        .checked_mul(12)
        .ok_or_else(|| "Agilent ChemStation directory is too large".to_string())?;
    if directory_offset
        .checked_add(directory_bytes)
        .filter(|end| *end <= bytes.len())
        .is_none()
    {
        return Err(format!(
            "Agilent ChemStation directory exceeds data file: {}",
            path.display()
        ));
    }
    let mut index = Vec::with_capacity(record_count as usize);
    for item in 0..record_count as usize {
        let base = directory_offset + item * 12;
        let offset_words = be32s(&bytes, base)?;
        if offset_words <= 0 {
            return Err(format!(
                "Invalid Agilent ChemStation spectrum offset at index {item}"
            ));
        }
        index.push(IndexEntry {
            offset: (offset_words as u64 - 1) * 2,
            retention_time_ms: be32s(&bytes, base + 4)?,
            total_signal_raw: be32s(&bytes, base + 8)?,
        });
    }
    Ok(DataFile {
        path,
        file_type,
        data_name,
        operator_name,
        acquisition_date,
        instrument_model,
        inlet,
        method_file,
        record_count,
        retention_time_start_ms,
        retention_time_end_ms,
        index,
    })
}

fn packed_abundance(bytes: &[u8], offset: usize) -> Result<i32, String> {
    let word = be16(bytes, offset)?;
    let scale = (bytes
        .get(offset)
        .ok_or_else(|| "Agilent ChemStation abundance is truncated".to_string())?
        >> 6) as u32;
    Ok(((word & 0x3fff) as u32 * (1u32 << (3 * scale))) as i32)
}

pub fn read_spectrum(data_file: &DataFile, index: usize) -> Result<Spectrum, String> {
    let entry = data_file
        .index
        .get(index)
        .ok_or_else(|| format!("Agilent ChemStation spectrum index is out of range: {index}"))?;
    let bytes = fs::read(&data_file.path).map_err(|error| error.to_string())?;
    let offset = entry.offset as usize;
    let words = be16s(&bytes, offset)?;
    let retention_time_ms = be32s(&bytes, offset + 2)?;
    let status_word = be16s(&bytes, offset + 10)?;
    let peak_count = be16s(&bytes, offset + 12)?;
    if words <= 0
        || peak_count < 0
        || (words as u64)
            .checked_mul(2)
            .and_then(|size| offset.checked_add(size as usize))
            .filter(|end| *end <= bytes.len())
            .is_none()
    {
        return Err(format!(
            "Invalid Agilent ChemStation spectrum record at index {index}"
        ));
    }
    let mut points = Vec::with_capacity(peak_count as usize);
    let mut cursor = offset + 18;
    for _ in 0..peak_count {
        let mz = be16(&bytes, cursor)? as f32 / 20.0;
        cursor += 2;
        let intensity = packed_abundance(&bytes, cursor)? as f32;
        cursor += 2;
        points.push((mz, intensity));
    }
    points.sort_by(|left, right| left.0.total_cmp(&right.0));
    let (mz, intensity) = points.into_iter().unzip();
    Ok(Spectrum {
        retention_time_ms,
        status_word,
        mz,
        intensity,
    })
}

fn be32(bytes: &[u8], offset: usize) -> Result<i32, String> {
    bytes
        .get(offset..offset + 4)
        .and_then(|value| value.try_into().ok())
        .map(i32::from_be_bytes)
        .ok_or_else(|| "Agilent ChemStation chromatogram field is truncated".into())
}

fn be64(bytes: &[u8], offset: usize) -> Result<f64, String> {
    bytes
        .get(offset..offset + 8)
        .and_then(|value| value.try_into().ok())
        .map(u64::from_be_bytes)
        .map(f64::from_bits)
        .ok_or_else(|| "Agilent ChemStation chromatogram double is truncated".into())
}

fn le16(bytes: &[u8], offset: usize) -> Result<u16, String> {
    bytes
        .get(offset..offset + 2)
        .and_then(|value| value.try_into().ok())
        .map(u16::from_le_bytes)
        .ok_or_else(|| "Agilent ChemStation chromatogram field is truncated".into())
}

fn le32(bytes: &[u8], offset: usize) -> Result<u32, String> {
    bytes
        .get(offset..offset + 4)
        .and_then(|value| value.try_into().ok())
        .map(u32::from_le_bytes)
        .ok_or_else(|| "Agilent ChemStation chromatogram field is truncated".into())
}

fn le64(bytes: &[u8], offset: usize) -> Result<f64, String> {
    bytes
        .get(offset..offset + 8)
        .and_then(|value| value.try_into().ok())
        .map(u64::from_le_bytes)
        .map(f64::from_bits)
        .ok_or_else(|| "Agilent ChemStation chromatogram double is truncated".into())
}

fn pascal_ascii(bytes: &[u8], offset: usize) -> String {
    let Some(&length) = bytes.get(offset) else {
        return String::new();
    };
    let end = offset.saturating_add(1 + length as usize);
    bytes
        .get(offset + 1..end)
        .map(|value| String::from_utf8_lossy(value).into_owned())
        .unwrap_or_default()
}

fn pascal_utf16(bytes: &[u8], offset: usize) -> String {
    let Some(&length) = bytes.get(offset) else {
        return String::new();
    };
    let mut value = String::new();
    for index in 0..length as usize {
        let Ok(code) = le16(bytes, offset + 1 + index * 2) else {
            break;
        };
        value.push(char::from_u32(code as u32).unwrap_or('?'));
    }
    value
}

fn decode_ch(bytes: &[u8], mut offset: usize) -> Result<Vec<i32>, String> {
    let mut values = Vec::new();
    while offset + 2 <= bytes.len() && bytes[offset] == 16 && bytes[offset + 1] != 0 {
        let count = bytes[offset + 1] as usize;
        offset += 2;
        for _ in 0..count {
            let delta = be16s(bytes, offset)?;
            offset += 2;
            if delta == i16::MIN {
                values.push(be32(bytes, offset)?);
                offset += 4;
            } else {
                values.push(values.last().copied().unwrap_or(0) + delta as i32);
            }
        }
    }
    Ok(values)
}

fn decode_delta(
    bytes: &[u8],
    mut offset: usize,
    count: usize,
    little: bool,
) -> Result<Vec<i32>, String> {
    let mut values = Vec::with_capacity(count);
    for _ in 0..count {
        let delta = if little {
            le16(bytes, offset)? as i16
        } else {
            be16s(bytes, offset)?
        };
        offset += 2;
        if delta == i16::MIN {
            values.push(if little {
                le32(bytes, offset)? as i32
            } else {
                be32(bytes, offset)?
            });
            offset += 4;
        } else {
            values.push(values.last().copied().unwrap_or(0) + delta as i32);
        }
    }
    Ok(values)
}

pub fn read_chromatograms(
    path: impl AsRef<Path>,
) -> Result<Vec<crate::reader::Chromatogram>, String> {
    let root = path.as_ref();
    let mut output = Vec::new();
    for entry in fs::read_dir(root)
        .map_err(|error| error.to_string())?
        .flatten()
    {
        if !entry
            .file_type()
            .map(|kind| kind.is_file())
            .unwrap_or(false)
        {
            continue;
        }
        let name = entry.file_name().to_string_lossy().into_owned();
        let upper = name.to_ascii_uppercase();
        let bytes = fs::read(entry.path()).map_err(|error| error.to_string())?;
        if upper.ends_with(".CH") {
            if pascal_ascii(&bytes, 0) != "130" {
                return Err(format!(
                    "Unsupported Agilent ChemStation .ch version in {}",
                    entry.path().display()
                ));
            }
            const HEADER: usize = 0x1800;
            let scale = be64(&bytes, 0x127c)?;
            let start = be32(&bytes, 0x11a)?;
            let end = be32(&bytes, 0x11e)?;
            let raw = decode_ch(&bytes, HEADER)?;
            if raw.is_empty() {
                continue;
            }
            let step = if raw.len() > 1 {
                (end - start) as f32 / (raw.len() - 1) as f32
            } else {
                0.0
            };
            output.push(crate::reader::Chromatogram {
                id: name.clone(),
                signal_type: "UV".into(),
                chromatogram_type: "UV".into(),
                detector: "UV".into(),
                channel: name,
                units: pascal_utf16(&bytes, 0x104c),
                wavelength_nm: pascal_utf16(&bytes, 0x104c)
                    .split_whitespace()
                    .find_map(|value| value.parse().ok())
                    .unwrap_or(0.0),
                interval_ms: step,
                time: (0..raw.len())
                    .map(|index| (start as f32 + index as f32 * step) / 60000.0)
                    .collect(),
                intensity: raw
                    .into_iter()
                    .map(|value| value as f32 * scale as f32)
                    .collect(),
                ..Default::default()
            });
            output.last_mut().unwrap().start_time =
                output.last().and_then(|value| value.time.first().copied());
            output.last_mut().unwrap().end_time =
                output.last().and_then(|value| value.time.last().copied());
            output.last_mut().unwrap().interval_ms = step * 60000.0;
        } else if upper.ends_with(".UV") {
            if pascal_ascii(&bytes, 0) != "131" {
                return Err(format!(
                    "Unsupported Agilent ChemStation .UV version in {}",
                    entry.path().display()
                ));
            }
            const HEADER: usize = 0x1000;
            let scale = be64(&bytes, 0x0c0d)?;
            let count = be32(&bytes, 0x116)?;
            if count <= 0 {
                continue;
            }
            let mut offset = HEADER;
            let mut times = Vec::new();
            let mut rows: Vec<Vec<f32>> = Vec::new();
            let mut wavelengths = Vec::new();
            for _ in 0..count {
                let label = le16(&bytes, offset)?;
                let segment_length = le16(&bytes, offset + 2)? as usize;
                let time = le32(&bytes, offset + 4)? as f32 / 60000.0;
                let low = le16(&bytes, offset + 8)?;
                let high = le16(&bytes, offset + 10)?;
                let step = le16(&bytes, offset + 12)?;
                if step == 0 || high < low {
                    return Err(
                        "Agilent ChemStation .UV segment has an invalid wavelength grid".into(),
                    );
                }
                let channels = ((high - low) / step + 1) as usize;
                if wavelengths.is_empty() {
                    wavelengths = (0..channels)
                        .map(|index| (low + index as u16 * step) as f32 / 20.0)
                        .collect();
                }
                if channels != wavelengths.len() {
                    return Err(
                        "Agilent ChemStation .UV wavelength grids change between segments".into(),
                    );
                }
                let body = offset + 22;
                let row = if label == 70 {
                    (0..channels)
                        .map(|index| {
                            le64(&bytes, body + index * 8).map(|value| value as f32 * scale as f32)
                        })
                        .collect::<Result<Vec<_>, _>>()?
                } else {
                    decode_delta(&bytes, body, channels, true)?
                        .into_iter()
                        .map(|value| value as f32 * scale as f32)
                        .collect()
                };
                times.push(time);
                rows.push(row);
                offset += if segment_length > 0 {
                    segment_length
                } else {
                    22
                };
            }
            let interval_ms = if times.len() > 1 {
                (times[1] - times[0]) * 60000.0
            } else {
                0.0
            };
            for channel in 0..wavelengths.len() {
                output.push(crate::reader::Chromatogram {
                    id: format!("{}:{}", name, wavelengths[channel]),
                    signal_type: "UV".into(),
                    chromatogram_type: "UV".into(),
                    detector: "UV".into(),
                    channel: name.clone(),
                    units: pascal_utf16(&bytes, 0xc15),
                    wavelength_nm: wavelengths[channel],
                    interval_ms,
                    start_time: times.first().copied(),
                    end_time: times.last().copied(),
                    time: times.clone(),
                    intensity: rows.iter().map(|row| row[channel]).collect(),
                    ..Default::default()
                });
            }
        }
    }
    Ok(output)
}

pub fn open_directory(path: impl AsRef<Path>) -> Result<DataFile, String> {
    let path = path.as_ref();
    let file = fs::read_dir(path)
        .map_err(|error| error.to_string())?
        .flatten()
        .find(|entry| {
            entry
                .file_type()
                .map(|kind| kind.is_file())
                .unwrap_or(false)
                && entry.file_name().to_string_lossy().to_ascii_uppercase() == "MSD1.MS"
        })
        .ok_or_else(|| {
            format!(
                "Agilent ChemStation directory has no MSD1.MS file: {}",
                path.display()
            )
        })?;
    read_data_file(file.path())
}
