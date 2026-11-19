module PdfDocumentStyle
  NAVY = "0B3C5D"
  BLUE = "1D5C7A"
  AMBER = "D99A2B"
  TEXT = "243746"
  MUTED = "607482"
  SURFACE = "F2F6F8"
  GRID = "D6E1E7"

  def draw_pdf_header(pdf, title:, subtitle:)
    pdf.image Rails.root.join("app/assets/images/logo_full.png").to_s, width: 150, position: :left
    pdf.move_down 8
    pdf.fill_color NAVY
    pdf.text pdf_safe(title), size: 20, style: :bold
    pdf.fill_color BLUE
    pdf.text pdf_safe(subtitle), size: 11, style: :bold
    pdf.move_down 10
    pdf.stroke_color AMBER
    pdf.line_width 2
    pdf.stroke_horizontal_line 0, pdf.bounds.width
    pdf.line_width 1
    pdf.move_down 14
    pdf.fill_color TEXT
  end

  def draw_pdf_section(pdf, title)
    pdf.move_down 8
    pdf.fill_color NAVY
    pdf.text pdf_safe(title), size: 11, style: :bold
    pdf.fill_color TEXT
    pdf.move_down 5
  end

  def draw_pdf_table(pdf, rows, widths:, headers: nil, font_size: 9)
    column_widths = widths.map { |width| pdf.bounds.width * width }
    if headers
      draw_pdf_table_row(pdf, headers, column_widths, header: true, font_size: 8)
    end

    rows.each do |row|
      height = pdf_table_row_height(pdf, row, column_widths, font_size)
      if pdf.cursor < height + (headers ? 26 : 0)
        pdf.start_new_page
        draw_pdf_table_row(pdf, headers, column_widths, header: true, font_size: 8) if headers
      end
      draw_pdf_table_row(pdf, row, column_widths, font_size: font_size)
    end
  end

  def pdf_safe(value)
    value.to_s.encode("Windows-1252", invalid: :replace, undef: :replace, replace: "?").encode("UTF-8")
  end

  private

  def pdf_table_row_height(pdf, row, widths, font_size)
    row.each_with_index.map do |value, index|
      pdf.height_of(pdf_safe(value), width: widths[index] - 12, size: font_size, leading: 2) + 12
    end.max.then { |height| [ height, 25 ].max }
  end

  def draw_pdf_table_row(pdf, row, widths, header: false, font_size:)
    height = header ? 25 : pdf_table_row_height(pdf, row, widths, font_size)
    top = pdf.cursor
    left = 0

    row.each_with_index do |value, index|
      width = widths[index]
      pdf.fill_color(header ? NAVY : (index.even? ? SURFACE : "FFFFFF"))
      pdf.fill_rectangle [ left, top ], width, height
      pdf.stroke_color GRID
      pdf.stroke_rectangle [ left, top ], width, height
      pdf.fill_color(header ? "FFFFFF" : TEXT)
      pdf.text_box pdf_safe(value), at: [ left + 6, top - 5 ], width: width - 12, height: height - 10,
        size: font_size, style: header ? :bold : :normal, valign: :center, leading: 2
      left += width
    end

    pdf.move_cursor_to top - height
    pdf.fill_color TEXT
  end
end
