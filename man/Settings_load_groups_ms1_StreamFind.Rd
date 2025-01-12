% Generated by roxygen2: do not edit by hand
% Please edit documentation in R/fct_ms_default_ProcessingSettings.R
\name{Settings_load_groups_ms1_StreamFind}
\alias{Settings_load_groups_ms1_StreamFind}
\alias{validate.Settings_load_groups_ms1_StreamFind}
\title{Settings_load_groups_ms1_StreamFind}
\usage{
Settings_load_groups_ms1_StreamFind(
  mzClust = 0.003,
  presence = 0.8,
  minIntensity = 1000,
  verbose = FALSE,
  filtered = FALSE,
  runParallel = TRUE
)

\method{validate}{Settings_load_groups_ms1_StreamFind}(x)
}
\arguments{
\item{mzClust}{Numeric value with the mass deviation threshold (in Da) to
cluster mass traces. Highly dependent on the mass resolution of the MS data.}

\item{presence}{Numeric of length one with the required presence ratio from
0 (i.e., doesn't need to be present in any spectra) to 1 (i.e., must be
present in all spectra) for traces during clustering of spectra.}

\item{minIntensity}{Numeric value with the minimum intensity.}

\item{verbose}{Logical with length one. Set \code{TRUE} to output diagnostic and
result messages. When \code{FALSE}, some messages are omitted.}

\item{filtered}{Logical. When \code{TRUE}, filtered features/groups are considered.}

\item{runParallel}{Logical of length one. Set to \code{TRUE} for parallel
processing. Note that parallel processing is not always faster due to
overhead.}

\item{x}{A Settings_load_groups_ms1_StreamFind S3 class object.}
}
\value{
A ProcessingSettings S3 class object with subclass
Settings_load_groups_ms1_StreamFind.
}
\description{
Settings for loading MS1 spectra for feature groups.
}
\section{Methods (by generic)}{
\itemize{
\item \code{validate(Settings_load_groups_ms1_StreamFind)}: Validates the object structure, returning a logical value of length one.

}}
