module Paperclip
  class Vips < Processor
    attr_accessor :auto_orient, :convert_options, :current_geometry, :format, :source_file_options,
      :target_geometry, :whiny

    def initialize(file, options = {}, attachment = nil)
      super

      geometry = options[:geometry].to_s
      @should_crop = geometry[-1, 1] == "#"
      @target_geometry = options.fetch(:string_geometry_parser, Geometry).parse(geometry)
      @current_geometry = options.fetch(:file_geometry_parser, Geometry).from_file(@file)
      @whiny = options.fetch(:whiny, true)

      @auto_orient = options.fetch(:auto_orient, true)
      @convert_options = options[:convert_options]

      @current_format = current_format(file).downcase
      @format = options[:format] || @current_format

      @basename = File.basename(@file.path, @current_format)
    end

    def make
      source = @file
      filename = [@basename, @format ? ".#{@format}" : ""].join
      destination = TempfileFactory.new.generate(filename)

      begin
        if @target_geometry.present?
          target_width = @target_geometry.width
          target_height = @target_geometry.height
          modifier = @target_geometry.modifier # e.g., ">", "#", etc.

          # Use thumbnail for efficient resizing and cropping
          crop = (modifier == "#")
          thumbnail = ::Vips::Image.thumbnail(
            source.path,
            target_width,
            height: crop ? target_height : nil,
            size: (modifier == ">" ? :down : :both), # ">" means shrink only
            crop: crop ? :centre : :none
          )

          # Additional cropping for exact "#" dimensions if needed
          if crop && (thumbnail.width != target_width || thumbnail.height != target_height)
            left = [0, (thumbnail.width - target_width) / 2].max
            top = [0, (thumbnail.height - target_height) / 2].max
            crop_width = [target_width, thumbnail.width - left].min
            crop_height = [target_height, thumbnail.height - top].min
            if crop_width.positive? && crop_height.positive?
              thumbnail = thumbnail.crop(left, top, crop_width,
                crop_height)
            end
          end
        end

        # Fallback to original image if no geometry
        thumbnail = ::Vips::Image.new_from_file(source.path) unless defined?(thumbnail) && thumbnail

        # Apply convert options
        thumbnail = process_convert_options(thumbnail)

        # Save the processed image
        save_thumbnail(thumbnail, destination.path)
      rescue StandardError => e
        puts e.message, e.backtrace
        if @whiny
          message = "There was an error processing the thumbnail for #{@basename}:\n#{e.message}"
          raise Paperclip::Error, message
        end
      end

      destination # Return the Tempfile object
    end

    private

    def crop
      return @options[:crop] || :centre if @should_crop

      nil
    end

    def current_format(file)
      extension = File.extname(file.path)
      return extension if extension.present?

      extension = File.extname(file.original_filename)
      return extension if extension.present?

      ""
    end

    def width
      @target_geometry&.width || @current_geometry.width
    end

    def height
      @target_geometry&.height || @current_geometry.height
    end

    def process_convert_options(image)
      if image && @convert_options.present?
        # Handle string-based convert_options (e.g., "-quality 80 -strip")
        quality = @convert_options[/quality (\d+)/, 1]&.to_i
        strip = @convert_options.include?("-strip")

        # Apply options via instance variables for save_thumbnail
        @processed_quality = quality if quality
        @processed_strip = strip if strip

        # Handle JSON-based commands if present
        commands = parsed_convert_commands(@convert_options)
        commands.each do |cmd|
          image = ::Vips::Operation.call(cmd[:cmd], [image, *cmd[:args]], cmd[:optional] || {})
        end
      end
      image
    end

    def parsed_convert_commands(convert_options)
      begin
        commands = JSON.parse(convert_options, symbolize_names: true)
      rescue StandardError
        commands = []
      end

      commands.unshift({ cmd: "autorot" }) if @auto_orient && commands.none? { |cmd| cmd[:cmd] == "autorot" }

      commands
    end

    def save_thumbnail(thumbnail, path)
      quality = @processed_quality || 75
      strip = @processed_strip || false

      case @format.to_s.downcase
      when ".jpeg", ".jpg", "jpeg", "jpg", "webp"
        thumbnail.jpegsave(path, Q: quality, strip:)
      when ".gif", "gif"
        thumbnail.magicksave(path, strip:) # No quality for GIF
      when ".png", "png"
        compression = 9 - (quality / 11.1).floor # Map 0-100 to 9-0
        thumbnail.pngsave(path, compression:, strip:)
      else
        thumbnail.write_to_file(path) # Fallback
      end
    end
  end
end
