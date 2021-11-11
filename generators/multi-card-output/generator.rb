# frozen_string_literal: true

# #######################################################################
#
# Cards Against Humanity Generator
# --------------------------------
#
# A card generator for Cards Against Humanity
#
# https://dev.bloomgogo.com/projects/cah-generator
#
# Created by Miguel Angel Fernandez Gutierrez (@mianfg)
# https://mianfg.bloomgogo.com/
#
# Based on Bigger, Blacker Cards
# https://github.com/bbcards/bbcards
#
# #######################################################################

require 'prawn'
require 'prawn/measurement_extensions'
require 'fileutils'

MM_PER_INCH = 25.4

PAPER_NAME   = 'LETTER'
PAPER_HEIGHT = (MM_PER_INCH * 11.0).mm
PAPER_WIDTH  = (MM_PER_INCH * 8.5).mm

def get_card_geometry(card_width_inches = 2.0, card_height_inches = 2.0, rounded_corners = false, one_card_per_page = false)
  card_geometry = {}
  card_geometry['card_width']        = (MM_PER_INCH * card_width_inches).mm
  card_geometry['card_height']       = (MM_PER_INCH * card_height_inches).mm

  card_geometry['rounded_corners']   = rounded_corners == true ? ((1.0 / 8.0) * MM_PER_INCH).mm : rounded_corners
  card_geometry['one_card_per_page'] = one_card_per_page

  if card_geometry['one_card_per_page']
    card_geometry['paper_width']       = card_geometry['card_width']
    card_geometry['paper_height']      = card_geometry['card_height']
  else
    card_geometry['paper_width']       = PAPER_WIDTH
    card_geometry['paper_height']      = PAPER_HEIGHT
  end

  card_geometry['cards_across'] = (card_geometry['paper_width'] / card_geometry['card_width']).floor
  card_geometry['cards_high']   = (card_geometry['paper_height'] / card_geometry['card_height']).floor

  card_geometry['page_width']   = card_geometry['card_width'] * card_geometry['cards_across']
  card_geometry['page_height']  = card_geometry['card_height'] * card_geometry['cards_high']

  card_geometry['margin_left']  = (card_geometry['paper_width'] - card_geometry['page_width']) / 2
  card_geometry['margin_top']   = (card_geometry['paper_height'] - card_geometry['page_height']) / 2

  card_geometry
end

def draw_grid(pdf, card_geometry)
  pdf.stroke do
    if card_geometry['rounded_corners'] == false
      # Draw vertical lines
      0.upto(card_geometry['cards_across']) do |i|
        pdf.line(
          [card_geometry['card_width'] * i, 0],
          [card_geometry['card_width'] * i, card_geometry['page_height']]
        )
      end

      # Draw horizontal lines
      0.upto(card_geometry['cards_high']) do |i|
        pdf.line(
          [0, card_geometry['card_height'] * i],
          [card_geometry['page_width'], card_geometry['card_height'] * i]
        )
      end
    else
      0.upto(card_geometry['cards_across'] - 1) do |i|
        0.upto(card_geometry['cards_high'] - 1) do |j|
          # rectangle bounded by upper left corner, horizontal measured from the left, vertical measured from the bottom
          pdf.rounded_rectangle(
            [i * card_geometry['card_width'], card_geometry['card_height'] + (j * card_geometry['card_height'])],
            card_geometry['card_width'],
            card_geometry['card_height'],
            card_geometry['rounded_corners']
          )
        end
      end
    end
  end
end

def box(pdf, card_geometry, index, &blck)
  # Determine row + column number
  column = index % card_geometry['cards_across']
  row = card_geometry['cards_high'] - index / card_geometry['cards_across']

  # Margin: 10pt
  x = card_geometry['card_width'] * column + 10
  y = card_geometry['card_height'] * row - 10

  pdf.bounding_box([x, y], width: card_geometry['card_width'] - 20, height: card_geometry['card_height'] - 10, &blck)
end

def draw_logos(pdf, card_geometry, icon)
  idx = 0
  while idx < card_geometry['cards_across'] * card_geometry['cards_high']
    box(pdf, card_geometry, idx) do
      logo_max_height = 15
      logo_max_width = card_geometry['card_width'] / 2
      pdf.image icon, fit: [logo_max_width, logo_max_height], at: [pdf.bounds.left, pdf.bounds.bottom + 25]
    end
    idx += 1
  end
end

def render_card_page(pdf, card_geometry, icon, statements, is_black, game_info)
  pdf.font 'Helvetica', style: :normal
  pdf.font_size = 14
  pdf.line_width(0.5)

  if is_black
    pdf.canvas do
      pdf.rectangle(pdf.bounds.top_left, pdf.bounds.width, pdf.bounds.height)
    end

    pdf.fill_and_stroke(fill_color: '000000', stroke_color: '000000') do
      pdf.canvas do
        pdf.rectangle(pdf.bounds.top_left, pdf.bounds.width, pdf.bounds.height)
      end
    end
    pdf.stroke_color 'ffffff'
    pdf.fill_color 'ffffff'
  else
    pdf.stroke_color '000000'
    pdf.fill_color '000000'
  end

  draw_grid(pdf, card_geometry)
  draw_logos(pdf, card_geometry, icon)
  statements.each_with_index do |line, idx|
    box(pdf, card_geometry, idx) do
      line_parts = line.split(/\t/)
      card_text = line_parts.shift
      card_text = card_text.gsub(/\\n */, "\n")
      card_text = card_text.gsub(/\\t/,   "\t")

      # Remove non-supported custom images for the multi-generator
      card_text = card_text.gsub('{{1}}', '')
      card_text = card_text.gsub('{{2}}', '')
      card_text = card_text.gsub('{{3}}', '')
      card_text = card_text.gsub('{{4}}', '')
      card_text = card_text.gsub('{{5}}', '')

      card_text = card_text.gsub('<b>', '[[[b]]]')
      card_text = card_text.gsub('<i>', '[[[i]]]')
      card_text = card_text.gsub('<u>', '[[[u]]]')
      card_text = card_text.gsub('<strikethrough>', '[[[strikethrough]]]')
      card_text = card_text.gsub('<sub>', '[[[sub]]]')
      card_text = card_text.gsub('<sup>', '[[[sup]]]')
      card_text = card_text.gsub('<font', '[[[font')
      card_text = card_text.gsub('<color', '[[[color')
      card_text = card_text.gsub('<br>', '[[[br/]]]')
      card_text = card_text.gsub('<br/>', '[[[br/]]]')
      card_text = card_text.gsub('<br />', '[[[br/]]]')

      card_text = card_text.gsub('</b>', '[[[/b]]]')
      card_text = card_text.gsub('</i>', '[[[/i]]]')
      card_text = card_text.gsub('</u>', '[[[/u]]]')
      card_text = card_text.gsub('</strikethrough>', '[[[/strikethrough]]]')
      card_text = card_text.gsub('</sub>', '[[[/sub]]]')
      card_text = card_text.gsub('</sup>', '[[[/sup]]]')
      card_text = card_text.gsub('</font>', '[[[/font]]]')
      card_text = card_text.gsub('</color>', '[[[/color]]]')

      card_text = card_text.gsub(/</, '&lt;')

      card_text = card_text.gsub("\[\[\[b\]\]\]", '<b>')
      card_text = card_text.gsub("\[\[\[i\]\]\]", '<i>')
      card_text = card_text.gsub("\[\[\[u\]\]\]", '<u>')
      card_text = card_text.gsub("\[\[\[strikethrough\]\]\]", '<strikethrough>')
      card_text = card_text.gsub("\[\[\[sub\]\]\]", '<sub>')
      card_text = card_text.gsub("\[\[\[sup\]\]\]", '<sup>')
      card_text = card_text.gsub("\[\[\[font", '<font')
      card_text = card_text.gsub("\[\[\[color", '<color')
      card_text = card_text.gsub("\[\[\[br/\]\]\]", '<br/>')

      card_text = card_text.gsub("\[\[\[/b\]\]\]", '</b>')
      card_text = card_text.gsub("\[\[\[/i\]\]\]", '</i>')
      card_text = card_text.gsub("\[\[\[/u\]\]\]", '</u>')
      card_text = card_text.gsub("\[\[\[/strikethrough\]\]\]", '</strikethrough>')
      card_text = card_text.gsub("\[\[\[/sub\]\]\]", '</sub>')
      card_text = card_text.gsub("\[\[\[/sup\]\]\]", '</sup>')
      card_text = card_text.gsub("\[\[\[/font\]\]\]", '</font>')
      card_text = card_text.gsub("\[\[\[/color\]\]\]", '</color>')

      parts = card_text.split(/\[\[/)
      card_text = ''
      first = true
      previous_matches = false
      parts.each do |p|
        n = p
        this_matches = false
        if p.match(/\]\]/)
          s = p.split(/\]\]/)
          line_parts.push(s[0])
          n = if s.length > 1
                s[1]
              else
                ''
              end
          this_matches = true
        end

        card_text = if first
                      n.to_s
                    elsif this_matches
                      card_text + n
                    else
                      "#{card_text}[[#{n}"
                    end
        first = false
      end
      card_text = card_text.gsub(/^[\t ]*/, '')
      card_text = card_text.gsub(/[\t ]*$/, '')

      is_pick2 = false
      is_pick3 = false
      if is_black
        pick_num = line_parts.shift
        if pick_num.nil? || pick_num == ''
          tmpline = "a#{card_text}a"
          parts = tmpline.split(/__+/)
          if parts.length == 3
            is_pick2 = true
          elsif parts.length >= 4
            is_pick3 = true
          end
        elsif pick_num == '2'
          is_pick2 = true
        elsif pick_num == '3'
          is_pick3 = true
        end
      end

      is_warn = false
      warn_text = ''
      if card_text.include?('((') && card_text.include?('))')
        is_warn = true
        warn_text = card_text[/\(\((.*?)\)\)/, 1]
        card_text.sub!("((#{warn_text}))", '')
      end

      picknum = '0'
      if is_pick2
        picknum = '2'
      elsif is_pick3
        picknum = '3'
      elsif is_black
        picknum = '1'
      end

      statements[idx] = [card_text, picknum]

      # by default cards should be bold
      card_text = "<b>#{card_text}</b>"

      # Text
      pdf.font 'Helvetica', style: :normal

      if is_pick3 && !is_warn
        pdf.text_box card_text.to_s, overflow: :shrink_to_fit, height: card_geometry['card_height'] - 55,
                                     inline_format: true
      else
        pdf.text_box card_text.to_s, overflow: :shrink_to_fit, height: card_geometry['card_height'] - 35,
                                     inline_format: true
      end

      pdf.font 'Helvetica', style: :bold
      # pick 2
      if is_pick2 && !is_warn
        pdf.text_box 'PICK', size: 11, align: :right, width: 30,
                             at: [pdf.bounds.right - 50, pdf.bounds.bottom + 20 + 1]
        pdf.fill_and_stroke(fill_color: 'ffffff', stroke_color: 'ffffff') do
          pdf.circle([pdf.bounds.right - 10 + 4, pdf.bounds.bottom + 15.5 + 2], 7.5)
        end
        pdf.stroke_color '000000'
        pdf.fill_color '000000'
        pdf.text_box '2', color: '000000', size: 14, width: 8, align: :center,
                          at: [pdf.bounds.right - 14 + 4, pdf.bounds.bottom + 21 + 1.5]
        pdf.stroke_color 'ffffff'
        pdf.fill_color 'ffffff'
      end

      # pick 3
      if is_pick3 && !is_warn
        pdf.text_box 'PICK', size: 11, align: :right, width: 30,
                             at: [pdf.bounds.right - 50, pdf.bounds.bottom + 20 + 1]
        pdf.fill_and_stroke(fill_color: 'ffffff', stroke_color: 'ffffff') do
          pdf.circle([pdf.bounds.right - 10 + 4, pdf.bounds.bottom + 15.5 + 2], 7.5)
        end
        pdf.stroke_color '000000'
        pdf.fill_color '000000'
        pdf.text_box '3', color: '000000', size: 14, width: 8, align: :center,
                          at: [pdf.bounds.right - 14 + 4, pdf.bounds.bottom + 21 + 1.5]
        pdf.stroke_color 'ffffff'
        pdf.fill_color 'ffffff'

        pdf.text_box 'DRAW', size: 11, align: :right, width: 35,
                             at: [pdf.bounds.right - 55, pdf.bounds.bottom + 40 + 1]
        pdf.fill_and_stroke(fill_color: 'ffffff', stroke_color: 'ffffff') do
          pdf.circle([pdf.bounds.right - 10 + 4, pdf.bounds.bottom + 35.5 + 2], 7.5)
        end
        pdf.stroke_color '000000'
        pdf.fill_color '000000'
        pdf.text_box '2', color: '000000', size: 14, width: 8, align: :center,
                          at: [pdf.bounds.right - 14 + 4, pdf.bounds.bottom + 41 + 1.5]
        pdf.stroke_color 'ffffff'
        pdf.fill_color 'ffffff'
      end

      if is_warn
        stroke_previous = pdf.stroke_color
        fill_previous = pdf.fill_color
        if is_black
          pdf.fill_and_stroke(fill_color: 'ffffff', stroke_color: 'ffffff') do
            pdf.circle([pdf.bounds.right - 10 + 4, pdf.bounds.bottom + 15.5 + 2], 7.5)
          end
          pdf.stroke_color '000000'
          pdf.fill_color '000000'
          pdf.text_box warn_text, color: '000000', size: 14, width: 12, align: :center,
                                  at: [pdf.bounds.right - 14 + 4 - 2, pdf.bounds.bottom + 21 + 1.5]
        else
          pdf.fill_and_stroke(fill_color: '000000', stroke_color: '000000') do
            pdf.circle([pdf.bounds.right - 10 + 4, pdf.bounds.bottom + 15.5 + 2], 7.5)
          end
          pdf.stroke_color 'ffffff'
          pdf.fill_color 'ffffff'
          pdf.text_box warn_text, color: 'ffffff', size: 14, width: 12, align: :center,
                                  at: [pdf.bounds.right - 14 + 4 - 2, pdf.bounds.bottom + 21 + 1.5]
        end
        pdf.stroke_color stroke_previous
        pdf.fill_color fill_previous
      end

      # print text
      text = game_info[:game_name]
      version = game_info[:game_version]

      text = game_info[:game_name_abbr] if is_pick2 || is_pick3

      text_color = if is_black
                     'ffffff'
                   else
                     '000000'
                   end

      stroke_previous = pdf.stroke_color
      fill_previous = pdf.fill_color

      pdf.stroke_color '000000'
      pdf.fill_color '000000'
      pdf.text_box version, color: '000000', size: 6, width: 20, rotate: -20, align: :center, at: [pdf.bounds.left + 6, pdf.bounds.bottom + 22] # WIP text
      pdf.stroke_color text_color
      pdf.fill_color text_color
      pdf.text_box text, color: 'ffffff', size: 6, width: 80, align: :left, at: [pdf.bounds.left + 24, pdf.bounds.bottom + 20] # WIP text
      pdf.stroke_color = stroke_previous
      pdf.fill_color = fill_previous
    end
  end

  pdf.stroke_color '000000'
  pdf.fill_color '000000'
end

def load_pages_from_lines(lines, card_geometry)
  pages = []

  non_empty_lines = []
  lines.each do |line|
    line = line.gsub(/^[\t\n\r]*/, '')
    line = line.gsub(/[\t\n\r]*$/, '')
    non_empty_lines.push(line) if line != ''
  end
  lines = non_empty_lines

  cards_per_page = card_geometry['cards_high'] * card_geometry['cards_across']
  num_pages = (lines.length.to_f / cards_per_page).ceil

  0.upto(num_pages - 1) do |pn|
    pages << lines[pn * cards_per_page, cards_per_page]
  end

  pages
end

def load_info(file)
  lines = IO.readlines(file) if File.exist?(file)

  unless lines.nil?
    if lines.size.positive?
      name = lines[0]
      name = name.split('=')[1]
      name = name.strip
      name_abbr = lines[1]
      name_abbr = name_abbr.split('=')[1]
      name_abbr = name_abbr.strip

      version = lines[2]
      version = version.split('=')[1]
      version = version.strip
    else
      name_abbr = ''
      version = ''
    end
  end

  { game_name: name, game_name_abbr: name_abbr, game_version: version }
end

def load_pages_from_string(string, card_geometry)
  lines = string.split(/[\r\n]+/)
  load_pages_from_lines(lines, card_geometry)
end

def load_pages_from_file(file, card_geometry)
  pages = []
  if File.exist?(file)
    lines = IO.readlines(file)
    pages = load_pages_from_lines(lines, card_geometry)
  end
  pages
end

def load_ttf_fonts(font_dir, font_families)
  if font_dir.nil?
    return
  elsif !Dir.exist?(font_dir) || font_families.nil?
    return
  end

  font_files = {}
  ttf_files = Dir.glob("#{font_dir}/*.ttf")
  ttf_files.each do |ttf|
    full_name = ttf.gsub(%r{^.*/}, '')
    full_name = full_name.gsub(/\.ttf$/, '')
    style = 'normal'
    name = full_name
    case name
    when /_Bold_Italic$/
      style = 'bold_italic'
      name = name.gsub(/_Bold_Italic$/, '')
    when /_Italic$/
      style = 'italic'
      name = name.gsub(/_Italic$/, '')
    when /_Bold$/
      style = 'bold'
      name = name.gsub(/_Bold$/, '')
    end

    name = name.gsub(/_/, ' ')

    font_files[name] = {} unless font_files.key? name
    font_files[name][style] = ttf
  end

  font_files.each_pair do |name, ttf_files|
    next unless (ttf_files.key? 'normal') && (!font_families.key? 'name')

    normal = ttf_files['normal']
    italic = (ttf_files.key? 'italic') ? ttf_files['italic'] : normal
    bold   = (ttf_files.key? 'bold') ? ttf_files['bold'] : normal
    bold_italic = normal
    if ttf_files.key? 'bold_italic'
      bold_italic = ttf_files['bold_italic']
    elsif ttf_files.key? 'italic'
      bold_italic = italic
    elsif ttf_files.key? 'bold'
      bold_italic = bold
    end

    font_families.update(name => {
                           normal: normal,
                           italic: italic,
                           bold: bold,
                           bold_italic: bold_italic
                         })
  end
end

# Renders cards
# @param directory [String] :
# @param info_file [String] :
# @param white_file [String] :
# @param black_file [String] :
# @param icon_file [String] :
# @param output_file [String] :
# @param input_files_are_absolute [Bool] :
# @param output_file_name_from_directory [Bool] :
# @param recurse [Bool] :
def render_cards(directory = '.', info_file = 'info.txt', white_file = 'white.txt', black_file = 'black.txt', icon_file = 'resources/icon.png', output_file = 'cards.pdf', input_files_are_absolute = false, output_file_name_from_directory = true, recurse = true, card_geometry = get_card_geometry, white_string = '', black_string = '', output_to_stdout = false, title = nil)
  original_white_file = white_file
  original_black_file = black_file
  original_icon_file = icon_file
  original_info_file = info_file
  unless input_files_are_absolute
    white_file = directory + File::Separator + white_file
    black_file = directory + File::Separator + black_file
    icon_file  = directory + File::Separator + icon_file
    info_file = directory + File::Separator + info_file
  end

  icon_file = './resources/icon.png' unless File.exist? icon_file

  if !directory.nil? && (File.exist?(directory) && (directory != '.') && output_file_name_from_directory)
    output_file = "#{directory.split(File::Separator).pop}.pdf"
  end

  if output_to_stdout && title.nil?
    title = 'Bloomgogo CAH'
  elsif title.nil? && (output_file != 'cards.pdf')
    title = output_file.split(File::Separator).pop.gsub(/.pdf$/, '')
  end

  white_pages = []
  black_pages = []

  if white_file.nil? && black_file.nil? && (white_string == '') && (black_string == '')
    white_string = ' '
    black_string = ' '
  end

  white_pages = if white_string != '' || white_file.nil?
                  load_pages_from_string(white_string, card_geometry)
                else
                  load_pages_from_file(white_file, card_geometry)
                end

  black_pages = if black_string != '' || black_file.nil?
                  load_pages_from_string(black_string, card_geometry)
                else
                  load_pages_from_file(black_file, card_geometry)
                end

  if white_pages.length.positive? || black_pages.length.positive?
    pdf = Prawn::Document.new(
      page_size: [card_geometry['paper_width'], card_geometry['paper_height']],
      left_margin: card_geometry['margin_left'],
      right_margin: card_geometry['margin_left'],
      top_margin: card_geometry['margin_top'],
      bottom_margin: card_geometry['margin_top'],
      info: { Title: title, CreationDate: Time.now, Producer: 'Bigger, Blacker Cards',
              Creator: 'Bigger, Blacker Cards' }
    )

    load_ttf_fonts('/usr/share/fonts/truetype/msttcorefonts', pdf.font_families)

    info = load_info(info_file)

    white_pages.each_with_index do |statements, page|
      render_card_page(pdf, card_geometry, icon_file, statements, false, info)
      pdf.start_new_page unless page >= white_pages.length - 1
    end

    pdf.start_new_page unless white_pages.length.zero? || black_pages.length.zero?

    black_pages.each_with_index do |statements, page|
      render_card_page(pdf, card_geometry, icon_file, statements, true, info)
      pdf.start_new_page unless page >= black_pages.length - 1
    end

    if output_to_stdout
      puts 'Content-Type: application/pdf'
      puts ''
      print pdf.render
    else
      pdf.render_file(output_file)
    end
  end

  if !input_files_are_absolute && recurse
    files_in_dir = Dir.glob("#{directory}#{File::Separator}*")
    files_in_dir.each do |subdir|
      if File.directory? subdir
        render_cards(subdir, original_info_file, original_white_file, original_black_file, original_icon_file,
                     'irrelevant', false, true, true, card_geometry)
      end
    end
  end
end

# Parse arguments
# @param variables [Hash] :
# @param flags [Hash] :
# @param save_orphaned [Bool] :
# @param argv [Array<>] :
def parse_args(variables = {}, flags = {}, save_orphaned = false, argv = ARGV)
  parsed_args = {}
  orphaned = []
  new_argv = []

  while argv.length.positive?
    next_arg = argv.shift
    if variables.key? next_arg
      arg_name = variables[next_arg]
      parsed_args[arg_name] = argv.shift
    elsif flags.key? next_arg
      flag_name = flags[next_arg]
      parsed_args[flag_name] = true
    else
      orphaned.push next_arg
    end
    new_argv.push next_arg
  end

  parsed_args['ORPHANED_ARGUMENT_ARRAY'] = orphaned if save_orphaned

  argv.push new_argv.shift while new_argv.length.positive?

  parsed_args
end

# Prints help message
def print_help
  puts "\n                       . :+ysmd.
                `.``ohhys+-`.m
          `.`-+ohsy-yhyyyyyyyyo:o/-/oosssyy.
     `--:+hsso:.`   mMMMMMMMMN/NMMMNdhyyydm-
     dm+/-`         mMMMMMMMModMMMMMMMMMMmdy+:.`
     +N+            mMMMMMMMyyMMMMMMMMMMMMMMMMNmhs+:.
     `/N:           mMMMMMMd+MMMMMMMMMMMMMMMMMMMMMMMm.
      .om.          mMMMMMN/NMMMMMMMMMMMMMMMMMMMMMMM+
       -yh`         mMMMMM+mMMMMMMMMMMMMMMMMMMMMMMMy
        :do         mMMMMsyMMMMMMMMMMMMMMMMMMMMMMMm`
        `:N:        mMMMhoMMMMMMMMMMMMMMMMMMMMMMMN-
         `/N.       mMMm/NMMMMMMMMMMMMMMMMMMMMMMM/
          .sd`      mMM+ymMMMMMMMMMMMMMMMMMMMMMMs
           :hs      +yy+-.-/oydNMMMMMMMMMMMMMMMd`
            -m/-/oosys-..     ``-/ohmNMMMMMMMMN.
            .+s++/.                 ``-+shmMMM/
                                           `::
"
  puts "\n             CARDS AGAINST HUMANITY GENERATOR"
  puts ''
  puts '-----------------------------------------------------------'
  puts 'USAGE:'
  puts "\tgenerator --directory [CARD_FILE_DIRECTORY]"
  puts "\tOR"
  puts "\tgenerator --white [WHITE_CARD_FILE]"
  puts "\t          --black [BLACK_CARD_FILE]"
  puts "\t          --info [INFO_FILE] --output [OUTPUT_FILE]"
  puts '-----------------------------------------------------------'
  puts ''
  puts '1. Routes'
  puts '-----------------------------------------------------------'
  puts 'This generator expects you to specify EITHER a directory or'
  puts 'specify a path to black/white card files. If both are'
  puts 'specified, it will ignore the indifidual files and generate'
  puts 'cards from the directory.'
  puts ''
  puts 'If you specify a directory, white cards will be loaded from'
  puts 'a file white.txt in that directory and black cards from'
  puts 'black.txt. If info.txt file exists in that directory, every'
  puts 'card will contain the information provided.'
  puts 'The output will be a pdf file with the same name as the'
  puts 'directory you specified in the current working directory.'
  puts 'This generator will descend recursively into any directory'
  puts 'you specify, generating a separate pdf for every directory'
  puts 'that contains black.txt, white.txt or both.'
  puts ''
  puts '2. Info file'
  puts '-----------------------------------------------------------'
  puts 'The info file contains the name of the game. It must have'
  puts 'from one to three lines.'
  puts '  - One line:'
  puts '      line 1 - game name'
  puts '      (name abbreviation will be automatically generated)'
  puts '  - Two lines:'
  puts '      line 1 - game name'
  puts '      line 2 - game version'
  puts '      (name abbreviation will be automatically generated)'
  puts '  - Three lines:'
  puts '      line 1 - game name'
  puts '      line 2 - abbreviated game name'
  puts '      line 3 - game version'
  puts ''
  puts '3. White and black text files'
  puts '-----------------------------------------------------------'
  puts 'Each card must be in one line. Zero-length lines will be'
  puts 'ignored, but lines containing spaces will be turned into'
  puts 'blank cards.'
  puts ''
  puts 'Inserting ((_)) will generate a special card, that has as'
  puts 'icon the character _ (i.e., for warning cards, put ((!))'
  puts ''
  puts 'The generator will detect PICK 2 and PICK 3, but you can'
  puts 'manually insert them by adding [[2]] or [[3]] at the'
  puts 'beginning or the end of the line.'
  puts ''
  puts 'Card text can be formatted using HTML-like tags. The'
  puts 'list of supported tags is as follows:'
  puts ''
  puts "\t<b></b> - bold text"
  puts "\t<i></i> - italic text"
  puts "\t<u></u> - underlined text"
  puts "\t<strikethrough></strikethrough>"
  puts "\t<sub></sub> - subscript text"
  puts "\t<sup></sup> - superscript text"
  puts "\t<br> - line break"
  puts "\t<color rgb=\"#0000ff\"></color>"
  puts "\t<font name=\"Font Name\"></font>"
  puts ''
  puts '3. Card sizes'
  puts '-----------------------------------------------------------'
  puts 'You may specify the card size by passing either the --small'
  puts ' or --large flag.  If you pass the --small flag then small'
  puts 'cards of size 2"x2" will be produced. If you pass the'
  puts '--large flag larger cards of size 2.5"x3.5" will be'
  puts 'produced. Small cards are produced by default.'
  puts ''
  puts 'All flags'
  puts '-----------------------------------------------------------'
  puts "\t-b,--black\tBlack card file"
  puts "\t-d,--dir\tDirectory to search for card files"
  puts "\t-h,--help\tPrint this Help message"
  puts "\t-i,--info\tInfo file"
  puts "\t-l,--large\tGenerate large 2.5\"x3.5\" cards"
  puts "\t-o,--output\tOutput directory, will be a cards.pdf file"
  puts "\t-s,--small\tGenerate small 2\"x2\" cards"
  puts "\t-w,--white\tWhite card file"
  puts ''
  puts '-----------------------------------------------------------'
  puts ''
  puts 'Beans Against Humanity Usage:'
  puts "\tscript/generate -d cards/ -l -o output"
  puts ''
end

# Main function
def main
  arg_defs = {}
  flag_defs = {}
  arg_defs['-b']          = 'black'
  arg_defs['--black']     = 'black'
  arg_defs['-w']          = 'white'
  arg_defs['--white']     = 'white'
  arg_defs['--info']	= 'info'
  arg_defs['-i']	= 'info'
  arg_defs['-d']          = 'dir'
  arg_defs['--directory'] = 'dir'
  arg_defs['-o']          = 'output'
  arg_defs['-output']     = 'output'

  flag_defs['-s']            = 'small'
  flag_defs['--small']       = 'small'
  flag_defs['-l']            = 'large'
  flag_defs['--large']       = 'large'
  flag_defs['-r']            = 'rounded'
  flag_defs['--rounded']     = 'rounded'
  flag_defs['-p']            = 'oneperpage'
  flag_defs['--oneperpage']  = 'oneperpage'
  flag_defs['-h']            = 'help'
  flag_defs['--help']        = 'help'

  args = parse_args(arg_defs, flag_defs)
  card_geometry = get_card_geometry(2.0, 2.0, !(args['rounded']).nil?, !(args['oneperpage']).nil?)

  card_geometry = get_card_geometry(2.5, 3.5, !(args['rounded']).nil?, !(args['oneperpage']).nil?) if args.key? 'large'

  if args.key?('help') || args.length.zero? || ((!args.key? 'white') && (!args.key? 'black') && (!args.key? 'dir'))
    print_help
  elsif args.key? 'dir'
    render_cards(args['dir'], 'info.txt', 'white.txt', 'black.txt', 'resources/icon.png', 'cards.pdf', false, true, true,
                 card_geometry, '', '', false)
  else
    render_cards(nil, args['info'], args['white'], args['black'], 'resources/icon.png', args['output'], true, false,
                 false, card_geometry, '', '', false)
  end

  if args['output']
    puts "Generated: #{args['output']}/cards.pdf"
    FileUtils.mv('cards.pdf', args['output'].to_s)
  end
end

main
puts "Done!"
exit
