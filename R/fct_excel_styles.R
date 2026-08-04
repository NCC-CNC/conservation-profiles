# Verdana is the NCC brand-specified spreadsheet substitute for Myriad Pro
header_style <- openxlsx::createStyle(
  fontName = "Verdana", fontSize = 10,
  fontColour = "#FFFFFF", fgFill = "#33862B",
  textDecoration = "bold", halign = "left", valign = "center",
  border = "BottomLeftRight", borderColour = "#2D602E", borderStyle = "medium",
  wrapText = TRUE
)
body_style <- openxlsx::createStyle(
  fontName = "Verdana", fontSize = 10, fontColour = "#000000",
  halign = "left", valign = "center",
  border = "Bottom", borderColour = "#CCCCCC", borderStyle = "thin"
)
alt_style <- openxlsx::createStyle(
  fontName = "Verdana", fontSize = 10, fontColour = "#000000",
  fgFill = "#EEF5EC",
  halign = "left", valign = "center",
  border = "Bottom", borderColour = "#CCCCCC", borderStyle = "thin"
)

apply_ncc_table <- function(wb, sheet, df, start_row = 1) {
  n_cols <- ncol(df)
  n_rows <- nrow(df)
  openxlsx::addStyle(wb, sheet, header_style, rows = start_row, cols = 1:n_cols, gridExpand = TRUE)
  for (i in seq_len(n_rows)) {
    s <- if (i %% 2 == 1) body_style else alt_style
    openxlsx::addStyle(wb, sheet, s, rows = start_row + i, cols = 1:n_cols, gridExpand = TRUE)
  }
  openxlsx::setColWidths(wb, sheet, cols = 1:n_cols, widths = "auto")
}
