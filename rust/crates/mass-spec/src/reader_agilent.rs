use std::fs;
use std::io::{Read, Seek, SeekFrom};
use std::path::{Path, PathBuf};

#[derive(Debug, Clone, PartialEq)]
pub struct ScanRecord {
    pub scan_id: u32,
    pub scan_method_id: u32,
    pub time_segment_id: u32,
    pub scan_time_minutes: f64,
    pub ms_level: i32,
    pub scan_type: i32,
    pub tic: f64,
    pub base_peak_mz: f64,
    pub base_peak_value: f64,
    pub calibration_id: i32,
    pub cycle_number: i32,
    pub spectrum_format_id: u32,
    pub spectrum_offset: u64,
    pub spectrum_byte_count: u32,
    pub spectrum_point_count: u32,
    pub spectrum_uncompressed_byte_count: u32,
    pub spectrum_min_x: f64,
    pub spectrum_max_x: f64,
    pub spectrum_min_y: f64,
    pub spectrum_max_y: f64,
    pub spectrum_measured_noise: f64,
}

#[derive(Debug, Clone, PartialEq)]
pub struct ProfileSpectrum {
    pub mz: Vec<f64>,
    pub intensity: Vec<f32>,
}

const SCAN_PREAMBLE_SIZE: usize = 228;
const SCAN_RECORD_SIZE: usize = 220;
const PROFILE_BLOCK_PREAMBLE_SIZE: usize = 16;
const MAX_PROFILE_UNCOMPRESSED_SIZE: usize = 512 * 1024 * 1024;

pub fn is_agilent_mass_hunter_directory(path: &Path) -> bool {
    let acq = path.join("AcqData");
    path.is_dir()
        && acq.join("Contents.xml").is_file()
        && acq.join("MSScan.bin").is_file()
        && acq.join("MSProfile.bin").is_file()
}

fn u32_at(bytes: &[u8], offset: usize) -> Result<u32, String> {
    let slice = bytes
        .get(offset..offset + 4)
        .ok_or_else(|| "Agilent binary record is truncated".to_string())?;
    Ok(u32::from_le_bytes(slice.try_into().unwrap()))
}

fn f64_at(bytes: &[u8], offset: usize) -> Result<f64, String> {
    let slice = bytes
        .get(offset..offset + 8)
        .ok_or_else(|| "Agilent binary double field is truncated".to_string())?;
    Ok(f64::from_le_bytes(slice.try_into().unwrap()))
}

fn decompress_lzf(input: &[u8], maximum_size: usize) -> Result<Vec<u8>, String> {
    if maximum_size > MAX_PROFILE_UNCOMPRESSED_SIZE {
        return Err("Agilent LZF profile block exceeds the decompression safety limit".to_string());
    }
    let mut output = vec![0u8; maximum_size];
    let (mut input_index, mut output_index) = (0usize, 0usize);
    while input_index < input.len() && output_index < output.len() {
        let control = input[input_index] as usize;
        input_index += 1;
        if control < 32 {
            let length = control + 1;
            if input_index + length > input.len() || output_index + length > output.len() {
                return Err("Agilent LZF literal run is outside the profile block".to_string());
            }
            output[output_index..output_index + length]
                .copy_from_slice(&input[input_index..input_index + length]);
            input_index += length;
            output_index += length;
            continue;
        }

        let mut length = control >> 5;
        let mut reference = output_index
            .checked_sub(((control & 31) << 8) + 1)
            .ok_or_else(|| "Agilent LZF back reference precedes profile output".to_string())?;
        if length == 7 {
            let extra = *input
                .get(input_index)
                .ok_or_else(|| "Agilent LZF profile block has a truncated length".to_string())?;
            length += extra as usize;
            input_index += 1;
        }
        let distance = *input
            .get(input_index)
            .ok_or_else(|| "Agilent LZF profile block has a truncated distance".to_string())?;
        input_index += 1;
        reference = reference
            .checked_sub(distance as usize)
            .ok_or_else(|| "Agilent LZF profile block has an invalid distance".to_string())?;
        length += 2;
        if output_index + length > output.len() {
            return Err("Agilent LZF match run exceeds profile output".to_string());
        }
        for _ in 0..length {
            output[output_index] = output[reference];
            output_index += 1;
            reference += 1;
        }
    }
    output.truncate(output_index);
    Ok(output)
}

pub fn read_scan_records(path: impl AsRef<Path>) -> Result<Vec<ScanRecord>, String> {
    let path = path.as_ref();
    if !is_agilent_mass_hunter_directory(path) {
        return Err(format!(
            "Not an Agilent MassHunter .d directory: {}",
            path.display()
        ));
    }
    let bytes = fs::read(PathBuf::from(path).join("AcqData/MSScan.bin"))
        .map_err(|error| error.to_string())?;
    if bytes.len() < SCAN_PREAMBLE_SIZE
        || (bytes.len() - SCAN_PREAMBLE_SIZE) % SCAN_RECORD_SIZE != 0
    {
        return Err("Agilent MSScan.bin has an unsupported record layout".to_string());
    }
    let mut records = Vec::with_capacity((bytes.len() - SCAN_PREAMBLE_SIZE) / SCAN_RECORD_SIZE);
    for offset in (SCAN_PREAMBLE_SIZE..bytes.len()).step_by(SCAN_RECORD_SIZE) {
        records.push(ScanRecord {
            scan_id: u32_at(&bytes, offset)?,
            scan_method_id: u32_at(&bytes, offset + 4)?,
            time_segment_id: u32_at(&bytes, offset + 8)?,
            scan_time_minutes: f64_at(&bytes, offset + 12)?,
            ms_level: u32_at(&bytes, offset + 20)? as i32,
            scan_type: u32_at(&bytes, offset + 24)? as i32,
            tic: f64_at(&bytes, offset + 28)?,
            base_peak_mz: f64_at(&bytes, offset + 36)?,
            base_peak_value: f64_at(&bytes, offset + 44)?,
            calibration_id: u32_at(&bytes, offset + 52)? as i32,
            cycle_number: u32_at(&bytes, offset + 56)? as i32,
            spectrum_format_id: u32_at(&bytes, offset + 156)?,
            spectrum_offset: u64::from_le_bytes(
                bytes[offset + 160..offset + 168].try_into().unwrap(),
            ),
            spectrum_byte_count: u32_at(&bytes, offset + 168)?,
            spectrum_point_count: u32_at(&bytes, offset + 172)?,
            spectrum_uncompressed_byte_count: u32_at(&bytes, offset + 176)?,
            spectrum_min_x: f64_at(&bytes, offset + 180)?,
            spectrum_max_x: f64_at(&bytes, offset + 188)?,
            spectrum_min_y: f64_at(&bytes, offset + 196)?,
            spectrum_max_y: f64_at(&bytes, offset + 204)?,
            spectrum_measured_noise: f64_at(&bytes, offset + 212)?,
        });
    }
    Ok(records)
}

pub fn read_profile_spectrum(
    path: impl AsRef<Path>,
    record: &ScanRecord,
) -> Result<ProfileSpectrum, String> {
    if record.spectrum_format_id != 1 {
        return Err("Agilent scan does not contain a SpectrumFormatID=1 profile block".to_string());
    }
    if record.spectrum_byte_count < PROFILE_BLOCK_PREAMBLE_SIZE as u32 {
        return Err("Agilent profile block is shorter than its preamble".to_string());
    }
    if record.spectrum_point_count == 0 {
        return Ok(ProfileSpectrum {
            mz: Vec::new(),
            intensity: Vec::new(),
        });
    }
    let point_bytes = record.spectrum_point_count as usize * std::mem::size_of::<u32>();
    if (record.spectrum_uncompressed_byte_count as usize) < point_bytes {
        return Err("Agilent profile uncompressed byte count is smaller than its point array".to_string());
    }

    let profile_path = path.as_ref().join("AcqData/MSProfile.bin");
    let profile_size = fs::metadata(&profile_path)
        .map_err(|error| error.to_string())?
        .len();
    let block_end = record
        .spectrum_offset
        .checked_add(record.spectrum_byte_count as u64)
        .ok_or_else(|| "Agilent profile block offset overflow".to_string())?;
    if block_end > profile_size {
        return Err("Agilent profile block is outside MSProfile.bin".to_string());
    }
    let mut profile_file = fs::File::open(profile_path).map_err(|error| error.to_string())?;
    profile_file
        .seek(SeekFrom::Start(record.spectrum_offset))
        .map_err(|error| error.to_string())?;
    let mut block = vec![0u8; record.spectrum_byte_count as usize];
    profile_file
        .read_exact(&mut block)
        .map_err(|error| error.to_string())?;
    let decoded = decompress_lzf(&block, record.spectrum_uncompressed_byte_count as usize)
        .or_else(|_| {
            decompress_lzf(
                &block[PROFILE_BLOCK_PREAMBLE_SIZE..],
                record.spectrum_uncompressed_byte_count as usize,
            )
        })?;
    let data_offset = if decoded.len() == point_bytes {
        0
    } else {
        PROFILE_BLOCK_PREAMBLE_SIZE
    };
    if decoded.len() < data_offset + point_bytes {
        return Err("Agilent LZF profile block is shorter than its declared point count".to_string());
    }

    let step = if record.spectrum_point_count > 1 {
        (record.spectrum_max_x - record.spectrum_min_x)
            / (record.spectrum_point_count as f64 - 1.0)
    } else {
        0.0
    };
    let mut mz = Vec::with_capacity(record.spectrum_point_count as usize);
    let mut intensity = Vec::with_capacity(record.spectrum_point_count as usize);
    for index in 0..record.spectrum_point_count as usize {
        mz.push(record.spectrum_min_x + index as f64 * step);
        intensity.push(u32_at(&decoded, data_offset + index * 4)? as f32);
    }
    Ok(ProfileSpectrum { mz, intensity })
}
