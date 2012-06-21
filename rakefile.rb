require 'tempfile'
require 'fileutils'

PROJECT          = File.basename(Dir.glob("*.pde").first, ".pde")
MCU              = 'atmega328p'
CPU              = '16000000L'
PORT             = Dir.glob('/dev/tty.usbmodem*').first
BITRATE          = '115200'

BUILD_OUTPUT     = 'build'
ARDUINO_ROOT     = '/Applications/Arduino.app/Contents/Resources/Java'
AVRDUDE          = "#{ARDUINO_ROOT}/hardware/tools/avr/bin/avrdude"
AVRDUDE_CONF     = "#{ARDUINO_ROOT}/hardware/tools/avr/etc/avrdude.conf"

AVR_G_PLUS_PLUS  = "#{ARDUINO_ROOT}/hardware/tools/avr/bin/avr-g++"
AVR_GCC          = "#{ARDUINO_ROOT}/hardware/tools/avr/bin/avr-gcc"
AVR_AR           = "#{ARDUINO_ROOT}/hardware/tools/avr/bin/avr-ar"
AVR_OBJCOPY      = "#{ARDUINO_ROOT}/hardware/tools/avr/bin/avr-objcopy"
ARDUINO_CORES    = "#{ARDUINO_ROOT}/hardware/arduino/cores/arduino"
ARDUINO_VARIANTS = "#{ARDUINO_ROOT}/hardware/arduino/variants/standard"

def build_output_path(file)
  FileUtils.mkdir_p(BUILD_OUTPUT)
  File.expand_path(File.join(BUILD_OUTPUT, file))
end

desc "build and upload"
task :default => [:build, :upload]

desc "build the hex file"
task :build => [:clean, :preprocess, :compile]

desc "upload hex file to your device"
task :upload do
  sh "#{AVRDUDE} -C#{AVRDUDE_CONF} -v -v -v -v -p#{MCU} -carduino -P#{PORT} -b#{BITRATE} -D -Uflash:w:#{build_output_path("#{PROJECT}.cpp.hex")}:i"
end

desc "delete the build output directory"
task :clean do
  FileUtils.rm_rf(BUILD_OUTPUT)
end

task :preprocess do
  pde = "#{PROJECT}.pde"
  cpp = build_output_path("#{PROJECT}.cpp")
  File.open(cpp, 'w') do |file|
    file.puts File.read(pde)
  end
end

task :compile do
  threads = [
    Thread.new {
      gplusplus build_output_path("#{PROJECT}.cpp")
    },
    Thread.new {
      Dir.glob("#{ARDUINO_ROOT}/hardware/arduino/cores/arduino/*.c").each { |c| gcc c }
    },
    Thread.new {
      Dir.glob("#{ARDUINO_ROOT}/hardware/arduino/cores/arduino/*.cpp").each { |cpp| gplusplus cpp }
    }
  ]
  threads.each { |t| t.join }

  Dir.glob(build_output_path("*.o")).each { |o| o o }

  sh "#{AVR_GCC} -Os -Wl,--gc-sections -mmcu=atmega328p -o #{build_output_path("#{PROJECT}.cpp.elf")} #{build_output_path("#{PROJECT}.cpp.o")} #{build_output_path("core.a")} -L#{build_output_path("#{PROJECT}.tmp")} -lm"

  sh "#{AVR_OBJCOPY} -O ihex -j .eeprom --set-section-flags=.eeprom=alloc,load --no-change-warnings --change-section-lma .eeprom=0 #{build_output_path("#{PROJECT}.cpp.elf")} #{build_output_path("#{PROJECT}.cpp.eep")}"
  sh "#{AVR_OBJCOPY} -O ihex -R .eeprom #{build_output_path("#{PROJECT}.cpp.elf")} #{build_output_path("#{PROJECT}.cpp.hex")}"
end

def gplusplus source_file
  output = build_output_path(File.basename(source_file) + ".o")
  sh "#{AVR_G_PLUS_PLUS} -c -g -Os -Wall -fno-exceptions -ffunction-sections -fdata-sections -mmcu=#{MCU} -DF_CPU=#{CPU} -MMD -DUSB_VID=null -DUSB_PID=null -DARDUINO=101 -I#{ARDUINO_CORES} -I#{ARDUINO_VARIANTS} #{source_file} -o #{output}"
end

def gcc source_file
  output = build_output_path(File.basename(source_file) + ".o")
  sh "#{AVR_GCC} -c -g -Os -Wall -ffunction-sections -fdata-sections -mmcu=#{MCU} -DF_CPU=#{CPU} -MMD -DUSB_VID=null -DUSB_PID=null -DARDUINO=101 -I#{ARDUINO_CORES} -I#{ARDUINO_VARIANTS} #{source_file} -o #{output}"
end

def o source_file
  sh "#{AVR_AR} rcs #{build_output_path("core.a")} #{source_file}" 
end
