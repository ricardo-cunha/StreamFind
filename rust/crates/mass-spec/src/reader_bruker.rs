use duckdb::Connection;
use std::fs::File;
use std::io::{Read, Seek, SeekFrom};
use std::path::{Path, PathBuf};

#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum Family {
    Baf,
    Tsf,
    Unknown,
}

#[derive(Debug, Clone, PartialEq)]
pub struct TsfFrame {
    pub id: i64,
    pub retention_time: f64,
    pub polarity: String,
    pub scan_mode: i32,
    pub msms_type: i32,
    pub tims_id: i64,
    pub max_intensity: f64,
    pub summed_intensities: f64,
    pub num_peaks: i32,
    pub mz_calibration: i32,
    pub t1: f64,
    pub t2: f64,
    pub property_group: i32,
}

#[derive(Debug, Clone, PartialEq)]
pub struct TsfMsMsInfo {
    pub frame: i64,
    pub parent: i64,
    pub trigger_mass: f64,
    pub isolation_width: f64,
    pub precursor_charge: i32,
    pub collision_energy: f64,
}

#[derive(Debug, Clone, PartialEq)]
pub struct TsfLineSpectrum {
    pub tof: Vec<f64>,
    pub intensity: Vec<f64>,
}

#[derive(Debug, Clone, PartialEq)]
pub struct BafLineSpectrum {
    pub coordinate: Vec<f64>,
    pub intensity: Vec<f64>,
    pub width: Vec<f64>,
}

#[derive(Debug, Clone, PartialEq)]
pub struct BafProfileSpectrum {
    pub intensity: Vec<u32>,
}

#[derive(Debug, Clone, PartialEq)]
pub struct TsfCalibration {
    pub id: i32,
    pub model_type: i32,
    pub digitizer_timebase: f64,
    pub digitizer_delay: f64,
    pub t1: f64,
    pub t2: f64,
    pub dc1: f64,
    pub dc2: f64,
    pub c0: f64,
    pub c1: f64,
    pub c2: f64,
    pub c3: f64,
    pub c4: f64,
    pub mz_min: f64,
    pub mz_max: f64,
    pub tof_max: u32,
    pub otof_control: bool,
}

pub fn detect_family(path: &Path) -> Family {
    if !path.is_dir() {
        return Family::Unknown;
    }
    if path.join("analysis.tsf").is_file() && path.join("analysis.tsf_bin").is_file() {
        Family::Tsf
    } else if path.join("analysis.baf").is_file()
        && path.join("analysis.baf_idx").is_file()
        && path.join("analysis.sqlite").is_file()
    {
        Family::Baf
    } else {
        Family::Unknown
    }
}

fn sql_quote(path: &Path) -> String {
    path.to_string_lossy().replace('\'', "''")
}

fn sqlite_scan(_connection: &Connection, database: &Path, table: &str) -> Result<String, String> {
    let database = sql_quote(database);
    Ok(format!("sqlite_scan('{database}','{table}')"))
}

pub fn read_tsf_frames(path: impl AsRef<Path>) -> Result<Vec<TsfFrame>, String> {
    let path = path.as_ref();
    if detect_family(path) != Family::Tsf {
        return Err(format!("Not a Bruker TSF directory: {}", path.display()));
    }
    let connection = Connection::open_in_memory().map_err(|error| error.to_string())?;
    connection
        .execute_batch("LOAD sqlite")
        .map_err(|error| error.to_string())?;
    let table = sqlite_scan(&connection, &path.join("analysis.tsf"), "Frames")?;
    let mut statement = connection
        .prepare(&format!("SELECT Id,Time,Polarity,ScanMode,MsMsType,TimsId,MaxIntensity,SummedIntensities,NumPeaks,MzCalibration,T1,T2,PropertyGroup FROM {table} ORDER BY Id"))
        .map_err(|error| error.to_string())?;
    let rows = statement
        .query_map([], |row| {
            Ok(TsfFrame {
                id: row.get(0)?,
                retention_time: row.get(1)?,
                polarity: row.get(2)?,
                scan_mode: row.get(3)?,
                msms_type: row.get(4)?,
                tims_id: row.get(5)?,
                max_intensity: row.get(6)?,
                summed_intensities: row.get(7)?,
                num_peaks: row.get(8)?,
                mz_calibration: row.get(9)?,
                t1: row.get(10)?,
                t2: row.get(11)?,
                property_group: row.get(12)?,
            })
        })
        .map_err(|error| error.to_string())?;
    rows.map(|row| row.map_err(|error| error.to_string()))
        .collect()
}

pub fn read_tsf_msms_info(path: impl AsRef<Path>) -> Result<Vec<TsfMsMsInfo>, String> {
    let path = path.as_ref();
    if detect_family(path) != Family::Tsf {
        return Err(format!("Not a Bruker TSF directory: {}", path.display()));
    }
    let connection = Connection::open_in_memory().map_err(|error| error.to_string())?;
    connection
        .execute_batch("LOAD sqlite")
        .map_err(|error| error.to_string())?;
    let table = sqlite_scan(&connection, &path.join("analysis.tsf"), "FrameMsMsInfo")?;
    let mut statement = connection
        .prepare(&format!("SELECT Frame,Parent,TriggerMass,IsolationWidth,PrecursorCharge,CollisionEnergy FROM {table} ORDER BY Frame"))
        .map_err(|error| error.to_string())?;
    let rows = statement
        .query_map([], |row| {
            Ok(TsfMsMsInfo {
                frame: row.get(0)?,
                parent: row.get(1)?,
                trigger_mass: row.get::<_, Option<f64>>(2)?.unwrap_or(0.0),
                isolation_width: row.get::<_, Option<f64>>(3)?.unwrap_or(0.0),
                precursor_charge: row.get::<_, Option<i32>>(4)?.unwrap_or(0),
                collision_energy: row.get::<_, Option<f64>>(5)?.unwrap_or(0.0),
            })
        })
        .map_err(|error| error.to_string())?;
    rows.map(|row| row.map_err(|error| error.to_string()))
        .collect()
}

pub fn read_tsf_line_spectrum(
    path: impl AsRef<Path>,
    frame: &TsfFrame,
) -> Result<TsfLineSpectrum, String> {
    let path = path.as_ref();
    if detect_family(path) != Family::Tsf {
        return Err(format!("Not a Bruker TSF directory: {}", path.display()));
    }
    if frame.tims_id < 0 || frame.num_peaks < 0 {
        return Err("Invalid TSF frame locator or peak count".into());
    }
    let mut input = File::open(path.join("analysis.tsf_bin")).map_err(|error| error.to_string())?;
    let file_size = input.metadata().map_err(|error| error.to_string())?.len();
    let offset = frame.tims_id as u64;
    if offset.checked_add(8).filter(|end| *end <= file_size).is_none() {
        return Err("TSF frame offset is outside analysis.tsf_bin".into());
    }
    input.seek(SeekFrom::Start(offset)).map_err(|error| error.to_string())?;
    let mut header = [0u8; 8];
    input.read_exact(&mut header).map_err(|error| error.to_string())?;
    let block_size = u32::from_le_bytes(header[0..4].try_into().unwrap()) as u64;
    let compressed_size = u32::from_le_bytes(header[4..8].try_into().unwrap()) as u64;
    if block_size < 8 || compressed_size > block_size - 8 {
        return Err("Invalid TSF frame block header".into());
    }
    if offset.checked_add(8).and_then(|value| value.checked_add(compressed_size)).filter(|end| *end <= file_size).is_none() {
        return Err("TSF compressed frame exceeds analysis.tsf_bin".into());
    }
    let mut compressed = vec![0u8; compressed_size as usize];
    input.read_exact(&mut compressed).map_err(|error| error.to_string())?;
    let expected = (frame.num_peaks as usize)
        .checked_mul(16)
        .ok_or_else(|| "TSF frame is too large".to_string())?;
    let decoded = zstd::bulk::decompress(&compressed, expected).map_err(|error| error.to_string())?;
    if decoded.len() != expected {
        return Err(format!("Unexpected TSF type-3 decompressed size: {}", decoded.len()));
    }
    let count = frame.num_peaks as usize;
    let mut tof = Vec::with_capacity(count);
    let mut intensity = Vec::with_capacity(count);
    for index in 0..count {
        let tof_start = index * 8;
        tof.push(f64::from_le_bytes(decoded[tof_start..tof_start + 8].try_into().unwrap()));
        let intensity_start = count * 8 + index * 4;
        intensity.push(f32::from_le_bytes(decoded[intensity_start..intensity_start + 4].try_into().unwrap()) as f64);
    }
    Ok(TsfLineSpectrum { tof, intensity })
}

pub fn read_tsf_calibration(
    path: impl AsRef<Path>,
    frame: &TsfFrame,
) -> Result<TsfCalibration, String> {
    let path = path.as_ref();
    if detect_family(path) != Family::Tsf {
        return Err(format!("Not a Bruker TSF directory: {}", path.display()));
    }
    let connection = Connection::open_in_memory().map_err(|error| error.to_string())?;
    connection
        .execute_batch("LOAD sqlite")
        .map_err(|error| error.to_string())?;
    let database = sqlite_scan(&connection, &path.join("analysis.tsf"), "MzCalibration")?;
    let sql = format!("SELECT CAST(Id AS VARCHAR),CAST(ModelType AS VARCHAR),CAST(DigitizerTimebase AS VARCHAR),CAST(DigitizerDelay AS VARCHAR),CAST(T1 AS VARCHAR),CAST(T2 AS VARCHAR),CAST(dC1 AS VARCHAR),CAST(dC2 AS VARCHAR),CAST(C0 AS VARCHAR),CAST(C1 AS VARCHAR),CAST(C2 AS VARCHAR),CAST(C3 AS VARCHAR),CAST(C4 AS VARCHAR) FROM {database} WHERE Id = {}", frame.mz_calibration);
    let calibration = connection
        .query_row(&sql, [], |row| {
            Ok(TsfCalibration {
                id: row.get::<_, String>(0)?.parse().map_err(|_| duckdb::Error::ToSqlConversionFailure("invalid TSF calibration id".into()))?,
                model_type: row.get::<_, String>(1)?.parse().map_err(|_| duckdb::Error::ToSqlConversionFailure("invalid TSF calibration model".into()))?,
                digitizer_timebase: row.get::<_, String>(2)?.parse().map_err(|_| duckdb::Error::ToSqlConversionFailure("invalid TSF timebase".into()))?,
                digitizer_delay: row.get::<_, String>(3)?.parse().map_err(|_| duckdb::Error::ToSqlConversionFailure("invalid TSF delay".into()))?,
                t1: row.get::<_, String>(4)?.parse().map_err(|_| duckdb::Error::ToSqlConversionFailure("invalid TSF T1".into()))?,
                t2: row.get::<_, String>(5)?.parse().map_err(|_| duckdb::Error::ToSqlConversionFailure("invalid TSF T2".into()))?,
                dc1: row.get::<_, String>(6)?.parse().map_err(|_| duckdb::Error::ToSqlConversionFailure("invalid TSF dC1".into()))?,
                dc2: row.get::<_, String>(7)?.parse().map_err(|_| duckdb::Error::ToSqlConversionFailure("invalid TSF dC2".into()))?,
                c0: row.get::<_, String>(8)?.parse().map_err(|_| duckdb::Error::ToSqlConversionFailure("invalid TSF C0".into()))?,
                c1: row.get::<_, String>(9)?.parse().map_err(|_| duckdb::Error::ToSqlConversionFailure("invalid TSF C1".into()))?,
                c2: row.get::<_, String>(10)?.parse().map_err(|_| duckdb::Error::ToSqlConversionFailure("invalid TSF C2".into()))?,
                c3: row.get::<_, String>(11)?.parse().map_err(|_| duckdb::Error::ToSqlConversionFailure("invalid TSF C3".into()))?,
                c4: row.get::<_, String>(12)?.parse().map_err(|_| duckdb::Error::ToSqlConversionFailure("invalid TSF C4".into()))?,
                mz_min: 0.0,
                mz_max: 0.0,
                tof_max: 0,
                otof_control: false,
            })
        })
        .map_err(|error| error.to_string())?;
    let metadata = sqlite_scan(&connection, &path.join("analysis.tsf"), "GlobalMetadata")?;
    let mut statement = connection
        .prepare(&format!("SELECT Key,Value FROM {metadata} WHERE Key IN ('MzAcqRangeLower','MzAcqRangeUpper','DigitizerNumSamples','AcquisitionSoftware')"))
        .map_err(|error| error.to_string())?;
    let rows = statement
        .query_map([], |row| Ok((row.get::<_, String>(0)?, row.get::<_, String>(1)?)))
        .map_err(|error| error.to_string())?;
    let mut calibration = calibration;
    for row in rows {
        let (key, value) = row.map_err(|error| error.to_string())?;
        match key.as_str() {
            "MzAcqRangeLower" => calibration.mz_min = value.parse().map_err(|_| "Invalid TSF lower m/z".to_string())?,
            "MzAcqRangeUpper" => calibration.mz_max = value.parse().map_err(|_| "Invalid TSF upper m/z".to_string())?,
            "DigitizerNumSamples" => calibration.tof_max = value.parse().map_err(|_| "Invalid TSF digitizer sample count".to_string())?,
            "AcquisitionSoftware" => calibration.otof_control = value == "Bruker otofControl",
            _ => {}
        }
    }
    if !(calibration.mz_min > 0.0 && calibration.mz_max > calibration.mz_min && calibration.tof_max > 0) {
        return Err("Incomplete TSF calibration metadata".into());
    }
    Ok(calibration)
}

pub fn tsf_tof_to_mz(calibration: &TsfCalibration, tof: &[f64]) -> Vec<f64> {
    let mut mz_min = calibration.mz_min;
    let mut mz_max = calibration.mz_max;
    if calibration.otof_control {
        mz_min -= 5.0;
        mz_max += 5.0;
    }
    let intercept = mz_min.sqrt();
    let slope = (mz_max.sqrt() - intercept) / f64::from(calibration.tof_max);
    tof.iter().map(|value| (intercept + slope * value).powi(2)).collect()
}

pub fn tsf_database_path(path: impl AsRef<Path>) -> PathBuf {
    path.as_ref().join("analysis.tsf")
}

pub fn read_baf_line_spectrum(
    path: impl AsRef<Path>,
    line_array_id: u64,
) -> Result<BafLineSpectrum, String> {
    let path = path.as_ref();
    if detect_family(path) != Family::Baf {
        return Err(format!("Not a Bruker BAF directory: {}", path.display()));
    }
    let type_tag = (line_array_id >> 56) as u8;
    if type_tag != 0x11 && type_tag != 0x16 {
        return Err("BAF array ID is not a line-spectrum array".into());
    }
    let offset = line_array_id & 0x00ff_ffff_ffff_ffff;
    let mut input = File::open(path.join("analysis.baf")).map_err(|error| error.to_string())?;
    let file_size = input.metadata().map_err(|error| error.to_string())?.len();
    if offset.checked_add(92).filter(|end| *end <= file_size).is_none() {
        return Err("BAF line-array offset is outside analysis.baf".into());
    }
    input.seek(SeekFrom::Start(offset)).map_err(|error| error.to_string())?;
    let mut header = [0u8; 92];
    input.read_exact(&mut header).map_err(|error| error.to_string())?;
    let block_size = u32::from_le_bytes(header[0..4].try_into().unwrap()) as u64;
    let block_type = u32::from_le_bytes(header[4..8].try_into().unwrap());
    let count = u32::from_le_bytes(header[24..28].try_into().unwrap()) as usize;
    let expected = 92u64
        .checked_add((count as u64).checked_mul(16).ok_or_else(|| "BAF line block is too large".to_string())?)
        .ok_or_else(|| "BAF line block is too large".to_string())?;
    if block_type != 0xbfa0_1002 || block_size != expected || offset.checked_add(block_size).filter(|end| *end <= file_size).is_none() {
    return Err(format!("Invalid BAF LineSpectrumBlock: offset={offset} size={block_size} type=0x{block_type:08x} count={count} expected={expected} file_size={file_size}"));
    }
    let mut payload = vec![0u8; (expected - 92) as usize];
    input.read_exact(&mut payload).map_err(|error| error.to_string())?;
    let mut coordinate = Vec::with_capacity(count);
    let mut intensity = Vec::with_capacity(count);
    let mut width = Vec::with_capacity(count);
    for index in 0..count {
        let start = index * 8;
        coordinate.push(f64::from_le_bytes(payload[start..start + 8].try_into().unwrap()));
        let start = count * 8 + index * 4;
        intensity.push(f32::from_le_bytes(payload[start..start + 4].try_into().unwrap()) as f64);
        let start = count * 12 + index * 4;
        width.push(f32::from_le_bytes(payload[start..start + 4].try_into().unwrap()) as f64);
    }
    Ok(BafLineSpectrum { coordinate, intensity, width })
}

struct BafBitReader<'a> {
    bytes: &'a [u8],
    position: usize,
    buffer: u32,
    bits: u32,
}

impl<'a> BafBitReader<'a> {
    fn new(bytes: &'a [u8], position: usize) -> Self {
        Self { bytes, position, buffer: 0, bits: 0 }
    }

    fn read(&mut self, count: u32) -> Result<u32, String> {
        if !(1..=32).contains(&count) {
            return Err("invalid BAF profile bit count".into());
        }
        let mut value = 0u32;
        let mut remaining = count;
        while remaining != 0 {
            if self.bits == 0 {
                if self.position.checked_add(4).filter(|end| *end <= self.bytes.len()).is_none() {
                    return Err("BAF profile bitstream ended during refill".into());
                }
                self.buffer = u32::from_be_bytes(self.bytes[self.position..self.position + 4].try_into().unwrap());
                self.position += 4;
                self.bits = 32;
            }
            let take = remaining.min(self.bits);
            value = if take == 32 { self.buffer } else { (value << take) | (self.buffer >> (32 - take)) };
            self.buffer = if take == 32 { 0 } else { self.buffer << take };
            self.bits -= take;
            remaining -= take;
        }
        Ok(value)
    }
}

pub fn read_baf_profile_spectrum(
    path: impl AsRef<Path>,
    profile_array_id: u64,
) -> Result<BafProfileSpectrum, String> {
    let path = path.as_ref();
    if detect_family(path) != Family::Baf {
        return Err(format!("Not a Bruker BAF directory: {}", path.display()));
    }
    if (profile_array_id >> 56) as u8 != 0x42 {
        return Err("BAF array ID is not a ProfileIntensityId".into());
    }
    let offset = (profile_array_id & 0x00ff_ffff_ffff_ffff) as usize;
    let bytes = std::fs::read(path.join("analysis.baf")).map_err(|error| error.to_string())?;
    if offset.checked_add(0x34).filter(|end| *end <= bytes.len()).is_none() {
        return Err("BAF profile-array offset is outside analysis.baf".into());
    }
    let block_size = u32::from_le_bytes(bytes[offset..offset + 4].try_into().unwrap()) as usize;
    let block_type = u32::from_le_bytes(bytes[offset + 4..offset + 8].try_into().unwrap());
    if block_type != 0xbfa0_1001 || block_size < 0x52 || offset.checked_add(block_size).filter(|end| *end <= bytes.len()).is_none() {
        return Err("Invalid BAF DataVectorBlock".into());
    }
    let block = &bytes[offset..offset + block_size];
    if u32::from_le_bytes(block[0x2c..0x30].try_into().unwrap()) != 0xee77 {
        return Err("Invalid BAF profile decoder header".into());
    }
    let count = u32::from_le_bytes(block[0x30..0x34].try_into().unwrap()) as usize;
    let table_size = u32::from_be_bytes(block[0x34..0x38].try_into().unwrap()) as usize;
    if table_size != 0x1a || 0x38 + table_size > block.len() {
        return Err("Unsupported BAF profile decoder table header".into());
    }
    let table = &block[0x38..0x38 + table_size];
    let widths = [0u8, 4, 5, 6, 7, 9, 10, 11, 32];
    let bases = [0i64, 1, 0x11, 0x31, 0x71, 0xf1, 0x2f1, 0x6f1, 0];
    let slots = [0usize, 0, 1, 2, 3, 4, 5, 6, 7, 8];
    if table[..9] != widths || table[25] != 10 {
        return Err("Unsupported BAF profile decoder table values".into());
    }
    let mut reader = BafBitReader::new(block, 0x34 + 4 + table_size);
    let mut intensity = vec![0u32; count];
    let mut position = 0usize;
    let mut previous = 0u32;
    while position < count {
        let mut control = 0usize;
        loop {
            let marker = reader.read(1)?;
            control += 1;
            if marker == 0 { continue; }
            if control == 16 { return Err("invalid BAF profile control terminator".into()); }
            if control == 10 {
                let run = reader.read(32)? as usize;
                if run == 0 { break; }
                if run > count - position { return Err("BAF profile zero run exceeds output length".into()); }
                position += run;
                break;
            }
            let slot = *slots.get(control).ok_or_else(|| "BAF profile control index is outside decoder tables".to_string())?;
            let width = widths[slot] as u32;
            if width == 0 {
                intensity[position] = previous;
            } else if width < 32 {
                let raw = reader.read(width + 1)?;
                let magnitude = (raw >> 1) as i64 + bases[slot];
                let delta = if raw & 1 == 0 { magnitude } else { -magnitude };
                let value = previous as i64 + delta;
                if !(0..=u32::MAX as i64).contains(&value) { return Err("BAF profile delta exceeds u32 range".into()); }
                previous = value as u32;
                intensity[position] = previous;
            } else {
                previous = reader.read(32)?;
                intensity[position] = previous;
            }
            position += 1;
            break;
        }
    }
    Ok(BafProfileSpectrum { intensity })
}
