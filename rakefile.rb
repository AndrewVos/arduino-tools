require 'tempfile'
require 'fileutils'

PROJECT          ||= File.basename(Dir.glob("*.pde").first, ".pde")
MCU              ||= 'atmega328p'
CPU              ||= '16000000L'
PORT             ||= Dir.glob('/dev/tty.usbmodem*').first
BITRATE          ||= '115200'
PROGRAMMER       ||= 'stk500v1'

BUILD_OUTPUT     ||= 'build'
ARDUINO_HARDWARE ||= '/Applications/Arduino.app/Contents/Resources/Java/hardware'
AVRDUDE          ||= "#{ARDUINO_HARDWARE}/tools/avr/bin/avrdude"
AVRDUDE_CONF     ||= "#{ARDUINO_HARDWARE}/tools/avr/etc/avrdude.conf"
ARDUINO_CORES    ||= "#{ARDUINO_HARDWARE}/arduino/cores/arduino"
AVR_G_PLUS_PLUS  ||= "#{ARDUINO_HARDWARE}/tools/avr/bin/avr-g++"
AVR_GCC          ||= "#{ARDUINO_HARDWARE}/tools/avr/bin/avr-gcc"
AVR_AR           ||= "#{ARDUINO_HARDWARE}/tools/avr/bin/avr-ar"
AVR_OBJCOPY      ||= "#{ARDUINO_HARDWARE}/tools/avr/bin/avr-objcopy"

def build_output_path(file)
  Dir.mkdir(BUILD_OUTPUT) if Dir.exist?(BUILD_OUTPUT) == false
  File.join(BUILD_OUTPUT, file)
end

C_FILES          ||= Dir.glob("#{ARDUINO_CORES}/*.c")
CPP_FILES        ||= Dir.glob("#{ARDUINO_CORES}/*.cpp") + [build_output_path("#{PROJECT}.cpp")]

desc "Compile and upload"
task :default => [:compile, :upload]

desc "Compile the hex file"
task :compile => [:clean, :preprocess, :c, :cpp, :hex]

desc "Upload compiled hex file to your device"
task :upload do
  hex = build_output_path("#{PROJECT}.hex")
  sh "#{AVRDUDE} -C#{AVRDUDE_CONF} -q -q -p#{MCU} -c#{PROGRAMMER} -P#{PORT} -b#{BITRATE} -D -Uflash:w:#{hex}:i"
end

desc "Delete the build output directory"
task :clean do
  FileUtils.rm_rf(BUILD_OUTPUT)
end

task :preprocess do
  pde = "#{PROJECT}.pde"
  cpp = build_output_path("#{PROJECT}.cpp")
  File.open(cpp, 'w') do |file|
    file.puts '#include "WProgram.h"'
    file.puts File.read(pde)
  end
end

task :c do
  C_FILES.each do |source|
    output = build_output_path(File.basename(source, File.extname(source)) + ".o")
    sh "#{AVR_GCC} -c -g -Os -w -ffunction-sections -fdata-sections -mmcu=#{MCU} -DF_CPU=#{CPU} -DARDUINO=22 -I#{ARDUINO_CORES} #{source} -o#{output}"
  end
end

task :cpp do
  CPP_FILES.each do |source|
    output = build_output_path(File.basename(source, File.extname(source)) + ".o")
    sh "#{AVR_G_PLUS_PLUS} -c -g -Os -w -fno-exceptions -ffunction-sections -fdata-sections -mmcu=#{MCU} -DF_CPU=#{CPU} -DARDUINO=22 -I#{ARDUINO_CORES} #{source} -o#{output}"
  end
end

task :hex do
  o       = build_output_path("#{PROJECT}.o")
  elf     = build_output_path("#{PROJECT}.elf")
  archive = build_output_path('core.a')
  eep     = build_output_path("#{PROJECT}.eep")
  hex     = build_output_path("#{PROJECT}.hex")

  (C_FILES + CPP_FILES).each do |file|
    file = build_output_path(File.basename(file, File.extname(file)) + ".o")
    sh "#{AVR_AR} rcs #{archive} #{file}"
  end

  sh "#{AVR_GCC} -Os -Wl,--gc-sections -mmcu=#{MCU} -o #{elf} #{o} #{archive} -L#{BUILD_OUTPUT} -lm"
  sh "#{AVR_OBJCOPY} -O ihex -j .eeprom --set-section-flags=.eeprom=alloc,load --no-change-warnings --change-section-lma .eeprom=0 #{elf} #{eep}"
  sh "#{AVR_OBJCOPY} -O ihex -R .eeprom #{elf} #{hex}"
end
