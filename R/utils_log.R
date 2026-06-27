# MARK: Internal console logging

#' Internal console logger for StreamFind runtime actions
#'
#' @description
#' Emits concise console messages with a class/component prefix. This helper is
#' intentionally internal and should be used by the class or method that owns the
#' action being reported.
#'
#' @param class Character scalar used inside the log prefix.
#' @param action Character scalar describing the action.
#' @param detail Optional extra details appended to the message.
#'
#' @return Invisibly returns the emitted message.
#' @noRd
.sf_log <- function(class = "Project", action, detail = NULL) {
  checkmate::assert_character(class, len = 1, any.missing = FALSE)
  checkmate::assert_character(action, len = 1, any.missing = FALSE)

  msg <- paste0("[", class, "] ", action)

  if (!is.null(detail)) {
    detail <- paste(as.character(detail), collapse = " ")
    if (nzchar(detail)) {
      msg <- paste(msg, detail)
    }
  }

  message(msg)
  invisible(msg)
}
