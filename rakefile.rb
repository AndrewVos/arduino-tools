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

C_FILES          ||= %w{pins_arduino.c WInterrupts.c wiring.c wiring_analog.c wiring_digital.c wiring_pulse.c wiring_shift.c}
CPP_FILES        ||= %w{HardwareSerial.cpp main.cpp Print.cpp Tone.cpp WMath.cpp WString.cpp}

desc "Compile and upload"
task :default => [:compile, :upload]

desc "Compile the hex file"
task :compile => [:clean, :create_cpp_file, :compile_c_files, :compile_cpp_files, :add_files_to_archive, :compile_elf, :compile_hex]

desc "Upload compiled hex file to your device"
task :upload do
  hex = build_output_path("#{PROJECT}.hex")
  sh "#{AVRDUDE} -C#{AVRDUDE_CONF} -q -q -p#{MCU} -c#{PROGRAMMER} -P#{PORT} -b#{BITRATE} -D -Uflash:w:#{hex}:i"
end

desc "Delete the build output directory"
task :clean do
  FileUtils.rm_rf(BUILD_OUTPUT)
end

task :create_cpp_file do
  pde = "#{PROJECT}.pde"
  cpp = build_output_path("#{PROJECT}.cpp")
  File.open(cpp, 'w') do |file|
    file.puts '#include "WProgram.h"'
    file.puts File.read(pde)
  end
  compile_g_plus_plus(cpp)
end

task :compile_c_files do
  C_FILES.each do |c|
    compile_c(c)
  end
end

task :compile_cpp_files do
  CPP_FILES.each do |cpp|
    compile_g_plus_plus(File.join(ARDUINO_CORES, cpp))
  end
end

task :add_files_to_archive do
  (C_FILES + CPP_FILES).each do |file|
    file = build_output_path(File.basename(file, File.extname(file)) + ".o")
    sh "#{AVR_AR} rcs #{build_output_path('core.a')} #{file}"
  end
end

task :compile_elf do
  o = build_output_path("#{PROJECT}.o")
  elf = build_output_path("#{PROJECT}.elf")
  core_archive = build_output_path('core.a')
  sh "#{AVR_GCC} -Os -Wl,--gc-sections -mmcu=#{MCU} -o #{elf} #{o} #{core_archive} -L#{BUILD_OUTPUT} -lm"
end

task :compile_hex do
  elf = build_output_path("#{PROJECT}.elf")
  eep = build_output_path("#{PROJECT}.eep")
  hex = build_output_path("#{PROJECT}.hex")
  sh "#{AVR_OBJCOPY} -O ihex -j .eeprom --set-section-flags=.eeprom=alloc,load --no-change-warnings --change-section-lma .eeprom=0 #{elf} #{eep}"
  sh "#{AVR_OBJCOPY} -O ihex -R .eeprom #{elf} #{hex}"
end

def compile_c(file)
  file_output = build_output_path(File.basename(file, File.extname(file)) + ".o")
  sh "#{AVR_GCC} -c -g -Os -w -ffunction-sections -fdata-sections -mmcu=#{MCU} -DF_CPU=#{CPU} -DARDUINO=22 -I#{ARDUINO_CORES} #{ARDUINO_CORES}/#{file} -o#{file_output}"
end

def compile_g_plus_plus(file)
  file_output = build_output_path(File.basename(file, File.extname(file)) + ".o")
  sh "#{AVR_G_PLUS_PLUS} -c -g -Os -w -fno-exceptions -ffunction-sections -fdata-sections -mmcu=#{MCU} -DF_CPU=#{CPU} -DARDUINO=22 -I#{ARDUINO_CORES} #{file} -o#{file_output}"
end

def build_output_path(file)
  Dir.mkdir(BUILD_OUTPUT) if Dir.exist?(BUILD_OUTPUT) == false
  File.join(BUILD_OUTPUT, file)
end
